//! Spatial (neighbour-aware) operations API across the `flutter_rust_bridge`
//! boundary. Thin wrappers over [`crate::spatial`].

use crate::spatial;

/// Texture (fine-detail) boost.
pub fn spatial_texture(rgba: Vec<u8>, width: u32, height: u32, amount: f32) -> Vec<u8> {
    if crate::validate::validate_rgba(&rgba, width, height).is_err() {
        return rgba;
    }
    spatial::apply_texture(&rgba, width as usize, height as usize, amount)
}

/// Clarity (mid-frequency local contrast).
pub fn spatial_clarity(rgba: Vec<u8>, width: u32, height: u32, amount: f32) -> Vec<u8> {
    if crate::validate::validate_rgba(&rgba, width, height).is_err() {
        return rgba;
    }
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
    if crate::validate::validate_rgba(&rgba, width, height).is_err() {
        return rgba;
    }
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
    if crate::validate::validate_rgba(&rgba, width, height).is_err() {
        return rgba;
    }
    spatial::apply_shadow_highlight(&rgba, width as usize, height as usize, shadows, highlights)
}

/// Luma/chroma noise reduction.
pub fn spatial_denoise(rgba: Vec<u8>, width: u32, height: u32, luma: f32, chroma: f32) -> Vec<u8> {
    if crate::validate::validate_rgba(&rgba, width, height).is_err() {
        return rgba;
    }
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
    sharpen_radius: f32,
    sharpen_detail: f32,
    sharpen_masking: f32,
    denoise_luma: f32,
    denoise_chroma: f32,
    dehaze: f32,
    vignette: f32,
    vignette_midpoint: f32,
    vignette_feather: f32,
    vignette_roundness: f32,
    vignette_highlights: f32,
    grain: f32,
    grain_size: f32,
    grain_roughness: f32,
) -> Vec<u8> {
    if crate::validate::validate_rgba(&rgba, width, height).is_err() {
        return rgba;
    }
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
            sharpen_radius,
            sharpen_detail,
            sharpen_masking,
            denoise_luma,
            denoise_chroma,
            dehaze,
            vignette,
            vignette_midpoint,
            vignette_feather,
            vignette_roundness,
            vignette_highlights,
            grain,
            grain_size,
            grain_roughness,
            ..Default::default()
        },
    )
}

/// Generates a black-and-white preview of the edge mask (for Alt/Option hold on Masking slider).
pub fn spatial_sharpen_edge_mask(rgba: Vec<u8>, width: u32, height: u32, masking: f32) -> Vec<u8> {
    if crate::validate::validate_rgba(&rgba, width, height).is_err() {
        return Vec::new();
    }
    let mask = spatial::sharpen_edge_mask(&rgba, width as usize, height as usize, masking);
    let mut out = vec![255u8; mask.len() * 4];
    for (i, &m) in mask.iter().enumerate() {
        let val = (m * 255.0).clamp(0.0, 255.0) as u8;
        out[i * 4] = val;
        out[i * 4 + 1] = val;
        out[i * 4 + 2] = val;
        out[i * 4 + 3] = 255;
    }
    out
}
