//! Ultra HDR & ISO 21496-1 Gain Map Engine (Issue #20).
//!
//! Provides pure-Rust, standards-compliant on-device generation, packaging, and
//! reconstruction of Ultra HDR JPEGs compatible with Android 14+, Apple iOS 18+,
//! macOS Sequoia, Windows 11 Chrome, and Google Photos.
//!
//! # Architecture
//! Ultra HDR pairs a standard 8-bit SDR JPEG with a compact secondary luminance
//! gain-map JPEG. The primary image embeds:
//! 1. ISO 21496-1 / Android Ultra HDR XMP metadata (`hdrgm:GainMapMax`, etc.)
//! 2. CIPA DC-007 Multi-Picture Format (MPF) APP2 segment pointing to the secondary image.
//! 3. Secondary gain map JPEG concatenated at the specified offset.
//!
//! When viewed on standard displays, only the SDR base image renders. On HDR
//! displays (>400–1600 nits), the gain map modulates highlight pixels to achieve
//! true optical HDR punch with zero banding.

use jpeg_encoder::{ColorType, Encoder};

/// Metadata parameters defined by ISO 21496-1 and Adobe/Google HDR Gain Map spec.
#[derive(Debug, Clone, PartialEq)]
pub struct UltraHdrMetadata {
    pub version: String,
    /// Minimum gain in log2 stops (typically 0.0).
    pub gain_map_min: f32,
    /// Maximum gain / headroom in log2 stops (e.g. 2.0 = 4x brightness boost).
    pub gain_map_max: f32,
    /// Gain map gamma (typically 1.0 for linear encoding).
    pub gamma: f32,
    /// SDR luminance offset epsilon (default 1/64 = 0.015625) to avoid divide-by-zero.
    pub offset_sdr: f32,
    /// HDR luminance offset epsilon (default 1/64 = 0.015625).
    pub offset_hdr: f32,
    /// Minimum display HDR headroom capacity.
    pub hdr_capacity_min: f32,
    /// Maximum display HDR headroom capacity.
    pub hdr_capacity_max: f32,
    /// Whether the base rendition is already HDR (default false for SDR base).
    pub base_rendition_is_hdr: bool,
}

impl Default for UltraHdrMetadata {
    fn default() -> Self {
        Self {
            version: "1.0".to_string(),
            gain_map_min: 0.0,
            gain_map_max: 2.0,
            gamma: 1.0,
            offset_sdr: 0.015625,
            offset_hdr: 0.015625,
            hdr_capacity_min: 0.0,
            hdr_capacity_max: 2.0,
            base_rendition_is_hdr: false,
        }
    }
}

/// Generates a grayscale luminance gain map buffer (`gw * gh` bytes) from an SDR RGBA8 image.
///
/// If `hdr_radiance` (linear RGB float per pixel) is supplied, it computes true ratio
/// against scene radiance. If `None`, it smoothly expands specular highlights (> 0.5 linear)
/// up to `2^(gain_map_max)` EV stops.
pub fn generate_gain_map(
    sdr_rgba: &[u8],
    sw: usize,
    sh: usize,
    gw: usize,
    gh: usize,
    metadata: &UltraHdrMetadata,
    hdr_radiance: Option<&[f32]>,
) -> Vec<u8> {
    if gw == 0 || gh == 0 || sw == 0 || sh == 0 {
        return Vec::new();
    }
    let mut gain_map = vec![0u8; gw * gh];
    let x_scale = sw as f32 / gw as f32;
    let y_scale = sh as f32 / gh as f32;

    for gy in 0..gh {
        let sy = (((gy as f32 + 0.5) * y_scale).floor() as usize).min(sh - 1);
        for gx in 0..gw {
            let sx = (((gx as f32 + 0.5) * x_scale).floor() as usize).min(sw - 1);
            let s_idx = (sy * sw + sx) * 4;

            let sdr_r = crate::color::srgb_to_linear(sdr_rgba[s_idx] as f32 / 255.0);
            let sdr_g = crate::color::srgb_to_linear(sdr_rgba[s_idx + 1] as f32 / 255.0);
            let sdr_b = crate::color::srgb_to_linear(sdr_rgba[s_idx + 2] as f32 / 255.0);
            let y_sdr = 0.2126 * sdr_r + 0.7152 * sdr_g + 0.0722 * sdr_b;

            let y_hdr = if let Some(radiance) = hdr_radiance {
                let h_idx = (sy * sw + sx) * 3;
                0.2126 * radiance[h_idx]
                    + 0.7152 * radiance[h_idx + 1]
                    + 0.0722 * radiance[h_idx + 2]
            } else {
                // Reconstruct specular highlight radiance
                if y_sdr > 0.4 {
                    let t = (y_sdr - 0.4) / 0.6;
                    let boost = 2f32.powf(metadata.gain_map_max) - 1.0;
                    y_sdr * (1.0 + boost * (t * t))
                } else {
                    y_sdr
                }
            };

            // ISO 21496-1 log2 ratio formula
            let ratio = (y_hdr + metadata.offset_hdr) / (y_sdr + metadata.offset_sdr);
            let gain = ratio.max(1e-4).log2();

            // Normalize into [0.0, 1.0]
            let gain_norm = if metadata.gain_map_max > metadata.gain_map_min {
                let clamped = gain.clamp(metadata.gain_map_min, metadata.gain_map_max);
                ((clamped - metadata.gain_map_min)
                    / (metadata.gain_map_max - metadata.gain_map_min))
                    .powf(1.0 / metadata.gamma)
            } else {
                0.0
            };

            gain_map[gy * gw + gx] = (gain_norm.clamp(0.0, 1.0) * 255.0 + 0.5) as u8;
        }
    }
    gain_map
}

/// Encodes a grayscale 8-bit gain map buffer to JPEG using [`jpeg_encoder`].
pub fn encode_gain_map_jpeg(
    gain_map: &[u8],
    width: usize,
    height: usize,
    quality: u8,
) -> Result<Vec<u8>, String> {
    if width == 0 || height == 0 || gain_map.len() != width * height {
        return Err("invalid gain map dimensions".to_string());
    }
    let mut out = Vec::new();
    Encoder::new(&mut out, quality)
        .encode(gain_map, width as u16, height as u16, ColorType::Luma)
        .map_err(|e| format!("gain map jpeg encode: {e}"))?;
    Ok(out)
}

/// Builds the Multi-Picture Format (MPF) APP2 segment according to CIPA DC-007.
///
/// * `primary_jpeg_len`: Total byte size of the primary SDR JPEG container.
/// * `gain_map_len`: Byte size of the secondary gain-map JPEG.
/// * `mpf_offset_in_primary`: Byte offset in the primary JPEG where this MPF segment starts.
pub fn build_mpf_segment(
    primary_jpeg_len: usize,
    gain_map_len: usize,
    mpf_offset_in_primary: usize,
) -> Vec<u8> {
    // Total segment layout:
    // 0xFF 0xE2 (Marker, 2B)
    // Length (2B, big-endian)
    // 'MPF\0' (4B)
    // TIFF Header (8B):
    //   0x4D, 0x4D (MM big endian)
    //   0x00, 0x2A (Magic 42)
    //   0x00, 0x00, 0x00, 0x08 (Offset to 1st IFD)
    // MP Index IFD:
    //   Count: 3 tags (2B: 0x00, 0x03)
    //   Tag 1 (0xB000, MPF Version): UNDEFINED, count 4, value: b"0100"
    //   Tag 2 (0xB001, Number of Images): LONG, count 1, value: 2
    //   Tag 3 (0xB002, MP Entry): UNDEFINED, count 32 (2 entries * 16B), offset 8 + 2 + 3*12 + 4 = 50
    //   Next IFD: 0x00, 0x00, 0x00, 0x00 (4B)
    // MP Entry Table (32B):
    //   Entry 1 (Primary):
    //     0x00, 0x03, 0x00, 0x00 (Baseline MP Primary Image)
    //     size: primary_jpeg_len (u32)
    //     offset: 0 (u32)
    //     dep1: 0 (u16), dep2: 0 (u16)
    //   Entry 2 (Secondary Gain Map):
    //     0x00, 0x00, 0x00, 0x00 (Undefined child image)
    //     size: gain_map_len (u32)
    //     offset: gain_map_offset_from_tiff_header (u32)
    //     dep1: 0 (u16), dep2: 0 (u16)

    let tiff_header_offset_in_primary = mpf_offset_in_primary + 8;
    let gain_map_offset = primary_jpeg_len.saturating_sub(tiff_header_offset_in_primary);

    let mut body = Vec::with_capacity(96);
    body.extend_from_slice(b"MPF\0");

    // TIFF Header
    body.extend_from_slice(&[0x4D, 0x4D]); // MM
    body.extend_from_slice(&[0x00, 0x2A]); // 42
    body.extend_from_slice(&8u32.to_be_bytes()); // Offset to IFD

    // MP Index IFD
    body.extend_from_slice(&3u16.to_be_bytes()); // 3 tags

    // Tag 1: MPF Version (0xB000)
    body.extend_from_slice(&0xB000u16.to_be_bytes());
    body.extend_from_slice(&7u16.to_be_bytes()); // UNDEFINED
    body.extend_from_slice(&4u32.to_be_bytes()); // count 4
    body.extend_from_slice(b"0100");

    // Tag 2: Number of Images (0xB001)
    body.extend_from_slice(&0xB001u16.to_be_bytes());
    body.extend_from_slice(&4u16.to_be_bytes()); // LONG
    body.extend_from_slice(&1u32.to_be_bytes()); // count 1
    body.extend_from_slice(&2u32.to_be_bytes()); // 2 images

    // Tag 3: MP Entry (0xB002)
    // Offset relative to TIFF header start: 8 (header) + 2 (count) + 3*12 (tags) + 4 (next IFD) = 50
    body.extend_from_slice(&0xB002u16.to_be_bytes());
    body.extend_from_slice(&7u16.to_be_bytes()); // UNDEFINED
    body.extend_from_slice(&32u32.to_be_bytes()); // 2 entries * 16 bytes
    body.extend_from_slice(&50u32.to_be_bytes()); // offset 50

    // Next IFD Offset (0 = none)
    body.extend_from_slice(&0u32.to_be_bytes());

    // MP Entries:
    // Entry 1 (Primary Image)
    body.extend_from_slice(&[0x00, 0x03, 0x00, 0x00]); // MP Primary
    body.extend_from_slice(&(primary_jpeg_len as u32).to_be_bytes());
    body.extend_from_slice(&0u32.to_be_bytes()); // offset 0
    body.extend_from_slice(&0u16.to_be_bytes()); // dep1
    body.extend_from_slice(&0u16.to_be_bytes()); // dep2

    // Entry 2 (Secondary Gain Map)
    body.extend_from_slice(&[0x00, 0x00, 0x00, 0x00]);
    body.extend_from_slice(&(gain_map_len as u32).to_be_bytes());
    body.extend_from_slice(&(gain_map_offset as u32).to_be_bytes());
    body.extend_from_slice(&0u16.to_be_bytes()); // dep1
    body.extend_from_slice(&0u16.to_be_bytes()); // dep2

    let payload_len = (body.len() + 2) as u16;
    let mut seg = Vec::with_capacity(body.len() + 4);
    seg.extend_from_slice(&[
        0xFF,
        0xE2,
        (payload_len >> 8) as u8,
        (payload_len & 0xFF) as u8,
    ]);
    seg.extend_from_slice(&body);
    seg
}

/// Builds an XMP APP1 segment embedding ISO 21496-1 and Google Ultra HDR metadata.
pub fn build_ultrahdr_xmp_segment(metadata: &UltraHdrMetadata, gain_map_len: usize) -> Vec<u8> {
    let xmp_xml = format!(
        r#"<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="ApertureX Ultra HDR Engine">
  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description rdf:about=""
      xmlns:hdrgm="http://ns.adobe.com/hdr-gain-map/1.0/"
      xmlns:Container="http://ns.google.com/photos/1.0/container/"
      xmlns:Item="http://ns.google.com/photos/1.0/container/item/"
      hdrgm:Version="{}"
      hdrgm:GainMapMin="{:.6}"
      hdrgm:GainMapMax="{:.6}"
      hdrgm:Gamma="{:.6}"
      hdrgm:OffsetSDR="{:.6}"
      hdrgm:OffsetHDR="{:.6}"
      hdrgm:HDRCapacityMin="{:.6}"
      hdrgm:HDRCapacityMax="{:.6}"
      hdrgm:BaseRenditionIsHDR="{}">
      <Container:Directory>
        <rdf:Seq>
          <rdf:li rdf:parseType="Resource">
            <Container:Item Item:Mime="image/jpeg" Item:Semantic="Primary" Item:Length="0" Item:Padding="0"/>
          </rdf:li>
          <rdf:li rdf:parseType="Resource">
            <Container:Item Item:Mime="image/jpeg" Item:Semantic="GainMap" Item:Length="{}" Item:Padding="0"/>
          </rdf:li>
        </rdf:Seq>
      </Container:Directory>
    </rdf:Description>
  </rdf:RDF>
</x:xmpmeta>"#,
        metadata.version,
        metadata.gain_map_min,
        metadata.gain_map_max,
        metadata.gamma,
        metadata.offset_sdr,
        metadata.offset_hdr,
        metadata.hdr_capacity_min,
        metadata.hdr_capacity_max,
        if metadata.base_rendition_is_hdr {
            "True"
        } else {
            "False"
        },
        gain_map_len,
    );

    let header = b"http://ns.adobe.com/xap/1.0/\0";
    let payload_len = (2 + header.len() + xmp_xml.len()) as u16;
    let mut seg = Vec::with_capacity(payload_len as usize + 2);
    seg.extend_from_slice(&[
        0xFF,
        0xE1,
        (payload_len >> 8) as u8,
        (payload_len & 0xFF) as u8,
    ]);
    seg.extend_from_slice(header);
    seg.extend_from_slice(xmp_xml.as_bytes());
    seg
}

/// Assembles a complete, standards-compliant Ultra HDR JPEG.
///
/// 1. Encodes primary SDR image to JPEG.
/// 2. Downsamples and encodes secondary luminance gain map.
/// 3. Injects ISO 21496-1 XMP metadata and CIPA DC-007 MPF APP2 segments.
/// 4. Appends the secondary gain-map JPEG stream.
#[allow(clippy::too_many_arguments)]
pub fn encode_ultra_hdr_jpeg(
    sdr_rgba: &[u8],
    width: usize,
    height: usize,
    sdr_quality: u8,
    gain_quality: u8,
    exif: &[u8],
    metadata: &UltraHdrMetadata,
    hdr_radiance: Option<&[f32]>,
) -> Result<Vec<u8>, String> {
    if width == 0 || height == 0 {
        return Err("dimensions must be non-zero".to_string());
    }

    // 1. Generate & encode secondary Gain Map (half resolution for compactness)
    let gw = (width / 2).max(1);
    let gh = (height / 2).max(1);
    let gain_map_raw = generate_gain_map(sdr_rgba, width, height, gw, gh, metadata, hdr_radiance);
    let gain_map_jpeg = encode_gain_map_jpeg(&gain_map_raw, gw, gh, gain_quality)?;

    // 2. Encode primary SDR JPEG
    let base_jpeg =
        crate::export::encode_jpeg(sdr_rgba, width as u32, height as u32, sdr_quality, exif)?;

    // 3. Build XMP metadata segment
    let xmp_seg = build_ultrahdr_xmp_segment(metadata, gain_map_jpeg.len());
    let with_xmp = crate::exif::inject_app1(base_jpeg, &xmp_seg);

    // 4. Build MPF segment with exact byte offsets
    // Dummy MPF length is 96 bytes (4 marker/len + 4 ident + 8 tiff + 46 IFD + 32 entries)
    let dummy_mpf = build_mpf_segment(0, gain_map_jpeg.len(), 2);
    let mpf_len = dummy_mpf.len();
    let final_primary_len = with_xmp.len() + mpf_len;
    let final_mpf = build_mpf_segment(final_primary_len, gain_map_jpeg.len(), 2);

    let with_mpf = crate::exif::inject_app1(with_xmp, &final_mpf);

    // 5. Append secondary gain map directly after primary JPEG
    let mut out = Vec::with_capacity(with_mpf.len() + gain_map_jpeg.len());
    out.extend_from_slice(&with_mpf);
    out.extend_from_slice(&gain_map_jpeg);

    Ok(out)
}

/// Parses an Ultra HDR JPEG file, extracting the secondary gain map bytes and metadata.
pub fn extract_gain_map(jpeg: &[u8]) -> Option<(Vec<u8>, UltraHdrMetadata)> {
    if jpeg.len() < 4 || jpeg[0] != 0xFF || jpeg[1] != 0xD8 {
        return None;
    }

    // 1. Find secondary JPEG by searching for the second SOI (0xFF, 0xD8)
    // Note: SOI marker is 0xFF 0xD8. Primary SOI is at index 0.
    // The second SOI occurs after the primary JPEG EOI (0xFF 0xD9) or via MPF offset.
    let mut secondary_start = None;
    for i in 2..jpeg.len().saturating_sub(1) {
        if jpeg[i] == 0xFF && jpeg[i + 1] == 0xD8 {
            // Check if preceded by 0xFF 0xD9 (primary EOI) or separated by padding
            if i >= 2 && jpeg[i - 2] == 0xFF && jpeg[i - 1] == 0xD9 {
                secondary_start = Some(i);
                break;
            }
        }
    }

    let start = secondary_start?;
    let gain_map_bytes = jpeg[start..].to_vec();

    // 2. Parse metadata from XMP
    let mut meta = UltraHdrMetadata::default();
    if let Some(xmp_str) = extract_xmp_text(jpeg) {
        if let Some(g_max) = parse_xmp_attr(&xmp_str, "hdrgm:GainMapMax=\"") {
            meta.gain_map_max = g_max;
        }
        if let Some(g_min) = parse_xmp_attr(&xmp_str, "hdrgm:GainMapMin=\"") {
            meta.gain_map_min = g_min;
        }
        if let Some(gamma) = parse_xmp_attr(&xmp_str, "hdrgm:Gamma=\"") {
            meta.gamma = gamma;
        }
        if let Some(off_sdr) = parse_xmp_attr(&xmp_str, "hdrgm:OffsetSDR=\"") {
            meta.offset_sdr = off_sdr;
        }
        if let Some(off_hdr) = parse_xmp_attr(&xmp_str, "hdrgm:OffsetHDR=\"") {
            meta.offset_hdr = off_hdr;
        }
    }

    Some((gain_map_bytes, meta))
}

fn extract_xmp_text(jpeg: &[u8]) -> Option<String> {
    let mut i = 2usize;
    while i + 4 <= jpeg.len() {
        if jpeg[i] != 0xFF {
            break;
        }
        let marker = jpeg[i + 1];
        if marker == 0xDA {
            break;
        }
        if marker == 0xD8 || marker == 0x01 || (0xD0..=0xD9).contains(&marker) {
            i += 2;
            continue;
        }
        let len = ((jpeg[i + 2] as usize) << 8) | jpeg[i + 3] as usize;
        let seg_end = i + 2 + len;
        if seg_end > jpeg.len() || len < 2 {
            break;
        }
        if marker == 0xE1 {
            let payload = &jpeg[i + 4..seg_end];
            let header = b"http://ns.adobe.com/xap/1.0/\0";
            if payload.starts_with(header) {
                return String::from_utf8(payload[header.len()..].to_vec()).ok();
            }
        }
        i = seg_end;
    }
    None
}

fn parse_xmp_attr(xmp: &str, prefix: &str) -> Option<f32> {
    let start = xmp.find(prefix)? + prefix.len();
    let end = xmp[start..].find('"')? + start;
    xmp[start..end].parse::<f32>().ok()
}

/// Reconstructs full linear HDR float radiance `[R, G, B]` per pixel by modulating
/// the SDR base pixels with the gain map according to ISO 21496-1.
pub fn reconstruct_hdr_radiance(
    sdr_rgba: &[u8],
    width: usize,
    height: usize,
    gain_map_jpeg: &[u8],
    metadata: &UltraHdrMetadata,
) -> Result<Vec<f32>, String> {
    let gain_img = crate::decode::decode_rgba(gain_map_jpeg)?;
    let mut hdr = vec![0.0f32; width * height * 3];

    let x_scale = gain_img.width as f32 / width as f32;
    let y_scale = gain_img.height as f32 / height as f32;

    for y in 0..height {
        let gy = (((y as f32 + 0.5) * y_scale).floor() as usize).min(gain_img.height - 1);
        for x in 0..width {
            let gx = (((x as f32 + 0.5) * x_scale).floor() as usize).min(gain_img.width - 1);
            let g_idx = (gy * gain_img.width + gx) * 4;
            let g_norm = gain_img.rgba[g_idx] as f32 / 255.0;

            // Invert gamma: gain = gain_min + (g_norm^gamma) * (gain_max - gain_min)
            let gain = metadata.gain_map_min
                + g_norm.powf(metadata.gamma) * (metadata.gain_map_max - metadata.gain_map_min);
            let weight = 2f32.powf(gain);

            let s_idx = (y * width + x) * 4;
            let lin_r = crate::color::srgb_to_linear(sdr_rgba[s_idx] as f32 / 255.0);
            let lin_g = crate::color::srgb_to_linear(sdr_rgba[s_idx + 1] as f32 / 255.0);
            let lin_b = crate::color::srgb_to_linear(sdr_rgba[s_idx + 2] as f32 / 255.0);

            let y_sdr = 0.2126 * lin_r + 0.7152 * lin_g + 0.0722 * lin_b;
            let y_hdr = (y_sdr + metadata.offset_sdr) * weight - metadata.offset_hdr;
            let scale = if y_sdr > 1e-4 {
                (y_hdr / y_sdr).max(0.0)
            } else {
                weight
            };

            let h_idx = (y * width + x) * 3;
            hdr[h_idx] = (lin_r * scale).max(0.0);
            hdr[h_idx + 1] = (lin_g * scale).max(0.0);
            hdr[h_idx + 2] = (lin_b * scale).max(0.0);
        }
    }

    Ok(hdr)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_sdr_image(w: usize, h: usize) -> Vec<u8> {
        let mut rgba = Vec::with_capacity(w * h * 4);
        for y in 0..h {
            for x in 0..w {
                // Gradient with bright specular highlight at top-left
                let bright = if x < 4 && y < 4 { 255u8 } else { 80u8 };
                rgba.extend_from_slice(&[bright, bright, bright, 255]);
            }
        }
        rgba
    }

    #[test]
    fn gain_map_generation_and_jpeg_encode() {
        let sdr = sample_sdr_image(16, 16);
        let meta = UltraHdrMetadata::default();
        let map = generate_gain_map(&sdr, 16, 16, 8, 8, &meta, None);
        assert_eq!(map.len(), 64);
        // Bright specular highlight at top-left should have higher gain than dark regions
        assert!(map[0] > map[63]);

        let jpeg = encode_gain_map_jpeg(&map, 8, 8, 85).expect("must encode");
        assert_eq!(&jpeg[0..2], &[0xFF, 0xD8]);
        assert_eq!(&jpeg[jpeg.len() - 2..], &[0xFF, 0xD9]);
    }

    #[test]
    fn mpf_segment_structure_is_valid() {
        let mpf = build_mpf_segment(10000, 2000, 2);
        assert_eq!(&mpf[0..2], &[0xFF, 0xE2]);
        assert_eq!(&mpf[4..8], b"MPF\0");
        assert_eq!(&mpf[8..10], b"MM"); // Big endian TIFF
    }

    #[test]
    fn xmp_segment_generation_and_parsing() {
        let meta = UltraHdrMetadata {
            gain_map_max: 2.5,
            ..Default::default()
        };
        let seg = build_ultrahdr_xmp_segment(&meta, 1234);
        assert_eq!(&seg[0..2], &[0xFF, 0xE1]);
        let xmp_text = String::from_utf8_lossy(&seg);
        assert!(xmp_text.contains("hdrgm:GainMapMax=\"2.500000\""));
        assert!(xmp_text.contains("Item:Length=\"1234\""));
    }

    #[test]
    fn ultra_hdr_end_to_end_roundtrip() {
        let sdr = sample_sdr_image(16, 16);
        let meta = UltraHdrMetadata {
            gain_map_max: 2.0, // +2 EV headroom
            ..Default::default()
        };

        // 1. Encode Ultra HDR JPEG
        let uhdr_jpeg = encode_ultra_hdr_jpeg(&sdr, 16, 16, 90, 85, &[], &meta, None)
            .expect("must encode Ultra HDR");

        assert!(uhdr_jpeg.len() > 500);

        // 2. Extract Gain Map and Metadata
        let (gain_jpeg, extracted_meta) =
            extract_gain_map(&uhdr_jpeg).expect("must extract gain map");
        assert_eq!(&gain_jpeg[0..2], &[0xFF, 0xD8]);
        assert!((extracted_meta.gain_map_max - 2.0).abs() < 1e-4);

        // 3. Reconstruct HDR Radiance
        let hdr_radiance = reconstruct_hdr_radiance(&sdr, 16, 16, &gain_jpeg, &extracted_meta)
            .expect("must reconstruct radiance");

        assert_eq!(hdr_radiance.len(), 16 * 16 * 3);
        // Highlight at (0,0) should have reconstructed radiance significantly greater than SDR 1.0
        assert!(
            hdr_radiance[0] > 1.5,
            "Recovered highlight: {}",
            hdr_radiance[0]
        );
    }
}
