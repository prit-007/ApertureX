//! JPEG encode API exposed across the `flutter_rust_bridge` boundary.
//!
//! Pure encode — the Dart export path first grades via `grade_rgba` (so tone
//! curves are included) and then calls this to produce the JPEG bytes.

use crate::export;

/// Encodes an RGBA8 buffer as a JPEG (alpha dropped).
pub fn encode_jpeg_rgba(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    quality: u8,
) -> Result<Vec<u8>, String> {
    export::encode_jpeg(&rgba, width, height, quality)
}
