//! EXIF API across the `flutter_rust_bridge` boundary.

use crate::exif;

/// Returns the source JPEG's APP1/Exif segment (a full `FF E1` segment), or an
/// empty buffer if there is none. Inject it into an export to preserve metadata.
pub fn extract_exif(jpeg: Vec<u8>) -> Vec<u8> {
    exif::extract_app1(&jpeg).unwrap_or_default()
}
