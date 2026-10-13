//! JPEG export API exposed across the `flutter_rust_bridge` boundary.
//!
//! Thin wrapper over [`crate::export`]: grade on the CPU (mirroring
//! `shaders/grade.frag`) then encode a JPEG. The P1 export path.

use crate::export;

/// Grades [rgba] on the CPU and encodes a JPEG. [exposure] is in EV;
/// [contrast] and [saturation] are unitless around 0. Returns the encoded JPEG
/// bytes, or an error if the buffer/dimensions are invalid.
pub fn encode_jpeg_export(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    quality: u8,
    exposure: f32,
    contrast: f32,
    saturation: f32,
) -> Result<Vec<u8>, String> {
    export::encode_jpeg(
        &rgba, width, height, quality, exposure, contrast, saturation,
    )
}
