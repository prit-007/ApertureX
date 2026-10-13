//! Tessera engine API surface exposed across the `flutter_rust_bridge` boundary.
//!
//! This is deliberately small: it proves the P0 exit criteria — a typed call
//! (`String`) and a byte-buffer round-trip (`Vec<u8>`). The real decode/tile/
//! colour pipeline lands in later phases behind the `ImageSource` trait
//! (see docs/ARCHITECTURE.md §7).

/// One-time initialisation hook required by `RustLib.init()` in Dart.
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

/// Engine crate version — proves a `String` crosses the bridge.
pub fn engine_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

/// Adds `amount` to the RGB channels of every RGBA pixel, clamping to 0..=255,
/// preserving each pixel's alpha. Proves an owned byte buffer crosses intact.
///
/// A trailing partial pixel (length not a multiple of 4) is left untouched.
#[allow(
    clippy::chunks_exact_to_as_chunks,
    reason = "as_chunks_mut would drop the trailing partial pixel, which we deliberately preserve"
)]
pub fn brighten_rgba(mut rgba: Vec<u8>, amount: i32) -> Vec<u8> {
    for pixel in rgba.chunks_exact_mut(4) {
        for channel in &mut pixel[..3] {
            *channel = (*channel as i32 + amount).clamp(0, 255) as u8;
        }
    }
    rgba
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn engine_version_is_non_empty() {
        assert!(!engine_version().is_empty());
    }

    #[test]
    fn brighten_preserves_alpha_and_clamps() {
        let input = vec![10, 20, 30, 40, 250, 250, 250, 128];
        let out = brighten_rgba(input, 20);
        assert_eq!(out, vec![30, 40, 50, 40, 255, 255, 255, 128]);
    }

    #[test]
    fn brighten_darkens_on_negative_amount() {
        let input = vec![10, 20, 30, 255];
        assert_eq!(brighten_rgba(input, -15), vec![0, 5, 15, 255]);
    }

    #[test]
    fn brighten_leaves_partial_pixel_untouched() {
        let input = vec![10, 20, 30, 40, 7];
        let out = brighten_rgba(input, 5);
        assert_eq!(out, vec![15, 25, 35, 40, 7]);
    }
}
