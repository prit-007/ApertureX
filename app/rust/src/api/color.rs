//! Colour + LUT API exposed across the `flutter_rust_bridge` boundary.
//!
//! Thin wrappers over [`crate::color`]: bake the point-wise grade into a
//! 2D-packed 3D LUT (preview), or apply the same pipeline per-pixel (export).
//! Both call the same core, so preview and export agree by construction.

use crate::color::{self, GradeParams};

/// Point-wise grade parameters (all neutral at 0).
pub struct ColorParams {
    pub exposure: f32,
    pub contrast: f32,
    pub saturation: f32,
    pub temperature: f32,
    pub tint: f32,
    pub vibrance: f32,
    pub grade_shadow_hue: f32,
    pub grade_shadow_sat: f32,
    pub grade_mid_hue: f32,
    pub grade_mid_sat: f32,
    pub grade_highlight_hue: f32,
    pub grade_highlight_sat: f32,
}

impl ColorParams {
    fn to_core(&self) -> GradeParams {
        GradeParams {
            exposure: self.exposure,
            contrast: self.contrast,
            saturation: self.saturation,
            temperature: self.temperature,
            tint: self.tint,
            vibrance: self.vibrance,
            grade_shadow_hue: self.grade_shadow_hue,
            grade_shadow_sat: self.grade_shadow_sat,
            grade_mid_hue: self.grade_mid_hue,
            grade_mid_sat: self.grade_mid_sat,
            grade_highlight_hue: self.grade_highlight_hue,
            grade_highlight_sat: self.grade_highlight_sat,
        }
    }
}

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

/// Bakes the grade into a 3D LUT atlas.
pub fn bake_lut3d(size: u32, params: ColorParams) -> LutData {
    let rgba = color::bake_lut3d(size, params.to_core());
    LutData {
        size,
        width: size * size,
        height: size,
        rgba,
    }
}

/// Applies the same pipeline to an RGBA8 buffer (the export-path twin of the
/// LUT), preserving alpha.
pub fn grade_rgba(rgba: Vec<u8>, params: ColorParams) -> Vec<u8> {
    let p = params.to_core();
    let mut out = rgba;
    for px in out.as_chunks_mut::<4>().0 {
        let c = color::grade_pixel_srgb(
            px[0] as f32 / 255.0,
            px[1] as f32 / 255.0,
            px[2] as f32 / 255.0,
            p,
        );
        px[0] = (c[0] * 255.0 + 0.5) as u8;
        px[1] = (c[1] * 255.0 + 0.5) as u8;
        px[2] = (c[2] * 255.0 + 0.5) as u8;
    }
    out
}
