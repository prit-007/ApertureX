//! RAW/DNG decode (ADR 0005: rawler-first).
//!
//! Phase C selected the pure-Rust `rawler` decoder (LGPL-2.1) for the default
//! build against the LibRaw alternative; see `docs/spikes/raw-engine-spike.md`.
//! The decoder surface here is deliberately neutral: [`decode`] returns
//! scene-linear camera RGB and [`metadata`] returns the tags the colour pipeline
//! needs (white balance, camera matrices, orientation). Colour transforms and
//! optics corrections are added in the Phase D submodules so preview and export
//! share one path.
//!
//! LibRaw remains available only behind the `raw-libraw` feature as a future
//! camera-coverage fallback and is not part of the default build.

use std::io::Cursor;

use rawler::dng::writer::DngWriter;
use rawler::dng::{CropMode, DngCompression, DngPhotometricConversion};
use rawler::imgop::xyz::Illuminant as RawlerIlluminant;
use rawler::rawimage::RawImageData;
use rawler::rawsource::RawSource;

/// A 3x3 colour matrix in row-major order.
pub type Mat3 = [[f32; 3]; 3];

/// DNG calibration illuminant, reduced to the cases that affect adaptation.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Illuminant {
    /// CIE D65 (~6504 K), the sRGB reference white.
    D65,
    /// CIE D50 (~5003 K), the ICC/DNG default profile white.
    D50,
    /// Any other calibration illuminant; treated as D65 for output adaptation.
    Other,
}

impl Illuminant {
    fn from_rawler(i: RawlerIlluminant) -> Self {
        match i {
            RawlerIlluminant::D65 | RawlerIlluminant::Daylight => Illuminant::D65,
            RawlerIlluminant::D50 => Illuminant::D50,
            _ => Illuminant::Other,
        }
    }
}

/// EXIF orientation, mirrored from `rawler` but without leaking its type.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RawOrientation {
    Normal,
    HorizontalFlip,
    Rotate180,
    VerticalFlip,
    Transpose,
    Rotate90,
    Transverse,
    Rotate270,
    Unknown,
}

impl RawOrientation {
    /// Clockwise rotation needed to display the frame upright.
    pub fn degrees(self) -> i32 {
        match self {
            RawOrientation::Rotate90 => 90,
            RawOrientation::Rotate180 => 180,
            RawOrientation::Rotate270 => 270,
            _ => 0,
        }
    }

    /// Whether the orientation swaps width and height for display.
    pub fn swaps_axes(self) -> bool {
        matches!(
            self,
            RawOrientation::Transpose
                | RawOrientation::Rotate90
                | RawOrientation::Transverse
                | RawOrientation::Rotate270
        )
    }

    /// `(transpose, flip_horizontal, flip_vertical)` in EXIF order. Flips must be
    /// applied before the transpose (matches `rawler::Orientation::to_flips`).
    /// `Unknown` is treated as [`RawOrientation::Normal`].
    pub fn to_flips(self) -> (bool, bool, bool) {
        match self {
            RawOrientation::Normal | RawOrientation::Unknown => (false, false, false),
            RawOrientation::VerticalFlip => (false, false, true),
            RawOrientation::HorizontalFlip => (false, true, false),
            RawOrientation::Rotate180 => (false, true, true),
            RawOrientation::Transpose => (true, false, false),
            RawOrientation::Rotate90 => (true, false, true),
            RawOrientation::Transverse => (true, true, true),
            RawOrientation::Rotate270 => (true, true, false),
        }
    }
}

/// A 2x2 RGB Bayer colour-filter pattern.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CfaPattern {
    /// Red, Green / Green, Blue.
    Rggb,
    /// Blue, Green / Green, Red.
    Bggr,
    /// Green, Red / Blue, Green.
    Grbg,
    /// Green, Blue / Red, Green.
    Gbrg,
}

impl CfaPattern {
    /// Builds a pattern from a 2x2 block of channel indices (0=R, 1=G, 2=B).
    pub fn from_colors(
        top_left: u8,
        top_right: u8,
        bottom_left: u8,
        bottom_right: u8,
    ) -> Option<Self> {
        match (top_left, top_right, bottom_left, bottom_right) {
            (0, 1, 1, 2) => Some(CfaPattern::Rggb),
            (2, 1, 1, 0) => Some(CfaPattern::Bggr),
            (1, 0, 2, 1) => Some(CfaPattern::Grbg),
            (1, 2, 0, 1) => Some(CfaPattern::Gbrg),
            _ => None,
        }
    }

    /// Channel index (0=R, 1=G, 2=B) at `(x, y)`.
    pub fn color_at(self, x: usize, y: usize) -> u8 {
        let (even_x, even_y) = (x.is_multiple_of(2), y.is_multiple_of(2));
        match self {
            CfaPattern::Rggb => match (even_x, even_y) {
                (true, true) => 0,
                (false, false) => 2,
                _ => 1,
            },
            CfaPattern::Bggr => match (even_x, even_y) {
                (true, true) => 2,
                (false, false) => 0,
                _ => 1,
            },
            CfaPattern::Grbg => match (even_x, even_y) {
                (true, true) => 1,
                (false, false) => 1,
                (false, true) => 0,
                (true, false) => 2,
            },
            CfaPattern::Gbrg => match (even_x, even_y) {
                (true, true) => 1,
                (false, false) => 1,
                (false, true) => 2,
                (true, false) => 0,
            },
        }
    }
}

/// Metadata required to render a RAW frame into working colour.
#[derive(Debug, Clone, PartialEq)]
pub struct RawMetadata {
    pub width: usize,
    pub height: usize,
    /// Components per pixel (1 = Bayer/CFA, 3 = LinearRaw RGB).
    pub cpp: usize,
    pub orientation: RawOrientation,
    /// As-shot white-balance multipliers in RGBE order.
    pub wb_coeffs: [f32; 4],
    /// Preferred DNG camera matrix (XYZ → camera) and its illuminant, if present.
    pub color_matrix: Option<(Illuminant, Mat3)>,
    /// Optional DCP/DNG HueSatMap for Adobe Standard color rendition.
    pub hue_sat_map: Option<color::HueSatMap>,
    /// Lens vignette polynomial coefficients [k1, k2, k3].
    pub lens_vignette: Option<[f32; 3]>,
    /// Lens radial distortion coefficients [k1, k2, k3].
    pub lens_distortion: Option<[f32; 3]>,
    /// Camera make string.
    pub make: Option<String>,
    /// Camera model string.
    pub model: Option<String>,
}

/// Scene-linear camera RGB, normalised so full scale maps to `1.0`.
#[derive(Debug, Clone, PartialEq)]
pub struct RawLinearImage {
    pub width: usize,
    pub height: usize,
    /// `width * height * 3` samples in RGB order.
    pub data: Vec<f32>,
}

fn decode_raw(bytes: &[u8]) -> Result<rawler::rawimage::RawImage, String> {
    let src = RawSource::new_from_slice(bytes);
    rawler::decode(&src, &rawler::decoders::RawDecodeParams::default())
        .map_err(|e| format!("rawler decode: {e:?}"))
}

/// Exports raw camera CFA samples into a lossless DNG format with injected XMP sidecar (#79).
///
/// Preserves the original CFA stream verbatim via lossless compression (LJPEG-92)
/// without demosaic or bit-depth degradation (shape (a)). Injects XMP packet
/// into the standard TIFF `ApplicationNotes` (tag 0x02BC) IFD directory.
pub fn export_dng(raw_bytes: &[u8], xmp: &str) -> Result<Vec<u8>, String> {
    let raw = decode_raw(raw_bytes)?;
    let mut buf = Cursor::new(Vec::new());
    let mut writer =
        DngWriter::new(&mut buf, [1, 4, 0, 0]).map_err(|e| format!("DngWriter new: {e:?}"))?;

    writer
        .load_base_tags(&raw)
        .map_err(|e| format!("load_base_tags: {e:?}"))?;

    let mut subframe = writer.subframe(0);
    subframe
        .raw_image(
            &raw,
            CropMode::None,
            DngCompression::Lossless,
            DngPhotometricConversion::Original,
            1,
        )
        .map_err(|e| format!("subframe raw_image: {e:?}"))?;
    subframe
        .finalize()
        .map_err(|e| format!("subframe finalize: {e:?}"))?;

    if !xmp.is_empty() {
        writer
            .xpacket(xmp.as_bytes())
            .map_err(|e| format!("writer xpacket: {e:?}"))?;
    }

    writer.close().map_err(|e| format!("writer close: {e:?}"))?;

    Ok(buf.into_inner())
}

fn flat_to_mat3(flat: &[f32]) -> Option<Mat3> {
    if flat.len() != 9 {
        return None;
    }
    Some([
        [flat[0], flat[1], flat[2]],
        [flat[3], flat[4], flat[5]],
        [flat[6], flat[7], flat[8]],
    ])
}

/// Parse a DCP ProfileHueSatMapData1 block (tag 0xC74E) into a HueSatMap.
///
/// Layout: HueDivs (u32 BE), SatDivs (u32 BE), ValDivs (u32 BE),
/// then hue_divs * sat_divs * val_divs * 3 float64 BE values of
/// [hue_shift_deg, sat_scale, val_scale] per cell.
fn parse_hue_sat_map(data: &[u8]) -> Option<color::HueSatMap> {
    if data.len() < 12 {
        return None;
    }
    let hue_divs = u32::from_be_bytes(data[0..4].try_into().unwrap_or_default()) as usize;
    let sat_divs = u32::from_be_bytes(data[4..8].try_into().unwrap_or_default()) as usize;
    let val_divs = u32::from_be_bytes(data[8..12].try_into().unwrap_or_default()) as usize;
    let expected = hue_divs * sat_divs * val_divs * 3;
    if hue_divs == 0 || sat_divs == 0 || val_divs == 0 {
        return None;
    }
    if data.len() < 12 + expected * 8 {
        return None;
    }
    let mut deltas = Vec::with_capacity(expected);
    let mut offset = 12;
    for _ in 0..expected {
        let d1 = f64::from_be_bytes(data[offset..offset + 8].try_into().unwrap_or_default()) as f32;
        let d2 =
            f64::from_be_bytes(data[offset + 8..offset + 16].try_into().unwrap_or_default()) as f32;
        let d3 = f64::from_be_bytes(
            data[offset + 16..offset + 24]
                .try_into()
                .unwrap_or_default(),
        ) as f32;
        deltas.push(d1);
        deltas.push(d2);
        deltas.push(d3);
        offset += 24;
    }
    color::HueSatMap::new(hue_divs, sat_divs, val_divs, deltas)
}

fn parse_opcode_list(
    data: &[u8],
    lens_vignette: &mut Option<[f32; 3]>,
    lens_distortion: &mut Option<[f32; 3]>,
) {
    if data.len() < 4 {
        return;
    }
    let count = u32::from_be_bytes(data[0..4].try_into().unwrap_or_default()) as usize;
    let mut offset = 4;
    for _ in 0..count {
        if offset + 16 > data.len() {
            break;
        }
        let id = u32::from_be_bytes(data[offset..offset + 4].try_into().unwrap_or_default());
        let size = u32::from_be_bytes(
            data[offset + 12..offset + 16]
                .try_into()
                .unwrap_or_default(),
        ) as usize;
        offset += 16;
        if offset + size > data.len() {
            break;
        }
        let payload = &data[offset..offset + size];
        offset += size;

        match id {
            1 if payload.len() >= 4 + 4 * 8 => {
                // WarpRectilinear
                let k1 = f64::from_be_bytes(payload[12..20].try_into().unwrap_or_default()) as f32;
                let k2 = f64::from_be_bytes(payload[20..28].try_into().unwrap_or_default()) as f32;
                let k3 = f64::from_be_bytes(payload[28..36].try_into().unwrap_or_default()) as f32;
                *lens_distortion = Some([k1, k2, k3]);
            }
            3 if payload.len() >= 5 * 8 => {
                // FixVignetteRadial
                let k1 = f64::from_be_bytes(payload[8..16].try_into().unwrap_or_default()) as f32;
                let k2 = f64::from_be_bytes(payload[16..24].try_into().unwrap_or_default()) as f32;
                let k3 = f64::from_be_bytes(payload[24..32].try_into().unwrap_or_default()) as f32;
                *lens_vignette = Some([k1, k2, k3]);
            }
            _ => {}
        }
    }
}

fn metadata_from_raw(raw: &rawler::rawimage::RawImage) -> RawMetadata {
    let color_matrix = raw
        .color_matrix_find_first([
            RawlerIlluminant::D65,
            RawlerIlluminant::Daylight,
            RawlerIlluminant::D50,
            RawlerIlluminant::A,
            RawlerIlluminant::Unknown,
        ])
        .and_then(|(illu, flat)| flat_to_mat3(&flat).map(|m| (Illuminant::from_rawler(illu), m)));

    let mut lens_vignette = None;
    let mut lens_distortion = None;
    let mut hue_sat_map = None;

    for tag in [0xC74Eu16, 0xC740u16, 0xC74Fu16] {
        if let Some(
            rawler::formats::tiff::value::Value::Byte(bytes)
            | rawler::formats::tiff::value::Value::Undefined(bytes),
        ) = raw.dng_tags.get(&tag)
        {
            match tag {
                0xC74E => {
                    // ProfileHueSatMapData1 — DCP HueSatMap
                    if let Some(hsm) = parse_hue_sat_map(bytes) {
                        hue_sat_map = Some(hsm);
                    }
                }
                _ => {
                    parse_opcode_list(bytes, &mut lens_vignette, &mut lens_distortion);
                }
            }
        }
    }

    let make = if !raw.clean_make.is_empty() {
        Some(raw.clean_make.clone())
    } else if !raw.make.is_empty() {
        Some(raw.make.clone())
    } else {
        None
    };
    let model = if !raw.clean_model.is_empty() {
        Some(raw.clean_model.clone())
    } else if !raw.model.is_empty() {
        Some(raw.model.clone())
    } else {
        None
    };

    RawMetadata {
        width: raw.width,
        height: raw.height,
        cpp: raw.cpp,
        orientation: match raw.orientation {
            rawler::decoders::Orientation::Normal => RawOrientation::Normal,
            rawler::decoders::Orientation::HorizontalFlip => RawOrientation::HorizontalFlip,
            rawler::decoders::Orientation::Rotate180 => RawOrientation::Rotate180,
            rawler::decoders::Orientation::VerticalFlip => RawOrientation::VerticalFlip,
            rawler::decoders::Orientation::Transpose => RawOrientation::Transpose,
            rawler::decoders::Orientation::Rotate90 => RawOrientation::Rotate90,
            rawler::decoders::Orientation::Transverse => RawOrientation::Transverse,
            rawler::decoders::Orientation::Rotate270 => RawOrientation::Rotate270,
            rawler::decoders::Orientation::Unknown => RawOrientation::Unknown,
        },
        wb_coeffs: raw.wb_coeffs,
        color_matrix,
        hue_sat_map,
        lens_vignette,
        lens_distortion,
        make,
        model,
    }
}

/// Reads RAW/DNG metadata without decoding pixel data into our working buffers.
pub fn metadata(bytes: &[u8]) -> Result<RawMetadata, String> {
    Ok(metadata_from_raw(&decode_raw(bytes)?))
}

/// Decodes a RAW/DNG into scene-linear camera RGB and its metadata.
///
/// Decodes the source once; use this over [`metadata`] + [`decode`] when both
/// are needed (the FFI entry point does).
pub fn decode_with_metadata(bytes: &[u8]) -> Result<(RawLinearImage, RawMetadata), String> {
    let raw = decode_raw(bytes)?;
    let meta = metadata_from_raw(&raw);
    let img = decode_from_raw(raw)?;
    Ok((img, meta))
}

/// Decodes a RAW/DNG into scene-linear camera RGB normalised to `0.0..=1.0`.
///
/// Handles both 3-component LinearRaw sources and single-channel Bayer/CFA
/// sources (demosaiced via [`demosaic_bilinear`]).
pub fn decode(bytes: &[u8]) -> Result<RawLinearImage, String> {
    decode_from_raw(decode_raw(bytes)?)
}

fn decode_from_raw(raw: rawler::rawimage::RawImage) -> Result<RawLinearImage, String> {
    let meta = metadata_from_raw(&raw);
    let samples = raw.data.as_f32();
    let is_float = matches!(&raw.data, RawImageData::Float(_));
    let white = raw
        .whitelevel
        .0
        .iter()
        .copied()
        .max()
        .unwrap_or(u16::MAX as u32) as f32;
    let normalize = |v: f32| {
        let linear = if is_float { v } else { v / white };
        linear.clamp(0.0, 1.0)
    };

    let flips = raw.orientation.to_flips();
    let img = match raw.cpp {
        3 => {
            let expected = raw.width * raw.height * 3;
            if samples.len() != expected {
                return Err(format!(
                    "raw decode: {} samples, expected {expected}",
                    samples.len()
                ));
            }
            let mut data: Vec<f32> = samples.iter().map(|&v| normalize(v)).collect();
            reconstruct_highlights(&mut data, raw.width, raw.height, 0.99, None);
            let mut linear = RawLinearImage {
                width: raw.width,
                height: raw.height,
                data,
            };
            if let Some(k) = meta.lens_vignette {
                lens::correct_vignette(&mut linear, &k);
            }
            if let Some(k) = meta.lens_distortion {
                lens::correct_distortion(&mut linear, &k);
            }
            if let Some(hsm) = &meta.hue_sat_map {
                hsm.apply_to_rgb(&mut linear.data);
            }
            Ok(linear)
        }
        1 => {
            let expected = raw.width * raw.height;
            if samples.len() != expected {
                return Err(format!(
                    "raw decode: {} samples, expected {expected}",
                    samples.len()
                ));
            }
            let cfa = &raw.camera.cfa;
            let pattern = CfaPattern::from_colors(
                cfa.color_at(0, 0) as u8,
                cfa.color_at(0, 1) as u8,
                cfa.color_at(1, 0) as u8,
                cfa.color_at(1, 1) as u8,
            )
            .ok_or_else(|| format!("raw decode: unsupported CFA pattern '{}'", cfa.name))?;
            let mosaic: Vec<f32> = samples.iter().map(|&v| normalize(v)).collect();
            let mut data = demosaic_bilinear(&mosaic, raw.width, raw.height, pattern)?;
            reconstruct_highlights(&mut data, raw.width, raw.height, 0.99, Some(&raw.wb_coeffs));
            apply_white_balance(&mut data, &raw.wb_coeffs);
            let mut linear = RawLinearImage {
                width: raw.width,
                height: raw.height,
                data,
            };
            if let Some(k) = meta.lens_vignette {
                lens::correct_vignette(&mut linear, &k);
            }
            if let Some(k) = meta.lens_distortion {
                lens::correct_distortion(&mut linear, &k);
            }
            if let Some(hsm) = &meta.hue_sat_map {
                hsm.apply_to_rgb(&mut linear.data);
            }
            Ok(linear)
        }
        other => Err(format!(
            "raw decode: unsupported components per pixel ({other})"
        )),
    }?;
    Ok(orient_image(img, flips.0, flips.1, flips.2))
}

/// Applies an EXIF [RawOrientation] to decoded RGB, returning an upright image.
pub fn apply_orientation(img: &RawLinearImage, orientation: RawOrientation) -> RawLinearImage {
    let (transpose, flip_h, flip_v) = orientation.to_flips();
    orient_image(
        RawLinearImage {
            width: img.width,
            height: img.height,
            data: img.data.clone(),
        },
        transpose,
        flip_h,
        flip_v,
    )
}

/// Transforms interleaved RGB by mirroring and/or transposing.
///
/// Order matters: horizontal/vertical flips run first, then the transpose swaps
/// the axes (output dimensions become `height × width`). This is the EXIF
/// convention and matches `rawler::Orientation::to_flips`.
fn orient_image(
    img: RawLinearImage,
    transpose: bool,
    flip_h: bool,
    flip_v: bool,
) -> RawLinearImage {
    let (w, h) = (img.width, img.height);
    let mut data = img.data;
    if flip_h {
        for y in 0..h {
            let row = &mut data[y * w * 3..(y + 1) * w * 3];
            for x in 0..w / 2 {
                let (a, b) = (x * 3, (w - 1 - x) * 3);
                for c in 0..3 {
                    row.swap(a + c, b + c);
                }
            }
        }
    }
    if flip_v {
        let stride = w * 3;
        for y in 0..h / 2 {
            let (top, bot) = (y * stride, (h - 1 - y) * stride);
            for i in 0..stride {
                data.swap(top + i, bot + i);
            }
        }
    }
    if !transpose {
        return RawLinearImage {
            width: w,
            height: h,
            data,
        };
    }
    let mut out = vec![0.0_f32; data.len()];
    for y in 0..h {
        for x in 0..w {
            let src = (y * w + x) * 3;
            let dst = (x * h + y) * 3;
            out[dst..dst + 3].copy_from_slice(&data[src..src + 3]);
        }
    }
    RawLinearImage {
        width: h,
        height: w,
        data: out,
    }
}

/// The calibrated camera matrix (`XYZ → camera`) and its working-white flag.
///
/// Returns the DNG matrix together with whether it must be chromatically adapted
/// from D50 to D65 before conversion to sRGB.
pub fn camera_matrix(meta: &RawMetadata) -> Option<(&Mat3, bool)> {
    meta.color_matrix
        .as_ref()
        .map(|(illu, m)| (m, *illu == Illuminant::D50))
}

/// Demosaics a single-channel Bayer mosaic into interleaved RGB.
///
/// Bilinear interpolation: the missing value at a site is the average of its
/// nearest same-colour neighbours (cross neighbours first, diagonals only for
/// the opposite colour at an R/B site). Borders skip out-of-range taps.
pub fn demosaic_bilinear(
    mosaic: &[f32],
    width: usize,
    height: usize,
    pattern: CfaPattern,
) -> Result<Vec<f32>, String> {
    if width == 0 || height == 0 {
        return Err("raw demosaic: empty image".into());
    }
    if mosaic.len() != width * height {
        return Err(format!(
            "raw demosaic: {} samples for {width}x{height}",
            mosaic.len()
        ));
    }
    let mut out = vec![0.0_f32; width * height * 3];
    for y in 0..height {
        for x in 0..width {
            let base = (y * width + x) * 3;
            for ch in 0..3u8 {
                out[base + ch as usize] = channel_value(mosaic, width, height, pattern, ch, x, y);
            }
        }
    }
    Ok(out)
}

fn channel_value(
    mosaic: &[f32],
    width: usize,
    height: usize,
    pattern: CfaPattern,
    ch: u8,
    x: usize,
    y: usize,
) -> f32 {
    if pattern.color_at(x, y) == ch {
        return mosaic[y * width + x];
    }
    let taps: [&[(i32, i32)]; 2] = [
        &[(1, 0), (-1, 0), (0, 1), (0, -1)],
        &[(1, 1), (1, -1), (-1, 1), (-1, -1)],
    ];
    for set in taps {
        let mut sum = 0.0_f32;
        let mut n = 0u32;
        for &(dx, dy) in set {
            let nx = x as i32 + dx;
            let ny = y as i32 + dy;
            if nx < 0 || ny < 0 || nx as usize >= width || ny as usize >= height {
                continue;
            }
            let (nx, ny) = (nx as usize, ny as usize);
            if pattern.color_at(nx, ny) == ch {
                sum += mosaic[ny * width + nx];
                n += 1;
            }
        }
        if n > 0 {
            return sum / n as f32;
        }
    }
    mosaic[y * width + x]
}

/// Reconstructs clipped RAW highlight channels from unclipped neighbor/channel ratios.
///
/// When one or two channels saturate (clip to whitelevel), this recovers the missing
/// energy and hue by propagating gradients and color differences from unclipped channels.
/// When all three channels saturate, it neutralizes them to eliminate the magenta cast
/// caused by post-demosaic white-balance multipliers.
pub fn reconstruct_highlights(
    rgb: &mut [f32],
    width: usize,
    height: usize,
    clip_threshold: f32,
    wb: Option<&[f32; 4]>,
) {
    if width == 0 || height == 0 || rgb.len() != width * height * 3 {
        return;
    }

    let mut sum_rg = 0.0f64;
    let mut sum_bg = 0.0f64;
    let mut count_g = 0usize;

    for i in (0..rgb.len()).step_by(3) {
        let r = rgb[i];
        let g = rgb[i + 1];
        let b = rgb[i + 2];
        if r < clip_threshold && g < clip_threshold && b < clip_threshold && g > 0.05 {
            sum_rg += (r / g) as f64;
            sum_bg += (b / g) as f64;
            count_g += 1;
        }
    }

    let default_rg = if count_g > 0 {
        (sum_rg / count_g as f64) as f32
    } else {
        1.0
    };
    let default_bg = if count_g > 0 {
        (sum_bg / count_g as f64) as f32
    } else {
        1.0
    };

    let (mr, mb) = if let Some(wb_coeffs) = wb {
        let g_wb = wb_coeffs[1];
        if g_wb.abs() > 1e-6 {
            (wb_coeffs[0] / g_wb, wb_coeffs[2] / g_wb)
        } else {
            (1.0, 1.0)
        }
    } else {
        (1.0, 1.0)
    };

    for y in 0..height {
        for x in 0..width {
            let idx = (y * width + x) * 3;
            let r = rgb[idx];
            let g = rgb[idx + 1];
            let b = rgb[idx + 2];

            let r_clip = r >= clip_threshold;
            let g_clip = g >= clip_threshold;
            let b_clip = b >= clip_threshold;

            if !r_clip && !g_clip && !b_clip {
                continue;
            }

            if r_clip && g_clip && b_clip {
                // All channels clipped: neutralize to the maximum sample to prevent magenta cast
                let max_v = r.max(g).max(b);
                rgb[idx] = if mr > 1e-3 { max_v / mr } else { max_v };
                rgb[idx + 1] = max_v;
                rgb[idx + 2] = if mb > 1e-3 { max_v / mb } else { max_v };
                continue;
            }

            // Estimate local unclipped ratios from immediate 5x5 window if available
            let mut local_sum_rg = 0.0f32;
            let mut local_sum_bg = 0.0f32;
            let mut local_count = 0usize;

            let y_min = y.saturating_sub(2);
            let y_max = (y + 2).min(height - 1);
            let x_min = x.saturating_sub(2);
            let x_max = (x + 2).min(width - 1);

            for ny in y_min..=y_max {
                for nx in x_min..=x_max {
                    let nidx = (ny * width + nx) * 3;
                    let nr = rgb[nidx];
                    let ng = rgb[nidx + 1];
                    let nb = rgb[nidx + 2];
                    if nr < clip_threshold
                        && ng < clip_threshold
                        && nb < clip_threshold
                        && ng > 0.05
                    {
                        local_sum_rg += nr / ng;
                        local_sum_bg += nb / ng;
                        local_count += 1;
                    }
                }
            }

            let ratio_rg = if local_count > 0 {
                local_sum_rg / local_count as f32
            } else {
                default_rg
            };
            let ratio_bg = if local_count > 0 {
                local_sum_bg / local_count as f32
            } else {
                default_bg
            };

            // Reconstruct clipped channels based on unclipped guide channel(s)
            if !g_clip {
                if r_clip {
                    let recon_r = g * ratio_rg;
                    rgb[idx] = r.max(recon_r);
                }
                if b_clip {
                    let recon_b = g * ratio_bg;
                    rgb[idx + 2] = b.max(recon_b);
                }
            } else if !r_clip && ratio_rg > 1e-3 {
                let recon_g = r / ratio_rg;
                let new_g = g.max(recon_g);
                rgb[idx + 1] = new_g;
                if b_clip {
                    rgb[idx + 2] = b.max(new_g * ratio_bg);
                }
            } else if !b_clip && ratio_bg > 1e-3 {
                let recon_g = b / ratio_bg;
                let new_g = g.max(recon_g);
                rgb[idx + 1] = new_g;
                if r_clip {
                    rgb[idx] = r.max(new_g * ratio_rg);
                }
            }

            // Apply smooth highlight roll-off above clip_threshold to avoid hard clamping
            for c in 0..3 {
                let v = rgb[idx + c];
                if v > clip_threshold {
                    let over = v - clip_threshold;
                    let compressed = clip_threshold + over / (1.0 + over * 0.5);
                    rgb[idx + c] = compressed;
                }
            }
        }
    }
}

/// Applies as-shot white-balance multipliers (RGBE order), normalised to green.
pub fn apply_white_balance(rgb: &mut [f32], wb: &[f32; 4]) {
    let g = wb[1];
    if g.abs() < 1e-6 {
        return;
    }
    let (mr, mb) = (wb[0] / g, wb[2] / g);
    if !mr.is_finite() || !mb.is_finite() {
        return;
    }
    for i in (0..rgb.len()).step_by(3) {
        rgb[i] *= mr;
        rgb[i + 2] *= mb;
    }
}

/// Crops a linear image to `(x, y, width, height)`; the rect must be in bounds.
pub fn crop_linear(
    img: &RawLinearImage,
    x: usize,
    y: usize,
    width: usize,
    height: usize,
) -> Result<RawLinearImage, String> {
    if x.saturating_add(width) > img.width || y.saturating_add(height) > img.height {
        return Err(format!(
            "raw crop ({x},{y},{width},{height}) outside {}x{}",
            img.width, img.height
        ));
    }
    let row = width * 3;
    let mut data = vec![0.0_f32; width * height * 3];
    for r in 0..height {
        let src = ((y + r) * img.width + x) * 3;
        let dst = r * row;
        data[dst..dst + row].copy_from_slice(&img.data[src..src + row]);
    }
    Ok(RawLinearImage {
        width,
        height,
        data,
    })
}

/// Decodes a RAW/DNG and returns only the requested region (ROI/tile path).
pub fn decode_roi(
    bytes: &[u8],
    x: usize,
    y: usize,
    width: usize,
    height: usize,
) -> Result<RawLinearImage, String> {
    crop_linear(&decode(bytes)?, x, y, width, height)
}

/// Encodes a linear sRGB image into an opaque RGBA8 buffer (sRGB transfer).
pub fn to_rgba8(img: &RawLinearImage) -> Vec<u8> {
    let mut out = vec![0u8; img.width * img.height * 4];
    for i in 0..(img.width * img.height) {
        out[i * 4] = (color::srgb_oetf(img.data[i * 3]) * 255.0).round() as u8;
        out[i * 4 + 1] = (color::srgb_oetf(img.data[i * 3 + 1]) * 255.0).round() as u8;
        out[i * 4 + 2] = (color::srgb_oetf(img.data[i * 3 + 2]) * 255.0).round() as u8;
        out[i * 4 + 3] = 255;
    }
    out
}

/// Linear colour transforms: DNG camera matrices → working/display RGB.
///
/// The working space is linear-light sRGB (D65); preview and export share these
/// matrices so they cannot drift (ARCHITECTURE §8, step 1).
pub mod color {
    use super::{Mat3, RawLinearImage};

    /// Linear sRGB → XYZ (D65), Bruce Lindbloom.
    #[allow(clippy::excessive_precision)]
    pub const SRGB_TO_XYZ_D65: Mat3 = [
        [0.4124564, 0.3575761, 0.1804375],
        [0.2126729, 0.7151522, 0.0721750],
        [0.0193339, 0.1191920, 0.9503041],
    ];

    /// XYZ (D65) → linear sRGB, Bruce Lindbloom.
    #[allow(clippy::excessive_precision)]
    pub const XYZ_TO_SRGB_D65: Mat3 = [
        [3.2404542, -1.5371385, -0.4985314],
        [-0.9692660, 1.8760108, 0.0415560],
        [0.0556434, -0.2040259, 1.0572252],
    ];

    /// Bradford chromatic adaptation XYZ (D50) → XYZ (D65).
    #[allow(clippy::excessive_precision)]
    pub const D50_TO_D65: Mat3 = [
        [0.9555766, -0.0230393, 0.0631636],
        [-0.0282895, 1.0099416, 0.0210077],
        [0.0122982, -0.0204830, 1.3299098],
    ];

    /// The identity colour matrix.
    pub const IDENTITY: Mat3 = [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]];

    /// Determinant-based 3x3 inverse; `None` if the matrix is singular.
    pub fn invert(m: &Mat3) -> Option<Mat3> {
        let det = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
            - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
            + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
        if det.abs() < 1e-12 {
            return None;
        }
        let inv_det = 1.0 / det;
        let mut out = [[0.0_f32; 3]; 3];
        out[0][0] = (m[1][1] * m[2][2] - m[1][2] * m[2][1]) * inv_det;
        out[0][1] = (m[0][2] * m[2][1] - m[0][1] * m[2][2]) * inv_det;
        out[0][2] = (m[0][1] * m[1][2] - m[0][2] * m[1][1]) * inv_det;
        out[1][0] = (m[1][2] * m[2][0] - m[1][0] * m[2][2]) * inv_det;
        out[1][1] = (m[0][0] * m[2][2] - m[0][2] * m[2][0]) * inv_det;
        out[1][2] = (m[0][2] * m[1][0] - m[0][0] * m[1][2]) * inv_det;
        out[2][0] = (m[1][0] * m[2][1] - m[1][1] * m[2][0]) * inv_det;
        out[2][1] = (m[0][1] * m[2][0] - m[0][0] * m[2][1]) * inv_det;
        out[2][2] = (m[0][0] * m[1][1] - m[0][1] * m[1][0]) * inv_det;
        Some(out)
    }

    /// Matrix product `a * b`.
    pub fn multiply(a: &Mat3, b: &Mat3) -> Mat3 {
        let mut out = [[0.0_f32; 3]; 3];
        for (r, row) in out.iter_mut().enumerate() {
            for (c, cell) in row.iter_mut().enumerate() {
                *cell = (0..3).map(|k| a[r][k] * b[k][c]).sum();
            }
        }
        out
    }

    /// Applies `m` to a column vector.
    pub fn transform(m: &Mat3, v: [f32; 3]) -> [f32; 3] {
        [
            m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
            m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
            m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2],
        ]
    }

    /// Builds the camera → linear-sRGB matrix from a DNG camera matrix.
    ///
    /// `dng` is the DNG `ColorMatrix` (XYZ → camera) for `dng_is_d50`'s
    /// illuminant: D65 is used directly, D50 is chromatically adapted to D65.
    pub fn camera_to_srgb(dng: &Mat3, dng_is_d50: bool) -> Option<Mat3> {
        let cam_to_xyz = invert(dng)?;
        let adapt = if dng_is_d50 { D50_TO_D65 } else { IDENTITY };
        Some(multiply(&XYZ_TO_SRGB_D65, &multiply(&adapt, &cam_to_xyz)))
    }

    /// Linear → gamma-encoded sRGB (the standard sRGB OETF), clamped to 0..=1.
    pub fn srgb_oetf(x: f32) -> f32 {
        let x = x.clamp(0.0, 1.0);
        if x <= 0.003_130_8 {
            12.92 * x
        } else {
            1.055 * x.powf(1.0 / 2.4) - 0.055
        }
    }

    /// Applies a colour matrix to every pixel of a linear image.
    pub fn apply(img: &RawLinearImage, m: &Mat3) -> RawLinearImage {
        let mut data = Vec::with_capacity(img.data.len());
        for i in (0..img.data.len()).step_by(3) {
            data.extend_from_slice(&transform(
                m,
                [img.data[i], img.data[i + 1], img.data[i + 2]],
            ));
        }
        RawLinearImage {
            width: img.width,
            height: img.height,
            data,
        }
    }

    /// Converts RGB in [0, 1] to HSV (H in [0, 360), S in [0, 1], V in [0, 1]).
    pub fn rgb_to_hsv(r: f32, g: f32, b: f32) -> (f32, f32, f32) {
        let max = r.max(g).max(b);
        let min = r.min(g).min(b);
        let delta = max - min;
        let v = max;
        let s = if max > 1e-6 { delta / max } else { 0.0 };
        let mut h = if delta < 1e-6 {
            0.0
        } else if (max - r).abs() < 1e-6 {
            60.0 * (((g - b) / delta).rem_euclid(6.0))
        } else if (max - g).abs() < 1e-6 {
            60.0 * (((b - r) / delta) + 2.0)
        } else {
            60.0 * (((r - g) / delta) + 4.0)
        };
        if h < 0.0 {
            h += 360.0;
        }
        (h, s, v)
    }

    /// Converts HSV (H in [0, 360), S in [0, 1], V in [0, 1]) to RGB in [0, 1].
    pub fn hsv_to_rgb(h: f32, s: f32, v: f32) -> (f32, f32, f32) {
        let h_norm = h.rem_euclid(360.0);
        let c = v * s;
        let x = c * (1.0 - ((h_norm / 60.0).rem_euclid(2.0) - 1.0).abs());
        let m = v - c;
        let (r1, g1, b1) = if h_norm < 60.0 {
            (c, x, 0.0)
        } else if h_norm < 120.0 {
            (x, c, 0.0)
        } else if h_norm < 180.0 {
            (0.0, c, x)
        } else if h_norm < 240.0 {
            (0.0, x, c)
        } else if h_norm < 300.0 {
            (x, 0.0, c)
        } else {
            (c, 0.0, x)
        };
        (r1 + m, g1 + m, b1 + m)
    }

    /// A 3D HSV delta map from a DCP/DNG camera profile (ProfileHueSatMap).
    #[derive(Debug, Clone, PartialEq)]
    pub struct HueSatMap {
        pub hue_divs: usize,
        pub sat_divs: usize,
        pub val_divs: usize,
        /// Elements: [hue_shift (deg), sat_scale, val_scale] for each grid cell.
        pub deltas: Vec<f32>,
    }

    impl HueSatMap {
        pub fn new(
            hue_divs: usize,
            sat_divs: usize,
            val_divs: usize,
            deltas: Vec<f32>,
        ) -> Option<Self> {
            let expected = hue_divs * sat_divs * val_divs * 3;
            if hue_divs == 0 || sat_divs == 0 || val_divs == 0 || deltas.len() != expected {
                return None;
            }
            Some(Self {
                hue_divs,
                sat_divs,
                val_divs,
                deltas,
            })
        }

        /// Interpolates between two HueSatMaps with weight `w` in [0, 1].
        pub fn interpolate(&self, other: &Self, w: f32) -> Option<Self> {
            if self.hue_divs != other.hue_divs
                || self.sat_divs != other.sat_divs
                || self.val_divs != other.val_divs
            {
                return None;
            }
            let w = w.clamp(0.0, 1.0);
            let deltas: Vec<f32> = self
                .deltas
                .iter()
                .zip(other.deltas.iter())
                .map(|(&d1, &d2)| (1.0 - w) * d1 + w * d2)
                .collect();
            Some(Self {
                hue_divs: self.hue_divs,
                sat_divs: self.sat_divs,
                val_divs: self.val_divs,
                deltas,
            })
        }

        /// Samples the delta [hue_shift, sat_scale, val_scale] at (h, s, v).
        pub fn sample(&self, h: f32, s: f32, v: f32) -> [f32; 3] {
            let h_deg = h.rem_euclid(360.0);
            let uh = (h_deg / 360.0) * self.hue_divs as f32;
            let h0 = (uh.floor() as usize) % self.hue_divs;
            let h1 = (h0 + 1) % self.hue_divs;
            let fh = uh - uh.floor();

            let us = s.clamp(0.0, 1.0) * (self.sat_divs - 1) as f32;
            let s0 = (us.floor() as usize).min(self.sat_divs - 1);
            let s1 = (s0 + 1).min(self.sat_divs - 1);
            let fs = (us - s0 as f32).clamp(0.0, 1.0);

            let (v0, v1, fv) = if self.val_divs > 1 {
                let uv = v.clamp(0.0, 1.0) * (self.val_divs - 1) as f32;
                let v0 = (uv.floor() as usize).min(self.val_divs - 1);
                let v1 = (v0 + 1).min(self.val_divs - 1);
                let fv = (uv - v0 as f32).clamp(0.0, 1.0);
                (v0, v1, fv)
            } else {
                (0, 0, 0.0)
            };

            let get_delta = |h_idx: usize, s_idx: usize, v_idx: usize| -> [f32; 3] {
                let idx = ((h_idx * self.sat_divs + s_idx) * self.val_divs + v_idx) * 3;
                [self.deltas[idx], self.deltas[idx + 1], self.deltas[idx + 2]]
            };

            let c000 = get_delta(h0, s0, v0);
            let c100 = get_delta(h1, s0, v0);
            let c010 = get_delta(h0, s1, v0);
            let c110 = get_delta(h1, s1, v0);
            let c001 = get_delta(h0, s0, v1);
            let c101 = get_delta(h1, s0, v1);
            let c011 = get_delta(h0, s1, v1);
            let c111 = get_delta(h1, s1, v1);

            let mut out = [0.0f32; 3];
            for i in 0..3 {
                let c00 = c000[i] * (1.0 - fh) + c100[i] * fh;
                let c10 = c010[i] * (1.0 - fh) + c110[i] * fh;
                let c01 = c001[i] * (1.0 - fh) + c101[i] * fh;
                let c11 = c011[i] * (1.0 - fh) + c111[i] * fh;

                let c0 = c00 * (1.0 - fs) + c10 * fs;
                let c1 = c01 * (1.0 - fs) + c11 * fs;

                out[i] = c0 * (1.0 - fv) + c1 * fv;
            }
            out
        }

        /// Applies the HueSatMap to a linear RGB slice in place.
        pub fn apply_to_rgb(&self, rgb: &mut [f32]) {
            for i in (0..rgb.len()).step_by(3) {
                let r = rgb[i];
                let g = rgb[i + 1];
                let b = rgb[i + 2];
                let (h, s, v) = rgb_to_hsv(r, g, b);
                let [dh, ds, dv] = self.sample(h, s, v);
                let new_h = (h + dh).rem_euclid(360.0);
                let new_s = (s * ds).clamp(0.0, 1.0);
                let new_v = (v * dv).max(0.0);
                let (nr, ng, nb) = hsv_to_rgb(new_h, new_s, new_v);
                rgb[i] = nr;
                rgb[i + 1] = ng;
                rgb[i + 2] = nb;
            }
        }
    }
}

/// Radial optics corrections (ARCHITECTURE §8, step 2).
///
/// Both models use a 3-term radial polynomial in the normalised radius `r`
/// (0 at the centre, 1 at the half-diagonal). Distortion follows the standard
/// Brown–Conrady model; vignetting corrects the radial falloff multiplicatively.
pub mod lens {
    use super::RawLinearImage;

    fn radial(r: f32, k: &[f32; 3]) -> f32 {
        let r2 = r * r;
        let r4 = r2 * r2;
        let r6 = r4 * r2;
        1.0 + k[0] * r2 + k[1] * r4 + k[2] * r6
    }

    /// Distortion gain at ideal radius `r`: `dr/dr_ideal` scale factor.
    pub fn distortion_factor(r: f32, k: &[f32; 3]) -> f32 {
        radial(r, k)
    }

    /// Ideal radius that the lens maps to observed radius `r_ideal * factor(r)`.
    pub fn distorted_radius(r_ideal: f32, k: &[f32; 3]) -> f32 {
        r_ideal * radial(r_ideal, k)
    }

    /// Solves `distorted_radius(x) = r_distorted` for `x` (Newton–Raphson).
    ///
    /// Used to resample: for each output radius we look up which source pixel to
    /// sample, so distortion and vignetting share one geometry pass.
    pub fn undistort_radius(r_distorted: f32, k: &[f32; 3]) -> f32 {
        let mut x = r_distorted;
        for _ in 0..24 {
            let r2 = x * x;
            let r4 = r2 * r2;
            let r6 = r4 * r2;
            let f = x * (1.0 + k[0] * r2 + k[1] * r4 + k[2] * r6) - r_distorted;
            let fp = 1.0 + 3.0 * k[0] * r2 + 5.0 * k[1] * r4 + 7.0 * k[2] * r6;
            if fp.abs() < 1e-12 {
                break;
            }
            let step = f / fp;
            x -= step;
            if step.abs() < 1e-7 {
                break;
            }
        }
        x
    }

    /// Vignette correction gain at radius `r` (multiply the pixel by this).
    pub fn vignette_gain(r: f32, k: &[f32; 3]) -> f32 {
        radial(r, k)
    }

    /// Multiplies each pixel by its vignette correction gain, using a radius
    /// normalised to the image half-diagonal.
    pub fn correct_vignette(img: &mut RawLinearImage, k: &[f32; 3]) {
        if k.iter().all(|c| *c == 0.0) {
            return;
        }
        let w = img.width as f32;
        let h = img.height as f32;
        let cx = (w - 1.0) * 0.5;
        let cy = (h - 1.0) * 0.5;
        let half_diag = (cx * cx + cy * cy).sqrt().max(f32::EPSILON);
        for i in (0..img.data.len()).step_by(3) {
            let p = i / 3;
            let x = (p % img.width) as f32;
            let y = (p / img.width) as f32;
            let dx = (x - cx) / half_diag;
            let dy = (y - cy) / half_diag;
            let r = (dx * dx + dy * dy).sqrt();
            let gain = vignette_gain(r, k);
            img.data[i] *= gain;
            img.data[i + 1] *= gain;
            img.data[i + 2] *= gain;
        }
    }

    /// Undistorts an image using the Brown–Conrady radial model with coefficients k = [k1, k2, k3].
    pub fn correct_distortion(img: &mut RawLinearImage, k: &[f32; 3]) {
        if k.iter().all(|c| *c == 0.0) {
            return;
        }
        let w = img.width;
        let h = img.height;
        let fw = w as f32;
        let fh = h as f32;
        let cx = (fw - 1.0) * 0.5;
        let cy = (fh - 1.0) * 0.5;
        let half_diag = (cx * cx + cy * cy).sqrt().max(f32::EPSILON);

        let mut out = vec![0.0f32; w * h * 3];

        for y in 0..h {
            for x in 0..w {
                let dx = (x as f32 - cx) / half_diag;
                let dy = (y as f32 - cy) / half_diag;
                let r = (dx * dx + dy * dy).sqrt();
                if r < 1e-7 {
                    let idx = (y * w + x) * 3;
                    out[idx..idx + 3].copy_from_slice(&img.data[idx..idx + 3]);
                    continue;
                }
                let r_distorted = distorted_radius(r, k);
                let scale = r_distorted / r;
                let src_x = cx + dx * scale * half_diag;
                let src_y = cy + dy * scale * half_diag;

                let dst_idx = (y * w + x) * 3;
                if src_x >= 0.0 && src_x <= fw - 1.0 && src_y >= 0.0 && src_y <= fh - 1.0 {
                    let x0 = src_x.floor() as usize;
                    let y0 = src_y.floor() as usize;
                    let x1 = (x0 + 1).min(w - 1);
                    let y1 = (y0 + 1).min(h - 1);
                    let fx = src_x - x0 as f32;
                    let fy = src_y - y0 as f32;

                    let i00 = (y0 * w + x0) * 3;
                    let i10 = (y0 * w + x1) * 3;
                    let i01 = (y1 * w + x0) * 3;
                    let i11 = (y1 * w + x1) * 3;

                    for c in 0..3 {
                        let top = img.data[i00 + c] * (1.0 - fx) + img.data[i10 + c] * fx;
                        let btm = img.data[i01 + c] * (1.0 - fx) + img.data[i11 + c] * fx;
                        out[dst_idx + c] = top * (1.0 - fy) + btm * fy;
                    }
                }
            }
        }
        img.data = out;
    }
}

/// Builds a standard JPEG APP1 Exif segment from a RAW/DNG file to preserve metadata on export.
pub fn build_exif_app1(bytes: &[u8]) -> Option<Vec<u8>> {
    let meta = metadata(bytes).ok()?;
    let make = meta.make.as_deref().unwrap_or("Generic");
    let model = meta.model.as_deref().unwrap_or("RAW Camera");
    let software = "ApertureX";

    let mut make_bytes = make.as_bytes().to_vec();
    make_bytes.push(0);
    let mut model_bytes = model.as_bytes().to_vec();
    model_bytes.push(0);
    let mut sw_bytes = software.as_bytes().to_vec();
    sw_bytes.push(0);

    let base_data_offset = 8 + 2 + 4 * 12 + 4; // 62
    let make_offset = base_data_offset as u32;
    let model_offset = make_offset + make_bytes.len() as u32;
    let sw_offset = model_offset + model_bytes.len() as u32;

    let mut tiff = Vec::new();
    tiff.extend_from_slice(b"II\x2a\x00"); // Little endian header
    tiff.extend_from_slice(&8u32.to_le_bytes()); // Offset to IFD0
    tiff.extend_from_slice(&4u16.to_le_bytes()); // 4 entries

    // 0x010F Make
    tiff.extend_from_slice(&0x010Fu16.to_le_bytes());
    tiff.extend_from_slice(&2u16.to_le_bytes()); // ASCII
    tiff.extend_from_slice(&(make_bytes.len() as u32).to_le_bytes());
    tiff.extend_from_slice(&make_offset.to_le_bytes());

    // 0x0110 Model
    tiff.extend_from_slice(&0x0110u16.to_le_bytes());
    tiff.extend_from_slice(&2u16.to_le_bytes()); // ASCII
    tiff.extend_from_slice(&(model_bytes.len() as u32).to_le_bytes());
    tiff.extend_from_slice(&model_offset.to_le_bytes());

    // 0x0112 Orientation (SHORT = 3, count = 1, val = 1)
    tiff.extend_from_slice(&0x0112u16.to_le_bytes());
    tiff.extend_from_slice(&3u16.to_le_bytes());
    tiff.extend_from_slice(&1u32.to_le_bytes());
    tiff.extend_from_slice(&1u16.to_le_bytes());
    tiff.extend_from_slice(&0u16.to_le_bytes());

    // 0x0131 Software
    tiff.extend_from_slice(&0x0131u16.to_le_bytes());
    tiff.extend_from_slice(&2u16.to_le_bytes()); // ASCII
    tiff.extend_from_slice(&(sw_bytes.len() as u32).to_le_bytes());
    tiff.extend_from_slice(&sw_offset.to_le_bytes());

    tiff.extend_from_slice(&0u32.to_le_bytes()); // Next IFD = 0
    tiff.extend_from_slice(&make_bytes);
    tiff.extend_from_slice(&model_bytes);
    tiff.extend_from_slice(&sw_bytes);

    let payload_len = 6 + tiff.len();
    let total_len = payload_len + 2;
    if total_len > 65535 {
        return None;
    }
    let mut app1 = Vec::with_capacity(2 + total_len);
    app1.push(0xFF);
    app1.push(0xE1);
    app1.push((total_len >> 8) as u8);
    app1.push((total_len & 0xFF) as u8);
    app1.extend_from_slice(b"Exif\0\0");
    app1.extend_from_slice(&tiff);

    Some(app1)
}

#[cfg(feature = "raw-libraw")]
#[cfg(test)]
mod libraw_tests {
    #[test]
    fn libraw_crate_linked() {
        // Only compiled with `--features raw-libraw`; verifies FFI linkage.
        let _ = libraw::version();
    }
}

#[cfg(test)]
pub(crate) mod tests {
    use std::io::Cursor;

    use rawler::dng::writer::DngWriter;
    use rawler::dng::DngCompression;

    use super::*;

    pub(crate) fn make_linear_dng(width: usize, height: usize) -> Vec<u8> {
        let data: Vec<u16> = (0..width * height * 3)
            .map(|i| ((i * 257) & 0xffff) as u16)
            .collect();
        let mut cursor = Cursor::new(Vec::new());
        {
            let mut w = DngWriter::new(&mut cursor, [1, 4, 0, 0]).unwrap();
            {
                let mut sub = w.subframe(0);
                sub.rgb_image_u16(&data, width, height, DngCompression::Uncompressed, 1)
                    .unwrap();
                sub.finalize().unwrap();
            }
            w.close().unwrap();
        }
        cursor.into_inner()
    }

    /// 3x2 RGB image where pixel (x, y) encodes its coordinates in R,G.
    fn coord_img() -> RawLinearImage {
        let mut data = Vec::new();
        for y in 0..2usize {
            for x in 0..3usize {
                data.extend_from_slice(&[x as f32, y as f32, 100.0]);
            }
        }
        RawLinearImage {
            width: 3,
            height: 2,
            data,
        }
    }

    fn pixel(img: &RawLinearImage, x: usize, y: usize) -> (f32, f32, f32) {
        let i = (y * img.width + x) * 3;
        (img.data[i], img.data[i + 1], img.data[i + 2])
    }

    #[test]
    fn orientation_normal_is_identity() {
        let out = apply_orientation(&coord_img(), RawOrientation::Normal);
        assert_eq!((out.width, out.height), (3, 2));
        assert_eq!(pixel(&out, 2, 1), (2.0, 1.0, 100.0));
    }

    #[test]
    fn orientation_horizontal_flip_mirrors_columns() {
        let out = apply_orientation(&coord_img(), RawOrientation::HorizontalFlip);
        assert_eq!((out.width, out.height), (3, 2));
        assert_eq!(pixel(&out, 0, 0), (2.0, 0.0, 100.0));
        assert_eq!(pixel(&out, 2, 0), (0.0, 0.0, 100.0));
    }

    #[test]
    fn orientation_vertical_flip_mirrors_rows() {
        let out = apply_orientation(&coord_img(), RawOrientation::VerticalFlip);
        assert_eq!((out.width, out.height), (3, 2));
        assert_eq!(pixel(&out, 0, 0), (0.0, 1.0, 100.0));
        assert_eq!(pixel(&out, 0, 1), (0.0, 0.0, 100.0));
    }

    #[test]
    fn orientation_rotate180_flips_both() {
        let out = apply_orientation(&coord_img(), RawOrientation::Rotate180);
        assert_eq!((out.width, out.height), (3, 2));
        assert_eq!(pixel(&out, 0, 0), (2.0, 1.0, 100.0));
        assert_eq!(pixel(&out, 2, 1), (0.0, 0.0, 100.0));
    }

    #[test]
    fn orientation_rotate90_transposes_and_swaps_axes() {
        // EXIF 6 = transpose + vertical flip: pixel (x,y) -> (y, w-1-x).
        let out = apply_orientation(&coord_img(), RawOrientation::Rotate90);
        assert_eq!((out.width, out.height), (2, 3));
        assert_eq!(pixel(&out, 0, 2), (2.0, 1.0, 100.0));
        assert_eq!(pixel(&out, 1, 0), (0.0, 0.0, 100.0));
    }

    #[test]
    fn orientation_transpose_swaps_axes() {
        let out = apply_orientation(&coord_img(), RawOrientation::Transpose);
        assert_eq!((out.width, out.height), (2, 3));
        // (x, y) -> (y, x)
        assert_eq!(pixel(&out, 1, 2), (2.0, 1.0, 100.0));
        assert_eq!(pixel(&out, 0, 0), (0.0, 0.0, 100.0));
    }

    #[test]
    fn to_flips_matches_swaps_axes() {
        for o in [
            RawOrientation::Normal,
            RawOrientation::HorizontalFlip,
            RawOrientation::Rotate180,
            RawOrientation::VerticalFlip,
            RawOrientation::Transpose,
            RawOrientation::Rotate90,
            RawOrientation::Transverse,
            RawOrientation::Rotate270,
            RawOrientation::Unknown,
        ] {
            assert_eq!(o.to_flips().0, o.swaps_axes(), "{o:?}");
        }
    }

    #[test]
    fn metadata_reports_dimensions_and_components() {
        let dng = make_linear_dng(16, 12);
        let meta = metadata(&dng).unwrap();
        assert_eq!((meta.width, meta.height), (16, 12));
        assert_eq!(meta.cpp, 3);
    }

    #[test]
    fn decode_produces_normalised_rgb() {
        let dng = make_linear_dng(8, 8);
        let img = decode(&dng).unwrap();
        assert_eq!((img.width, img.height), (8, 8));
        assert_eq!(img.data.len(), 8 * 8 * 3);
        assert!(img.data.iter().all(|&v| (0.0..=1.0).contains(&v)));
        // The generator is `(i * 257) & 0xffff`, so the first sample is 0.0 and
        // the largest is < full scale — confirming normalisation, not raw u16.
        assert!(img.data[0].abs() < f32::EPSILON);
        let max = img.data.iter().copied().fold(0.0_f32, f32::max);
        assert!(max > 0.7 && max < 1.0, "max={max}");
    }

    #[test]
    fn metadata_without_embedded_matrix_has_none() {
        let dng = make_linear_dng(4, 4);
        assert!(metadata(&dng).unwrap().color_matrix.is_none());
        assert!(camera_matrix(&metadata(&dng).unwrap()).is_none());
    }

    #[test]
    fn decode_rejects_non_rgb_sources() {
        // A 1-component (Bayer) payload is not a valid LinearRaw DNG, so decoding
        // must fail cleanly rather than mis-report dimensions.
        assert!(decode(b"not a raw file").is_err());
    }

    fn assert_mat_approx(a: &Mat3, b: &Mat3, eps: f32) {
        for r in 0..3 {
            for c in 0..3 {
                assert!(
                    (a[r][c] - b[r][c]).abs() < eps,
                    "matrix[{r}][{c}]: {} vs {}",
                    a[r][c],
                    b[r][c]
                );
            }
        }
    }

    #[test]
    fn invert_round_trips() {
        let m = color::SRGB_TO_XYZ_D65;
        let inv = color::invert(&m).unwrap();
        assert_mat_approx(&color::multiply(&inv, &m), &color::IDENTITY, 1e-5);
    }

    #[test]
    fn invert_rejects_singular() {
        let singular = [[1.0, 2.0, 3.0], [2.0, 4.0, 6.0], [0.0, 1.0, 1.0]];
        assert!(color::invert(&singular).is_none());
    }

    #[test]
    fn camera_to_srgb_recovers_identity_for_srgb_camera() {
        // If the "camera" space is sRGB, the DNG matrix is XYZ→sRGB; converting
        // back to sRGB must be (numerically) the identity.
        let dng = color::XYZ_TO_SRGB_D65;
        let m = color::camera_to_srgb(&dng, false).unwrap();
        assert_mat_approx(&m, &color::IDENTITY, 1e-4);
    }

    #[test]
    fn color_apply_scales_pixels() {
        let img = RawLinearImage {
            width: 1,
            height: 1,
            data: vec![0.5, 0.25, 0.1],
        };
        let twice = [[2.0, 0.0, 0.0], [0.0, 2.0, 0.0], [0.0, 0.0, 2.0]];
        let out = color::apply(&img, &twice);
        assert_eq!(out.data, vec![1.0, 0.5, 0.2]);
    }

    #[test]
    fn distortion_is_identity_without_coefficients() {
        let k = [0.0_f32, 0.0, 0.0];
        assert!((lens::distortion_factor(0.7, &k) - 1.0).abs() < 1e-6);
        assert!((lens::distorted_radius(0.7, &k) - 0.7).abs() < 1e-6);
    }

    #[test]
    fn undistort_inverts_distortion() {
        let k = [0.15_f32, -0.05, 0.01];
        for r in [0.0_f32, 0.2, 0.5, 0.8, 1.0] {
            let distorted = lens::distorted_radius(r, &k);
            let recovered = lens::undistort_radius(distorted, &k);
            assert!((recovered - r).abs() < 1e-4, "r={r} recovered={recovered}");
        }
    }

    #[test]
    fn vignette_correction_brightens_corners() {
        let mut img = RawLinearImage {
            width: 3,
            height: 3,
            data: vec![0.5; 3 * 3 * 3],
        };
        let k = [0.25_f32, 0.0, 0.0];
        lens::correct_vignette(&mut img, &k);
        // Centre gains 1.0, corners gain >1.0.
        let centre = (3 + 1) * 3;
        assert!((img.data[centre] - 0.5).abs() < 1e-6);
        assert!(img.data[0] > 0.5);
    }

    #[test]
    fn metadata_reads_embedded_color_matrix() {
        use std::collections::HashMap;

        use rawler::decoders::Camera;
        use rawler::dng::{CropMode, DngPhotometricConversion};
        use rawler::imgop::xyz::Illuminant as RI;
        use rawler::pixarray::PixU16;
        use rawler::rawimage::{BlackLevel, RawImage, RawPhotometricInterpretation, WhiteLevel};

        let (w, h) = (4usize, 4usize);
        let pix = PixU16::new_with(vec![1024_u16; w * h * 3], w * 3, h);
        let mut cam = Camera::new();
        cam.cfa = rawler::CFA::new("RGGB");
        let mut cm = HashMap::new();
        cm.insert(
            RI::D65,
            color::SRGB_TO_XYZ_D65.iter().flatten().copied().collect(),
        );
        cam.color_matrix = cm;
        let raw = RawImage::new(
            cam,
            pix,
            3,
            [1.0, 1.0, 1.0, 1.0],
            RawPhotometricInterpretation::LinearRaw,
            Some(BlackLevel::new(&[0_u32, 0, 0], 1, 1, 3)),
            Some(WhiteLevel::new_bits(16, 3)),
            false,
        );

        let mut cursor = Cursor::new(Vec::new());
        {
            let mut wr = DngWriter::new(&mut cursor, [1, 4, 0, 0]).unwrap();
            let mut sub = wr.subframe(0);
            sub.raw_image(
                &raw,
                CropMode::None,
                DngCompression::Uncompressed,
                DngPhotometricConversion::Original,
                1,
            )
            .unwrap();
            sub.finalize().unwrap();
            wr.close().unwrap();
        }
        let dng = cursor.into_inner();

        let meta = metadata(&dng).unwrap();
        let (illu, m) = meta.color_matrix.expect("embedded matrix");
        assert_eq!(illu, Illuminant::D65);
        assert_mat_approx(&m, &color::SRGB_TO_XYZ_D65, 1e-3);
    }

    #[test]
    fn cfa_pattern_from_colors_maps_all_variants() {
        assert_eq!(CfaPattern::from_colors(0, 1, 1, 2), Some(CfaPattern::Rggb));
        assert_eq!(CfaPattern::from_colors(2, 1, 1, 0), Some(CfaPattern::Bggr));
        assert_eq!(CfaPattern::from_colors(1, 0, 2, 1), Some(CfaPattern::Grbg));
        assert_eq!(CfaPattern::from_colors(1, 2, 0, 1), Some(CfaPattern::Gbrg));
        assert_eq!(CfaPattern::from_colors(0, 0, 1, 2), None);
    }

    #[test]
    fn cfa_pattern_color_at_matches_strings() {
        // RGGB: R G / G B
        assert_eq!(CfaPattern::Rggb.color_at(0, 0), 0);
        assert_eq!(CfaPattern::Rggb.color_at(1, 0), 1);
        assert_eq!(CfaPattern::Rggb.color_at(0, 1), 1);
        assert_eq!(CfaPattern::Rggb.color_at(1, 1), 2);
        // GB/RG
        assert_eq!(CfaPattern::Gbrg.color_at(0, 0), 1);
        assert_eq!(CfaPattern::Gbrg.color_at(1, 0), 2);
        assert_eq!(CfaPattern::Gbrg.color_at(0, 1), 0);
        assert_eq!(CfaPattern::Gbrg.color_at(1, 1), 1);
    }

    fn mosaic_constant(pattern: CfaPattern, w: usize, h: usize, rgb: [f32; 3]) -> Vec<f32> {
        (0..w * h)
            .map(|i| {
                let (x, y) = (i % w, i / w);
                rgb[pattern.color_at(x, y) as usize]
            })
            .collect()
    }

    #[test]
    fn demosaic_recovers_constant_colour_for_every_pattern() {
        let rgb = [0.2_f32, 0.4, 0.6];
        for pattern in [
            CfaPattern::Rggb,
            CfaPattern::Bggr,
            CfaPattern::Grbg,
            CfaPattern::Gbrg,
        ] {
            let mosaic = mosaic_constant(pattern, 4, 4, rgb);
            let out = demosaic_bilinear(&mosaic, 4, 4, pattern).unwrap();
            for px in out.as_chunks::<3>().0 {
                assert!((px[0] - rgb[0]).abs() < 1e-6, "{pattern:?} {px:?}");
                assert!((px[1] - rgb[1]).abs() < 1e-6, "{pattern:?} {px:?}");
                assert!((px[2] - rgb[2]).abs() < 1e-6, "{pattern:?} {px:?}");
            }
        }
    }

    #[test]
    fn demosaic_propagates_red_only_signal() {
        let pattern = CfaPattern::Rggb;
        let mosaic = mosaic_constant(pattern, 4, 4, [0.7, 0.0, 0.0]);
        let out = demosaic_bilinear(&mosaic, 4, 4, pattern).unwrap();
        for px in out.as_chunks::<3>().0 {
            assert!((px[0] - 0.7).abs() < 1e-6, "{px:?}");
            assert!(px[1].abs() < 1e-6 && px[2].abs() < 1e-6, "{px:?}");
        }
    }

    #[test]
    fn white_balance_normalises_to_green() {
        let mut rgb = vec![1.0_f32; 9];
        apply_white_balance(&mut rgb, &[2.0, 1.0, 0.5, 0.0]);
        assert_eq!(rgb, vec![2.0, 1.0, 0.5, 2.0, 1.0, 0.5, 2.0, 1.0, 0.5]);
    }

    #[test]
    fn white_balance_is_noop_for_zero_green() {
        let mut rgb = vec![1.0_f32; 3];
        apply_white_balance(&mut rgb, &[2.0, 0.0, 0.5, 0.0]);
        assert_eq!(rgb, vec![1.0, 1.0, 1.0]);
    }

    #[test]
    fn crop_linear_extracts_subregion() {
        let img = RawLinearImage {
            width: 3,
            height: 2,
            data: (0..18).map(|v| v as f32).collect(),
        };
        let c = crop_linear(&img, 1, 0, 2, 2).unwrap();
        assert_eq!((c.width, c.height), (2, 2));
        assert_eq!(
            c.data,
            vec![3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0]
        );
        assert!(crop_linear(&img, 2, 1, 3, 2).is_err());
    }

    #[test]
    fn srgb_oetf_encodes_known_points() {
        assert!((color::srgb_oetf(0.0) - 0.0).abs() < 1e-7);
        assert!((color::srgb_oetf(1.0) - 1.0).abs() < 1e-6);
        assert!((color::srgb_oetf(0.5) - 0.735_356_9).abs() < 1e-4);
        assert!((color::srgb_oetf(-0.5) - 0.0).abs() < 1e-7);
    }

    #[test]
    fn to_rgba8_produces_opaque_srgb() {
        let img = RawLinearImage {
            width: 1,
            height: 1,
            data: vec![0.5, 0.0, 1.0],
        };
        assert_eq!(to_rgba8(&img), vec![188, 0, 255, 255]);
    }

    #[test]
    fn bayer_dng_demosaics_to_rgb() {
        use rawler::cfa::PlaneColor;
        use rawler::decoders::Camera;
        use rawler::dng::{CropMode, DngPhotometricConversion};
        use rawler::pixarray::PixU16;
        use rawler::rawimage::{
            BlackLevel, CFAConfig, RawImage, RawPhotometricInterpretation, WhiteLevel,
        };

        let (w, h) = (8usize, 8usize);
        // Constant scene colour sampled through the CFA: R=0.25, G=0.5, B=0.75.
        let levels = [0.25_f32, 0.5, 0.75];
        let data: Vec<u16> = (0..w * h)
            .map(|i| {
                let (x, y) = (i % w, i / w);
                let c = CfaPattern::Rggb.color_at(x, y) as usize;
                (levels[c] * u16::MAX as f32) as u16
            })
            .collect();

        let pix = PixU16::new_with(data, w, h);
        let mut cam = Camera::new();
        cam.cfa = rawler::CFA::new("RGGB");
        let photometric =
            RawPhotometricInterpretation::Cfa(CFAConfig::new(&cam.cfa, &PlaneColor::new("RGB")));
        let raw = RawImage::new(
            cam,
            pix,
            1,
            [1.0, 1.0, 1.0, 1.0],
            photometric,
            Some(BlackLevel::new(&[0_u32], 1, 1, 1)),
            Some(WhiteLevel::new_bits(16, 1)),
            false,
        );

        let mut cursor = Cursor::new(Vec::new());
        {
            let mut wr = DngWriter::new(&mut cursor, [1, 4, 0, 0]).unwrap();
            let mut sub = wr.subframe(0);
            sub.raw_image(
                &raw,
                CropMode::None,
                DngCompression::Uncompressed,
                DngPhotometricConversion::Original,
                1,
            )
            .unwrap();
            sub.finalize().unwrap();
            wr.close().unwrap();
        }
        let dng = cursor.into_inner();

        let img = decode(&dng).unwrap();
        assert_eq!((img.width, img.height), (w, h));
        // Interior pixel recovers the scene colour through bilinear demosaic.
        let idx = (4 * w + 4) * 3;
        assert!(
            (img.data[idx] - levels[0]).abs() < 0.02,
            "r={}",
            img.data[idx]
        );
        assert!(
            (img.data[idx + 1] - levels[1]).abs() < 0.02,
            "g={}",
            img.data[idx + 1]
        );
        assert!(
            (img.data[idx + 2] - levels[2]).abs() < 0.02,
            "b={}",
            img.data[idx + 2]
        );
    }

    #[test]
    fn decode_roi_matches_crop_of_full_decode() {
        let dng = make_linear_dng(8, 8);
        let full = decode(&dng).unwrap();
        let roi = decode_roi(&dng, 2, 3, 3, 2).unwrap();
        let expected = crop_linear(&full, 2, 3, 3, 2).unwrap();
        assert_eq!(roi, expected);
    }

    #[test]
    fn vignette_is_noop_without_coefficients() {
        let mut img = RawLinearImage {
            width: 2,
            height: 2,
            data: vec![0.3, 0.4, 0.5, 0.3, 0.4, 0.5, 0.3, 0.4, 0.5, 0.3, 0.4, 0.5],
        };
        let before = img.data.clone();
        lens::correct_vignette(&mut img, &[0.0, 0.0, 0.0]);
        assert_eq!(img.data, before);
    }

    #[test]
    fn highlight_reconstruction_noop_on_unclipped_image() {
        let mut data = vec![0.2, 0.4, 0.3, 0.5, 0.6, 0.7, 0.1, 0.8, 0.2, 0.4, 0.3, 0.5];
        let original = data.clone();
        reconstruct_highlights(&mut data, 2, 2, 0.99, None);
        assert_eq!(data, original);
    }

    #[test]
    fn highlight_reconstruction_recovers_clipped_channel_ratio() {
        let (w, h) = (4, 4);
        let mut data = vec![0.0f32; w * h * 3];
        // Scene with true R:G = 1.5, B:G = 0.8
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 3;
                if y == 0 && x == 0 {
                    // Blown highlight: G is 0.8, B is 0.64, but R clipped at 1.0 (true R was 1.2)
                    data[idx] = 1.0;
                    data[idx + 1] = 0.8;
                    data[idx + 2] = 0.64;
                } else {
                    // Unclipped surrounding context with ratio R/G = 1.5, B/G = 0.8
                    let g = 0.4f32;
                    data[idx] = g * 1.5;
                    data[idx + 1] = g;
                    data[idx + 2] = g * 0.8;
                }
            }
        }

        reconstruct_highlights(&mut data, w, h, 0.99, None);
        let recon_r = data[0];
        let recon_g = data[1];
        // R should be reconstructed above 1.0 according to the unclipped R/G ratio 1.5
        assert!(
            recon_r > 1.0,
            "clipped R should be reconstructed above 1.0, got {recon_r}"
        );
        let recovered_ratio = recon_r / recon_g;
        assert!(
            (recovered_ratio - 1.5).abs() < 0.25,
            "recovered ratio should be close to 1.5, got {recovered_ratio}"
        );
    }

    #[test]
    fn highlight_reconstruction_neutralizes_all_clipped_pixels() {
        let (w, h) = (2, 2);
        // Completely blown white highlight
        let mut data = vec![1.0f32; w * h * 3];
        let wb = [2.0f32, 1.0, 1.5, 1.0]; // Typical WB: Red × 2.0, Blue × 1.5
        reconstruct_highlights(&mut data, w, h, 0.99, Some(&wb));
        apply_white_balance(&mut data, &wb);

        // After WB, all clipped pixels must stay neutral white (R == G == B) without magenta tint
        for i in (0..data.len()).step_by(3) {
            let r = data[i];
            let g = data[i + 1];
            let b = data[i + 2];
            assert!(
                (r - g).abs() < 1e-4 && (b - g).abs() < 1e-4,
                "fully clipped highlight must be neutral, got R={r}, G={g}, B={b}"
            );
        }
    }

    #[test]
    fn huesatmap_rgb_to_hsv_roundtrip() {
        let colors = [
            [1.0f32, 0.0, 0.0],
            [0.0, 1.0, 0.0],
            [0.0, 0.0, 1.0],
            [1.0, 1.0, 0.0],
            [0.0, 1.0, 1.0],
            [1.0, 0.0, 1.0],
            [0.5, 0.5, 0.5],
            [0.2, 0.7, 0.4],
        ];
        for &[r, g, b] in &colors {
            let (h, s, v) = color::rgb_to_hsv(r, g, b);
            let (r2, g2, b2) = color::hsv_to_rgb(h, s, v);
            assert!(
                (r - r2).abs() < 1e-4 && (g - g2).abs() < 1e-4 && (b - b2).abs() < 1e-4,
                "roundtrip failed for [{r}, {g}, {b}] -> [{r2}, {g2}, {b2}]"
            );
        }
    }

    #[test]
    fn huesatmap_identity_deltas_is_noop() {
        let deltas = [0.0f32, 1.0, 1.0].repeat(4 * 2);
        let map = color::HueSatMap::new(4, 2, 1, deltas).unwrap();
        let mut rgb = vec![0.8, 0.2, 0.3, 0.1, 0.9, 0.4];
        let original = rgb.clone();
        map.apply_to_rgb(&mut rgb);
        for i in 0..rgb.len() {
            assert!(
                (rgb[i] - original[i]).abs() < 1e-4,
                "identity map modified pixel {i}: {} vs {}",
                rgb[i],
                original[i]
            );
        }
    }

    #[test]
    fn huesatmap_shifts_hue_and_scales_saturation() {
        let mut deltas = [0.0f32, 1.0, 1.0].repeat(4 * 2);
        // At Red (H ~ 0), add +30 degrees hue shift
        for s in 0..2 {
            let idx = s * 3;
            deltas[idx] = 30.0;
            deltas[idx + 1] = 1.2;
        }

        let map = color::HueSatMap::new(4, 2, 1, deltas).unwrap();
        let mut red_rgb = vec![1.0, 0.0, 0.0];
        map.apply_to_rgb(&mut red_rgb);

        // After +30 deg shift, Pure Red (0 deg) shifts towards Orange (30 deg: R=1.0, G=0.5, B=0.0)
        assert!(
            red_rgb[0] > 0.9 && red_rgb[1] > 0.4 && red_rgb[2] < 0.1,
            "expected red shifted to orange: got {:?}",
            red_rgb
        );
    }

    #[test]
    fn huesatmap_temperature_interpolation() {
        let deltas1 = [10.0f32, 1.0, 1.0].repeat(2 * 2);
        let map1 = color::HueSatMap::new(2, 2, 1, deltas1).unwrap();

        let deltas2 = [30.0f32, 1.0, 1.0].repeat(2 * 2);
        let map2 = color::HueSatMap::new(2, 2, 1, deltas2).unwrap();

        let interp = map1.interpolate(&map2, 0.5).unwrap();
        let sample = interp.sample(0.0, 1.0, 1.0);
        assert!(
            (sample[0] - 20.0).abs() < 1e-4,
            "interpolated hue shift expected 20.0, got {}",
            sample[0]
        );
    }

    #[test]
    fn lens_distortion_is_noop_for_zero_coefficients() {
        let mut img = coord_img();
        let original = img.clone();
        lens::correct_distortion(&mut img, &[0.0, 0.0, 0.0]);
        assert_eq!(img, original);
    }

    #[test]
    fn lens_distortion_leaves_center_unchanged() {
        let (w, h) = (9, 9);
        let mut data = Vec::with_capacity(w * h * 3);
        for y in 0..h {
            for x in 0..w {
                data.extend_from_slice(&[x as f32, y as f32, 0.5]);
            }
        }
        let mut img = RawLinearImage {
            width: w,
            height: h,
            data,
        };
        let center_idx = (4 * w + 4) * 3;
        let original_center = [
            img.data[center_idx],
            img.data[center_idx + 1],
            img.data[center_idx + 2],
        ];

        lens::correct_distortion(&mut img, &[0.1, 0.05, 0.0]);
        assert_eq!(
            [
                img.data[center_idx],
                img.data[center_idx + 1],
                img.data[center_idx + 2]
            ],
            original_center,
            "center pixel must remain unchanged under radial distortion"
        );
        // An off-center interior pixel (e.g. x=2, y=3) must shift
        let interior_idx = (3 * w + 2) * 3;
        assert!(
            (img.data[interior_idx] - 2.0).abs() > 1e-4
                || (img.data[interior_idx + 1] - 3.0).abs() > 1e-4,
            "off-center interior pixel should be shifted by distortion"
        );
    }

    #[test]
    fn build_exif_app1_creates_valid_app1_with_metadata() {
        let dng = make_linear_dng(4, 4);
        let app1 = build_exif_app1(&dng).expect("build_exif_app1 should succeed for valid DNG");
        assert_eq!(app1[0], 0xFF);
        assert_eq!(app1[1], 0xE1);
        assert_eq!(&app1[4..10], b"Exif\0\0");
        // Verify ApertureX is present in the software tag
        let payload = &app1[10..];
        let found_software = payload
            .windows(b"ApertureX".len())
            .any(|w| w == b"ApertureX");
        assert!(
            found_software,
            "exported EXIF must include ApertureX software tag"
        );
    }

    #[test]
    fn test_export_dng_lossless_cfa_roundtrip_with_xmp() {
        let linear_dng = make_linear_dng(8, 8);
        let sample_xmp = "<x:xmpmeta xmlns:x=\"adobe:ns:meta/\"><rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"><rdf:Description xmlns:crs=\"http://ns.adobe.com/camera-raw-settings/1.0/\" crs:Exposure2012=\"+0.75\"/></rdf:RDF></x:xmpmeta>";

        let exported = export_dng(&linear_dng, sample_xmp).expect("export_dng should succeed");
        assert!(exported.len() > 100);

        // Verify TIFF magic
        assert_eq!(&exported[0..2], b"II");
        assert_eq!(&exported[2..4], &[42, 0]);

        // Verify XMP packet is present in ApplicationNotes payload
        let found_xmp = exported
            .windows(b"Exposure2012=\"+0.75\"".len())
            .any(|w| w == b"Exposure2012=\"+0.75\"");
        assert!(found_xmp, "Exported DNG must contain injected XMP payload");

        // Re-decode exported DNG and verify dimensions match
        let re_meta = metadata(&exported).expect("re-decoding exported DNG should succeed");
        assert_eq!((re_meta.width, re_meta.height), (8, 8));
    }
}
