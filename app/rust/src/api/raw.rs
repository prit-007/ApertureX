//! RAW/DNG decode API exposed across the `flutter_rust_bridge` boundary.
//!
//! Thin wrappers over [`crate::raw`]: the decode is demosaic + camera colour
//! matrix → sRGB, so Dart receives the same kind of RGBA8 buffer the JPEG path
//! produces (and can push it straight into the resident preview store).

use crate::api::decode::{ImageDims, RgbaImage};
use crate::raw;

/// Reads RAW/DNG dimensions without demosaicing, in **display** orientation
/// (axes swapped for the 90°/270°/transpose EXIF cases, matching `decode_*`).
pub fn raw_dimensions(raw: Vec<u8>) -> Result<ImageDims, String> {
    let meta = raw::metadata(&raw)?;
    let (w, h) = if meta.orientation.swaps_axes() {
        (meta.height, meta.width)
    } else {
        (meta.width, meta.height)
    };
    Ok(ImageDims {
        width: w as u32,
        height: h as u32,
    })
}

/// Decodes a RAW/DNG and returns the embedded camera matrix as a flat
/// row-major `[f32; 9]` (empty when the file carries no matrix). Dart uses this
/// only for diagnostics; the RGB conversion already applies it in Rust.
pub fn raw_camera_matrix(raw: Vec<u8>) -> Result<Vec<f32>, String> {
    let meta = raw::metadata(&raw)?;
    Ok(match raw::camera_matrix(&meta) {
        Some((m, _)) => m.iter().flatten().copied().collect(),
        None => Vec::new(),
    })
}

/// Decodes a RAW/DNG into a full sRGB RGBA8 buffer.
pub fn decode_raw_rgba(raw: Vec<u8>) -> Result<RgbaImage, String> {
    let img = decode_raw_to_srgb(&raw)?;
    Ok(RgbaImage {
        width: img.width as u32,
        height: img.height as u32,
        rgba: raw::to_rgba8(&img),
    })
}

/// Decodes a RAW/DNG and returns only the requested region (ROI/tile path).
pub fn decode_raw_roi(
    raw: Vec<u8>,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
) -> Result<RgbaImage, String> {
    let img = decode_raw_to_srgb(&raw)?;
    let cropped = raw::crop_linear(
        &img,
        x as usize,
        y as usize,
        width as usize,
        height as usize,
    )?;
    Ok(RgbaImage {
        width: cropped.width as u32,
        height: cropped.height as u32,
        rgba: raw::to_rgba8(&cropped),
    })
}

/// Decodes once, applies the DNG camera matrix (if any), and returns linear sRGB.
fn decode_raw_to_srgb(bytes: &[u8]) -> Result<raw::RawLinearImage, String> {
    let (mut img, meta) = raw::decode_with_metadata(bytes)?;
    if let Some((dng, is_d50)) = raw::camera_matrix(&meta) {
        if let Some(srgb) = raw::color::camera_to_srgb(dng, is_d50) {
            img = raw::color::apply(&img, &srgb);
        }
    }
    if let Some(ref huesat) = meta.hue_sat_map {
        huesat.apply_to_rgb(&mut img.data);
    }
    Ok(img)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    use rawler::dng::writer::DngWriter;
    use rawler::dng::DngCompression;

    fn make_linear_dng(width: usize, height: usize) -> Vec<u8> {
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
    fn dimensions_match_decoded_size() {
        let dng = make_linear_dng(10, 6);
        let dims = raw_dimensions(dng.clone()).unwrap();
        assert_eq!((dims.width, dims.height), (10, 6));
    }

    #[test]
    fn decode_returns_opaque_rgba_of_expected_size() {
        let dng = make_linear_dng(8, 4);
        let img = decode_raw_rgba(dng).unwrap();
        assert_eq!((img.width, img.height), (8, 4));
        assert_eq!(img.rgba.len(), 8 * 4 * 4);
        assert!(img.rgba.as_chunks::<4>().0.iter().all(|p| p[3] == 255));
    }

    #[test]
    fn roi_matches_region_of_full_decode() {
        let dng = make_linear_dng(12, 8);
        let full = decode_raw_rgba(dng.clone()).unwrap();
        let roi = decode_raw_roi(dng, 2, 3, 4, 2).unwrap();
        assert_eq!((roi.width, roi.height), (4, 2));
        for row in 0..2usize {
            for col in 0..4usize {
                let src = ((3 + row) * 12 + (2 + col)) * 4;
                let dst = (row * 4 + col) * 4;
                assert_eq!(roi.rgba[dst..dst + 4], full.rgba[src..src + 4]);
            }
        }
    }

    #[test]
    fn garbage_input_errors() {
        assert!(decode_raw_rgba(b"nope".to_vec()).is_err());
        assert!(raw_dimensions(b"nope".to_vec()).is_err());
    }
}
