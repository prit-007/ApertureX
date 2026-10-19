//! EXIF API across the `flutter_rust_bridge` boundary.

use crate::exif;
use crate::raw;

/// Returns the source JPEG's or RAW/DNG's APP1/Exif segment (a full `FF E1` segment),
/// or an empty buffer if there is none. Inject it into an export to preserve metadata.
pub fn extract_exif(jpeg: Vec<u8>) -> Vec<u8> {
    if let Some(app1) = exif::extract_app1(&jpeg) {
        return app1;
    }
    if let Some(app1) = raw::build_exif_app1(&jpeg) {
        return app1;
    }
    Vec::new()
}

/// Embedded depth map extracted from JPEG container metadata.
pub struct EmbeddedDepthResult {
    pub width: u32,
    pub height: u32,
    /// 8-bit grayscale depth values normalized so 255 is nearest.
    pub depth: Vec<u8>,
    /// `GDepth:Format` value (`RangeInverse` or `RangeLinear`).
    pub format: String,
    /// `GDepth:Near` in the container's units.
    pub near: f32,
    /// `GDepth:Far` in the container's units.
    pub far: f32,
}

/// Attempts to extract embedded portrait depth map from JPEG container metadata.
/// Returns None if no embedded depth map exists.
pub fn extract_embedded_depth(jpeg: Vec<u8>) -> Option<EmbeddedDepthResult> {
    exif::extract_embedded_depth_meta(&jpeg).map(|d| EmbeddedDepthResult {
        width: d.width as u32,
        height: d.height as u32,
        depth: d.depth,
        format: d.format.as_str().to_string(),
        near: d.near,
        far: d.far,
    })
}

pub use crate::exif::ImageMetadata;

/// Parses comprehensive image format, dimensions, camera, lens, exposure, and GPS metadata.
pub fn get_image_metadata(bytes: Vec<u8>) -> ImageMetadata {
    exif::parse_image_metadata(&bytes)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_exif_from_raw_dng_yields_app1_exif() {
        let dng = raw::tests::make_linear_dng(4, 4);
        let extracted = extract_exif(dng);
        assert!(
            !extracted.is_empty(),
            "extract_exif must extract EXIF from RAW DNG"
        );
        assert_eq!(extracted[0], 0xFF);
        assert_eq!(extracted[1], 0xE1);
        assert_eq!(&extracted[4..10], b"Exif\0\0");
    }

    #[test]
    fn extract_exif_on_garbage_returns_empty() {
        assert!(extract_exif(b"garbage".to_vec()).is_empty());
    }
}
