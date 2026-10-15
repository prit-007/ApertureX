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

/// Reads RAW/DNG metadata without decoding pixel data into our working buffers.
pub fn metadata(bytes: &[u8]) -> Result<RawMetadata, String> {
    let raw = decode_raw(bytes)?;
    let color_matrix = raw
        .color_matrix_find_first([
            RawlerIlluminant::D65,
            RawlerIlluminant::Daylight,
            RawlerIlluminant::D50,
            RawlerIlluminant::A,
            RawlerIlluminant::Unknown,
        ])
        .and_then(|(illu, flat)| flat_to_mat3(&flat).map(|m| (Illuminant::from_rawler(illu), m)));
    Ok(RawMetadata {
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
    })
}

/// Decodes a RAW/DNG into scene-linear camera RGB normalised to `0.0..=1.0`.
///
/// Only 3-component (LinearRaw/DNG) sources are supported for now; Bayer/CFA
/// sources (`cpp == 1`) require demosaic, which is a follow-up in P3.
pub fn decode(bytes: &[u8]) -> Result<RawLinearImage, String> {
    let raw = decode_raw(bytes)?;
    if raw.cpp != 3 {
        return Err(format!(
            "raw decode: only 3-component LinearRaw sources supported yet (got cpp={})",
            raw.cpp
        ));
    }
    let samples = raw.data.as_f32();
    let is_float = matches!(&raw.data, RawImageData::Float(_));
    let white = raw
        .whitelevel
        .0
        .iter()
        .copied()
        .max()
        .unwrap_or(u16::MAX as u32) as f32;
    let expected = raw.width * raw.height * 3;
    if samples.len() != expected {
        return Err(format!(
            "raw decode: {} samples, expected {expected}",
            samples.len()
        ));
    }
    let data = samples
        .iter()
        .map(|&v| {
            let linear = if is_float { v } else { v / white };
            linear.clamp(0.0, 1.0)
        })
        .collect();
    Ok(RawLinearImage {
        width: raw.width,
        height: raw.height,
        data,
    })
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
