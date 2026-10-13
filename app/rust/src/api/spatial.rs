//! Spatial (neighbour-aware) operations API across the `flutter_rust_bridge`
//! boundary. Thin wrappers over [`crate::spatial`].

use crate::spatial;

/// Texture (fine-detail) boost.
pub fn spatial_texture(rgba: Vec<u8>, width: u32, height: u32, amount: f32) -> Vec<u8> {
    spatial::apply_texture(&rgba, width as usize, height as usize, amount)
}

/// Clarity (mid-frequency local contrast).
pub fn spatial_clarity(rgba: Vec<u8>, width: u32, height: u32, amount: f32) -> Vec<u8> {
    spatial::apply_clarity(&rgba, width as usize, height as usize, amount)
}

/// Unsharp sharpening with an explicit radius.
pub fn spatial_sharpen(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    amount: f32,
    radius: u32,
) -> Vec<u8> {
    spatial::apply_sharpen(
        &rgba,
        width as usize,
        height as usize,
        amount,
        radius as usize,
    )
}

/// Edge-aware shadows/highlights.
pub fn spatial_shadow_highlight(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    shadows: f32,
    highlights: f32,
) -> Vec<u8> {
    spatial::apply_shadow_highlight(&rgba, width as usize, height as usize, shadows, highlights)
}

/// Luma/chroma noise reduction.
pub fn spatial_denoise(rgba: Vec<u8>, width: u32, height: u32, luma: f32, chroma: f32) -> Vec<u8> {
    spatial::denoise(&rgba, width as usize, height as usize, luma, chroma)
}

/// The full spatial pass (denoise → shadows/highlights → clarity → texture →
/// sharpen).
#[allow(
    clippy::too_many_arguments,
    reason = "flat scalar args keep the frb surface simple; a struct adds a bridge type for no gain"
)]
pub fn spatial_apply(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    shadows: f32,
    highlights: f32,
    clarity: f32,
    texture: f32,
    sharpen: f32,
    denoise_luma: f32,
    denoise_chroma: f32,
) -> Vec<u8> {
    spatial::apply_spatial(
        &rgba,
        width as usize,
        height as usize,
        spatial::SpatialParams {
            shadows,
            highlights,
            clarity,
            texture,
            sharpen,
            denoise_luma,
            denoise_chroma,
        },
    )
}
