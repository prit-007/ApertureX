//! Wide-gamut input API across the `flutter_rust_bridge` boundary.

use crate::icc;

/// Detects the JPEG's colour space: 0 unknown, 1 sRGB, 2 Display P3.
pub fn detect_colorspace(jpeg: Vec<u8>) -> u32 {
    icc::detect_colorspace(&jpeg)
}

/// Converts Display-P3-encoded RGBA pixels to sRGB.
pub fn p3_to_srgb(rgba: Vec<u8>, width: u32, height: u32) -> Vec<u8> {
    icc::p3_to_srgb(&rgba, width as usize, height as usize)
}
