//! Compositing API across flutter_rust_bridge.

use crate::compositing::{self, BlendMode};

/// Composites an overlay image onto a base image with the given blend mode and opacity.
pub fn composite_layers(
    base_rgba: Vec<u8>,
    overlay_rgba: Vec<u8>,
    width: u32,
    height: u32,
    blend_mode_index: u32,
    opacity: f32,
) -> Vec<u8> {
    if crate::validate::validate_rgba(&base_rgba, width, height).is_err()
        || crate::validate::validate_rgba(&overlay_rgba, width, height).is_err()
    {
        return base_rgba;
    }
    let mode = BlendMode::from_u32(blend_mode_index);
    compositing::composite_layers(
        &base_rgba,
        &overlay_rgba,
        width as usize,
        height as usize,
        mode,
        opacity,
    )
}
