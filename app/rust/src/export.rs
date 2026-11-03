//! JPEG encode — the final export step. Pure: grading lives in [`crate::color`].
//!
//! The export path grades via `color::grade_pixel_c` (the same pipeline —
//! including tone curves — the preview LUT bakes) and then encodes here, so
//! preview and export share the exact colour math.

use jpeg_encoder::{ColorType, Encoder};

/// Encodes an RGBA8 buffer (`width*height*4`) as a JPEG, dropping alpha. If
/// [exif] is non-empty (a full APP1 segment), it is injected so metadata
/// survives export.
pub fn encode_jpeg(
    rgba: &[u8],
    width: u32,
    height: u32,
    quality: u8,
    exif: &[u8],
) -> Result<Vec<u8>, String> {
    if width == 0 || height == 0 {
        return Err("export dimensions must be at least 1x1".to_string());
    }
    if width > u16::MAX as u32 || height > u16::MAX as u32 {
        return Err(format!(
            "export dimensions {width}x{height} exceed the JPEG limit of {}",
            u16::MAX
        ));
    }
    let expected = width as usize * height as usize * 4;
    if rgba.len() != expected {
        return Err(format!(
            "rgba buffer has {} bytes, expected {expected} for {width}x{height}",
            rgba.len()
        ));
    }

    let mut rgb = Vec::with_capacity(width as usize * height as usize * 3);
    for px in rgba.as_chunks::<4>().0 {
        rgb.extend_from_slice(&[px[0], px[1], px[2]]);
    }

    let mut out = Vec::new();
    Encoder::new(&mut out, quality)
        .encode(&rgb, width as u16, height as u16, ColorType::Rgb)
        .map_err(|e| format!("jpeg encode failed: {e}"))?;
    let final_exif = if !exif.is_empty() {
        let mut exif_buf = exif.to_vec();
        crate::exif::rewrite_orientation_to_normal(&mut exif_buf);
        exif_buf
    } else {
        Vec::new()
    };
    Ok(crate::exif::inject_app1(out, &final_exif))
}

const CRC_TABLE: [u32; 256] = {
    let mut table = [0u32; 256];
    let mut i = 0;
    while i < 256 {
        let mut c = i as u32;
        let mut k = 0;
        while k < 8 {
            if c & 1 != 0 {
                c = 0xEDB88320 ^ (c >> 1);
            } else {
                c >>= 1;
            }
            k += 1;
        }
        table[i] = c;
        i += 1;
    }
    table
};

fn crc32(tag: &[u8; 4], data: &[u8]) -> u32 {
    let mut crc = 0xFFFFFFFFu32;
    for &b in tag {
        crc = CRC_TABLE[((crc ^ (b as u32)) & 0xFF) as usize] ^ (crc >> 8);
    }
    for &b in data {
        crc = CRC_TABLE[((crc ^ (b as u32)) & 0xFF) as usize] ^ (crc >> 8);
    }
    !crc
}

fn write_png_chunk(out: &mut Vec<u8>, tag: &[u8; 4], data: &[u8]) {
    out.extend_from_slice(&(data.len() as u32).to_be_bytes());
    out.extend_from_slice(tag);
    out.extend_from_slice(data);
    let crc = crc32(tag, data);
    out.extend_from_slice(&crc.to_be_bytes());
}

/// Encodes an RGBA8 buffer (`width * height * 4`) as a lossless PNG.
///
/// Uses `miniz_oxide` deflate compression with 0 external dependencies.
pub fn encode_png(rgba: &[u8], width: u32, height: u32) -> Result<Vec<u8>, String> {
    if width == 0 || height == 0 {
        return Err("export dimensions must be at least 1x1".to_string());
    }
    let expected = width as usize * height as usize * 4;
    if rgba.len() != expected {
        return Err(format!(
            "rgba buffer has {} bytes, expected {expected} for {width}x{height}",
            rgba.len()
        ));
    }

    let row_len = width as usize * 4;
    let mut raw_data = Vec::with_capacity(height as usize * (row_len + 1));
    for y in 0..height as usize {
        raw_data.push(0); // Filter type 0 (None)
        let start = y * row_len;
        raw_data.extend_from_slice(&rgba[start..start + row_len]);
    }

    let compressed = miniz_oxide::deflate::compress_to_vec_zlib(&raw_data, 6);

    let mut out = Vec::with_capacity(compressed.len() + 64);
    out.extend_from_slice(b"\x89PNG\r\n\x1a\n");

    let mut ihdr = Vec::with_capacity(13);
    ihdr.extend_from_slice(&width.to_be_bytes());
    ihdr.extend_from_slice(&height.to_be_bytes());
    ihdr.push(8); // Bit depth: 8
    ihdr.push(6); // Color type: 6 (RGBA)
    ihdr.push(0); // Compression: 0 (deflate)
    ihdr.push(0); // Filter: 0
    ihdr.push(0); // Interlace: 0
    write_png_chunk(&mut out, b"IHDR", &ihdr);

    write_png_chunk(&mut out, b"IDAT", &compressed);
    write_png_chunk(&mut out, b"IEND", &[]);

    Ok(out)
}

/// Helper to write an ISO-BMFF box (4 bytes BE length, 4 bytes tag, payload).
fn write_isobmff_box(out: &mut Vec<u8>, tag: &[u8; 4], payload: &[u8]) {
    let size = (payload.len() + 8) as u32;
    out.extend_from_slice(&size.to_be_bytes());
    out.extend_from_slice(tag);
    out.extend_from_slice(payload);
}

/// Helper to build a complete ISO-BMFF container for HEIC/AVIF encapsulation (#175).
///
/// The payload is always a JPEG bitstream (no HEVC/AV1 encoder available), so
/// the honest brand combination is major `mif1` + compatible `jpeg` — NOT
/// `heic`/`avif` which would declare HEVC/AV1 compatibility we don't have.
/// An `iinf`/`infe` box with `item_type = "jpeg"` is mandatory for a valid
/// HEIF container.
fn encode_isobmff_container(
    rgba: &[u8],
    width: u32,
    height: u32,
    quality: u8,
    major_brand: &[u8; 4],
    compatible_brands: &[&[u8; 4]],
) -> Result<Vec<u8>, String> {
    if width == 0 || height == 0 {
        return Err("export dimensions must be at least 1x1".to_string());
    }
    let expected = width as usize * height as usize * 4;
    if rgba.len() != expected {
        return Err(format!(
            "rgba buffer has {} bytes, expected {expected} for {width}x{height}",
            rgba.len()
        ));
    }

    // 1. Encode primary image payload (always JPEG — no HEVC/AV1 encoder).
    let payload = encode_jpeg(rgba, width, height, quality, &[])?;

    let mut out = Vec::with_capacity(payload.len() + 512);

    // 2. ftyp box
    let mut ftyp_payload = Vec::new();
    ftyp_payload.extend_from_slice(major_brand);
    ftyp_payload.extend_from_slice(&0u32.to_be_bytes()); // minor version
    for brand in compatible_brands {
        ftyp_payload.extend_from_slice(*brand);
    }
    write_isobmff_box(&mut out, b"ftyp", &ftyp_payload);

    // 3. meta box (FullBox: version 0, flags 0)
    let mut meta_content = Vec::new();
    meta_content.extend_from_slice(&[0, 0, 0, 0]); // version 0, flags 0

    // 3a. hdlr box
    let mut hdlr = Vec::new();
    hdlr.extend_from_slice(&[0, 0, 0, 0]); // version/flags
    hdlr.extend_from_slice(&[0, 0, 0, 0]); // pre_defined
    hdlr.extend_from_slice(b"pict"); // handler_type
    hdlr.extend_from_slice(&[0u8; 12]); // reserved
    hdlr.extend_from_slice(b"Picture\0"); // name
    write_isobmff_box(&mut meta_content, b"hdlr", &hdlr);

    // 3b. pitm box (primary item id = 1)
    let mut pitm = Vec::new();
    pitm.extend_from_slice(&[0, 0, 0, 0]); // version/flags
    pitm.extend_from_slice(&1u16.to_be_bytes()); // item_ID
    write_isobmff_box(&mut meta_content, b"pitm", &pitm);

    // 3c. iinf box (item info) + infe entry (item_type = "jpeg")
    let mut iinf = Vec::new();
    iinf.extend_from_slice(&[0, 0, 0, 0]); // version/flags
    iinf.extend_from_slice(&1u16.to_be_bytes()); // entry_count = 1

    let mut infe = Vec::new();
    infe.extend_from_slice(&[0, 0, 0, 0]); // version/flags
    infe.extend_from_slice(&1u16.to_be_bytes()); // item_ID = 1
    infe.extend_from_slice(b"jpeg\0"); // item_type = "jpeg" (null-terminated)
    infe.extend_from_slice(&[0]); // item_name = empty (null-terminated)
    write_isobmff_box(&mut iinf, b"infe", &infe);

    write_isobmff_box(&mut meta_content, b"iinf", &iinf);

    // 3d. iprp box (item properties) -> ipco -> ispe
    let mut ipco = Vec::new();
    let mut ispe = Vec::new();
    ispe.extend_from_slice(&[0, 0, 0, 0]); // version/flags
    ispe.extend_from_slice(&width.to_be_bytes());
    ispe.extend_from_slice(&height.to_be_bytes());
    write_isobmff_box(&mut ipco, b"ispe", &ispe);

    let mut pixi = Vec::new();
    pixi.extend_from_slice(&[0, 0, 0, 0]);
    pixi.push(3); // 3 channels
    pixi.extend_from_slice(&[8, 8, 8]);
    write_isobmff_box(&mut ipco, b"pixi", &pixi);

    let mut iprp = Vec::new();
    write_isobmff_box(&mut iprp, b"ipco", &ipco);

    let mut ipma = Vec::new();
    ipma.extend_from_slice(&[0, 0, 0, 0]); // version/flags
    ipma.extend_from_slice(&1u32.to_be_bytes()); // entry count
    ipma.extend_from_slice(&1u16.to_be_bytes()); // item id = 1
    ipma.push(1); // 1 association
    ipma.push(1); // property index 1 (ispe)
    write_isobmff_box(&mut iprp, b"ipma", &ipma);

    write_isobmff_box(&mut meta_content, b"iprp", &iprp);

    // 3e. iloc box (item location: offset & length)
    let meta_box_size = meta_content.len() + 8;
    let iloc_size = 30;
    let total_meta_size = (meta_box_size + iloc_size) as u32;
    let mdat_header_size = 8u32;
    let payload_offset = out.len() as u32 + total_meta_size + mdat_header_size;

    let mut iloc = Vec::new();
    iloc.extend_from_slice(&[0, 0, 0, 0]); // version/flags
    iloc.push(0x44); // offset_size: 4, length_size: 4
    iloc.push(0x00); // base_offset_size: 0, index_size: 0
    iloc.extend_from_slice(&1u16.to_be_bytes()); // item_count = 1
    iloc.extend_from_slice(&1u16.to_be_bytes()); // item_id = 1
    iloc.extend_from_slice(&0u16.to_be_bytes()); // data_reference_index = 0
    iloc.extend_from_slice(&1u16.to_be_bytes()); // extent_count = 1
    iloc.extend_from_slice(&payload_offset.to_be_bytes()); // extent_offset
    iloc.extend_from_slice(&(payload.len() as u32).to_be_bytes()); // extent_length
    write_isobmff_box(&mut meta_content, b"iloc", &iloc);

    write_isobmff_box(&mut out, b"meta", &meta_content);

    // 4. mdat box containing image bitstream
    write_isobmff_box(&mut out, b"mdat", &payload);

    Ok(out)
}

/// Encodes an RGBA8 buffer into an ISO-BMFF HEIF container with JPEG payload (#175).
///
/// Honest brands: major `mif1`, compatible `jpeg`. Does NOT claim HEVC
/// compatibility (no `heic` brand) since the payload is plain JPEG.
pub fn encode_heic(rgba: &[u8], width: u32, height: u32, quality: u8) -> Result<Vec<u8>, String> {
    encode_isobmff_container(rgba, width, height, quality, b"mif1", &[b"mif1", b"jpeg"])
}

/// Encodes an RGBA8 buffer into an ISO-BMFF container with JPEG payload (#175).
///
/// Honest brands: major `mif1`, compatible `jpeg`. The `avif` name is retained
/// for API compatibility but the container is really HEIF/JPEG — no AV1 item
/// exists (no AV1 encoder available). A real AVIF would require rav1e/svt-av1.
pub fn encode_avif(rgba: &[u8], width: u32, height: u32, quality: u8) -> Result<Vec<u8>, String> {
    encode_isobmff_container(rgba, width, height, quality, b"mif1", &[b"mif1", b"jpeg"])
}

#[cfg(test)]
mod tests {
    use super::*;

    fn solid_rgba(width: u32, height: u32, r: u8, g: u8, b: u8) -> Vec<u8> {
        let mut v = Vec::with_capacity(width as usize * height as usize * 4);
        for _ in 0..width * height {
            v.extend_from_slice(&[r, g, b, 255]);
        }
        v
    }

    #[test]
    fn lower_quality_produces_a_smaller_file() {
        let mut src = Vec::new();
        for y in 0..64 {
            for x in 0..64 {
                src.extend_from_slice(&[(x * 3 + y) as u8, (x ^ y) as u8, (x + y * 2) as u8, 255]);
            }
        }
        let hi = encode_jpeg(&src, 64, 64, 95, &[]).unwrap();
        let lo = encode_jpeg(&src, 64, 64, 20, &[]).unwrap();
        assert!(
            lo.len() < hi.len(),
            "quality 20 ({}) should beat 95 ({})",
            lo.len(),
            hi.len()
        );
    }

    #[test]
    fn rejects_a_mismatched_buffer_length() {
        let err = encode_jpeg(&[0u8; 9], 2, 2, 90, &[]).unwrap_err();
        assert!(err.contains("expected 16"), "got: {err}");
    }

    #[test]
    fn rejects_zero_dimensions() {
        assert!(encode_jpeg(&[], 0, 10, 90, &[]).is_err());
        assert!(encode_jpeg(&[], 10, 0, 90, &[]).is_err());
    }

    #[test]
    fn encodes_a_decodable_jpeg_and_drops_alpha() {
        let jpeg = encode_jpeg(&solid_rgba(8, 8, 200, 100, 50), 8, 8, 90, &[]).unwrap();
        assert_eq!(crate::decode::dimensions(&jpeg).unwrap(), (8, 8));
    }

    #[test]
    fn round_trips_colour_within_jpeg_tolerance() {
        let jpeg = encode_jpeg(&solid_rgba(32, 32, 128, 128, 128), 32, 32, 95, &[]).unwrap();
        let img = crate::decode::decode_rgba(&jpeg).unwrap();
        let mean = img
            .rgba
            .as_chunks::<4>()
            .0
            .iter()
            .map(|p| p[0] as f64)
            .sum::<f64>()
            / (img.rgba.len() / 4) as f64;
        assert!((mean - 128.0).abs() < 4.0, "mean {mean}");
    }

    #[test]
    fn rewrites_exif_orientation_to_normal_on_export() {
        let tiff = vec![
            b'I', b'I', 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00, 0x01, 0x00, 0x12, 0x01, 0x03, 0x00,
            0x01, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ];
        let payload_len = 6 + tiff.len();
        let mut app1 = vec![
            0xFF,
            0xE1,
            ((payload_len + 2) >> 8) as u8,
            ((payload_len + 2) & 0xFF) as u8,
        ];
        app1.extend_from_slice(b"Exif\0\0");
        app1.extend_from_slice(&tiff);

        assert_eq!(crate::exif::parse_orientation(&app1), Some(6));

        let jpeg = encode_jpeg(&solid_rgba(8, 8, 100, 100, 100), 8, 8, 90, &app1).unwrap();
        assert_eq!(crate::exif::parse_orientation(&jpeg), Some(1));
    }

    #[test]
    fn encode_png_produces_decodable_png_with_exact_pixels() {
        let rgba = solid_rgba(16, 12, 120, 200, 250);
        let png = encode_png(&rgba, 16, 12).expect("encode_png should succeed");
        assert_eq!(&png[..8], b"\x89PNG\r\n\x1a\n");

        let (decoded, w, h) = crate::watermark::decode_png_rgba(&png).expect("decodable png");
        assert_eq!((w, h), (16, 12));
        assert_eq!(decoded.len(), 16 * 12 * 4);
        assert_eq!(decoded, rgba);
    }

    #[test]
    fn encode_png_rejects_invalid_dimensions() {
        assert!(encode_png(&[], 0, 10).is_err());
        assert!(encode_png(&[], 10, 0).is_err());
        assert!(encode_png(&[0u8; 10], 4, 4).is_err());
    }

    #[test]
    fn encode_heic_produces_valid_isobmff_container_with_ispe() {
        let rgba = solid_rgba(32, 24, 180, 140, 90);
        let bytes = encode_heic(&rgba, 32, 24, 90).expect("encode_heic should succeed");
        // Verify ftyp header with major brand "mif1" (not "heic" — no HEVC)
        assert_eq!(&bytes[4..8], b"ftyp");
        assert_eq!(&bytes[8..12], b"mif1");

        // Verify iinf/infe box with item_type "jpeg"
        let iinf_pos = bytes
            .windows(4)
            .position(|w| w == b"iinf")
            .expect("iinf box must exist in heic container");
        assert!(
            bytes[iinf_pos..].windows(6).any(|w| w == b"infe\0\0"),
            "infe box must exist inside iinf"
        );
        let infe_pos = bytes
            .windows(5)
            .position(|w| w == b"jpeg\0")
            .expect("item_type 'jpeg' must exist in infe box");

        // Verify ispe spatial dimensions exist in container
        let ispe_pos = bytes
            .windows(4)
            .position(|w| w == b"ispe")
            .expect("ispe box must exist in heic container");
        let w = u32::from_be_bytes(bytes[ispe_pos + 8..ispe_pos + 12].try_into().unwrap());
        let h = u32::from_be_bytes(bytes[ispe_pos + 12..ispe_pos + 16].try_into().unwrap());
        assert_eq!((w, h), (32, 24));

        // item_type must appear before ispe (both inside meta)
        assert!(infe_pos < ispe_pos, "infe item_type must precede ispe");
    }

    #[test]
    fn encode_avif_produces_valid_isobmff_container_with_ispe() {
        let rgba = solid_rgba(40, 30, 200, 100, 50);
        let bytes = encode_avif(&rgba, 40, 30, 85).expect("encode_avif should succeed");
        // Verify ftyp header with major brand "mif1" (not "avif" — no AV1)
        assert_eq!(&bytes[4..8], b"ftyp");
        assert_eq!(&bytes[8..12], b"mif1");

        // Verify iinf/infe box with item_type "jpeg"
        let iinf_pos = bytes
            .windows(4)
            .position(|w| w == b"iinf")
            .expect("iinf box must exist in avif container");
        assert!(
            bytes[iinf_pos..].windows(6).any(|w| w == b"infe\0\0"),
            "infe box must exist inside iinf"
        );
        let infe_pos = bytes
            .windows(5)
            .position(|w| w == b"jpeg\0")
            .expect("item_type 'jpeg' must exist in infe box");

        // Verify ispe spatial dimensions exist in container
        let ispe_pos = bytes
            .windows(4)
            .position(|w| w == b"ispe")
            .expect("ispe box must exist in avif container");
        let w = u32::from_be_bytes(bytes[ispe_pos + 8..ispe_pos + 12].try_into().unwrap());
        let h = u32::from_be_bytes(bytes[ispe_pos + 12..ispe_pos + 16].try_into().unwrap());
        assert_eq!((w, h), (40, 30));

        // item_type must appear before ispe (both inside meta)
        assert!(infe_pos < ispe_pos, "infe item_type must precede ispe");
    }
}
