//! JPEG encode API exposed across the `flutter_rust_bridge` boundary.
//!
//! Pure encode — the Dart export path first grades via `grade_rgba` (so tone
//! curves are included) and then calls this to produce the JPEG bytes.

use crate::export;

/// Encodes an RGBA8 buffer as a JPEG (alpha dropped). [exif] (a full APP1
/// segment from the source, or empty) is injected to preserve metadata.
pub fn encode_jpeg_rgba(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    quality: u8,
    exif: Vec<u8>,
) -> Result<Vec<u8>, String> {
    export::encode_jpeg(&rgba, width, height, quality, &exif)
}
