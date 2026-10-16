//! EXIF API across the `flutter_rust_bridge` boundary.

use crate::exif;

/// Returns the source JPEG's APP1/Exif segment (a full `FF E1` segment), or an
/// empty buffer if there is none. Inject it into an export to preserve metadata.
pub fn extract_exif(jpeg: Vec<u8>) -> Vec<u8> {
    exif::extract_app1(&jpeg).unwrap_or_default()
}

/// Embedded depth map extracted from JPEG container metadata.
pub struct EmbeddedDepthResult {
    pub width: u32,
    pub height: u32,
    /// 8-bit grayscale depth values (0..255).
    pub depth: Vec<u8>,
}

/// Attempts to extract embedded portrait depth map from JPEG container metadata.
/// Returns None if no embedded depth map exists.
pub fn extract_embedded_depth(jpeg: Vec<u8>) -> Option<EmbeddedDepthResult> {
    exif::extract_embedded_depth(&jpeg).map(|(depth, w, h)| EmbeddedDepthResult {
        width: w as u32,
        height: h as u32,
        depth,
    })
}
