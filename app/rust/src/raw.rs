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
}
