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
            let data = samples.iter().map(|&v| normalize(v)).collect();
            Ok(RawLinearImage {
                width: raw.width,
                height: raw.height,
                data,
            })
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
            apply_white_balance(&mut data, &raw.wb_coeffs);
            Ok(RawLinearImage {
                width: raw.width,
                height: raw.height,
                data,
            })
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
mod tests {
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
}
