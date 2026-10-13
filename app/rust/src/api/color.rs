//! Colour + LUT API exposed across the `flutter_rust_bridge` boundary.
//!
//! Thin wrappers over [`crate::color`]: bake the grade into a 2D-packed 3D LUT
//! (preview), or apply the same pipeline per-pixel (export). Because both call
//! the same core, preview and export agree by construction.

use crate::color;

/// A colour pipeline baked into a 2D-packed RGBA8 LUT atlas.
pub struct LutData {
    /// LUT edge length (e.g. 33).
    pub size: u32,
    /// Atlas width  = `size * size`.
    pub width: u32,
    /// Atlas height = `size`.
    pub height: u32,
    /// RGBA8 atlas, length `width * height * 4`.
    pub rgba: Vec<u8>,
}

/// Bakes the grade (exposure EV, contrast, saturation) into a 3D LUT atlas.
pub fn bake_lut3d(size: u32, exposure: f32, contrast: f32, saturation: f32) -> LutData {
    let rgba = color::bake_lut3d(size, exposure, contrast, saturation);
    LutData {
        size,
        width: size * size,
        height: size,
        rgba,
    }
}

/// Applies the same pipeline to an RGBA8 buffer (the export-path twin of the
/// LUT), preserving alpha.
pub fn grade_rgba(rgba: Vec<u8>, exposure: f32, contrast: f32, saturation: f32) -> Vec<u8> {
    let mut out = rgba;
    for px in out.as_chunks_mut::<4>().0 {
        let c = color::grade_pixel_srgb(
            px[0] as f32 / 255.0,
            px[1] as f32 / 255.0,
            px[2] as f32 / 255.0,
            exposure,
            contrast,
            saturation,
        );
        px[0] = (c[0] * 255.0 + 0.5) as u8;
        px[1] = (c[1] * 255.0 + 0.5) as u8;
        px[2] = (c[2] * 255.0 + 0.5) as u8;
    }
    out
}
