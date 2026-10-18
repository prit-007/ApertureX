//! Colour + LUT API exposed across the `flutter_rust_bridge` boundary.
//!
//! Thin wrappers over [`crate::color`]: bake the point-wise grade (plus tone
//! curves) into a 2D-packed 3D LUT (preview), or apply the same pipeline
//! per-pixel (export). Both call the same core, so preview and export agree.

use crate::color::{self, CurveSet, GradeParams};

/// Point-wise grade parameters (all neutral at 0).
#[derive(Default)]
pub struct ColorParams {
    pub exposure: f32,
    pub contrast: f32,
    pub highlights: f32,
    pub shadows: f32,
    pub whites: f32,
    pub blacks: f32,
    pub saturation: f32,
    pub temperature: f32,
    pub tint: f32,
    pub vibrance: f32,
    pub grade_shadow_hue: f32,
    pub grade_shadow_sat: f32,
    pub grade_shadow_lum: f32,
    pub grade_mid_hue: f32,
    pub grade_mid_sat: f32,
    pub grade_mid_lum: f32,
    pub grade_highlight_hue: f32,
    pub grade_highlight_sat: f32,
    pub grade_highlight_lum: f32,
    pub grade_blending: f32,
    pub grade_balance: f32,
}

impl ColorParams {
    pub(crate) fn to_core(&self) -> GradeParams {
        GradeParams {
            exposure: self.exposure,
            contrast: self.contrast,
            highlights: self.highlights,
            shadows: self.shadows,
            whites: self.whites,
            blacks: self.blacks,
            saturation: self.saturation,
            temperature: self.temperature,
            tint: self.tint,
            vibrance: self.vibrance,
            grade_shadow_hue: self.grade_shadow_hue,
            grade_shadow_sat: self.grade_shadow_sat,
            grade_shadow_lum: self.grade_shadow_lum,
            grade_mid_hue: self.grade_mid_hue,
            grade_mid_sat: self.grade_mid_sat,
            grade_mid_lum: self.grade_mid_lum,
            grade_highlight_hue: self.grade_highlight_hue,
            grade_highlight_sat: self.grade_highlight_sat,
            grade_highlight_lum: self.grade_highlight_lum,
            grade_blending: self.grade_blending,
            grade_balance: self.grade_balance,
        }
    }
    pub fn is_neutral(&self) -> bool {
        self.exposure == 0.0
            && self.contrast == 0.0
            && self.highlights == 0.0
            && self.shadows == 0.0
            && self.whites == 0.0
            && self.blacks == 0.0
            && self.saturation == 0.0
            && self.temperature == 0.0
            && self.tint == 0.0
            && self.vibrance == 0.0
            && self.grade_shadow_sat == 0.0
            && self.grade_shadow_lum == 0.0
            && self.grade_mid_sat == 0.0
            && self.grade_mid_lum == 0.0
            && self.grade_highlight_sat == 0.0
            && self.grade_highlight_lum == 0.0
            && self.grade_balance == 0.0
    }
}

/// Tone-curve control points, flat `[x0,y0,x1,y1,...]` per curve. An empty list
/// is the identity curve.
pub struct CurveParams {
    pub master: Vec<f32>,
    pub red: Vec<f32>,
    pub green: Vec<f32>,
    pub blue: Vec<f32>,
}

impl CurveParams {
    pub(crate) fn to_set(&self) -> CurveSet {
        CurveSet::from_points(&self.master, &self.red, &self.green, &self.blue)
    }
}

/// Pads/truncates a flat HSL list (8 bands × 3) to a fixed `[f32; 24]`.
pub(crate) fn to_hsl24(v: &[f32]) -> [f32; 24] {
    let mut a = [0.0f32; 24];
    for (slot, value) in a.iter_mut().zip(v.iter()) {
        *slot = *value;
    }
    a
}

/// A colour pipeline baked into a 2D-packed RGBA8 LUT atlas.
pub struct LutData {
    pub size: u32,
    pub width: u32,
    pub height: u32,
    pub rgba: Vec<u8>,
}

/// Bakes the grade (tone curves + HSL mix) into a 3D LUT atlas.
pub fn bake_lut3d(size: u32, params: ColorParams, curves: CurveParams, hsl: Vec<f32>) -> LutData {
    let clamped_size = size.clamp(2, 256);
    let set = curves.to_set();
    let rgba =
        color::bake_lut3d_curves(clamped_size, params.to_core(), Some(&set), &to_hsl24(&hsl));
    LutData {
        size: clamped_size,
        width: clamped_size * clamped_size,
        height: clamped_size,
        rgba,
    }
}

/// Applies the same pipeline (tone curves + HSL) per-pixel over RGBA — the
/// export twin of the LUT.
pub fn grade_rgba(
    rgba: Vec<u8>,
    params: ColorParams,
    curves: CurveParams,
    hsl: Vec<f32>,
) -> Vec<u8> {
    let p = params.to_core();
    let set = curves.to_set();
    let hsl = to_hsl24(&hsl);
    let mut out = rgba;
    for px in out.as_chunks_mut::<4>().0 {
        let c = color::grade_pixel_c(
            px[0] as f32 / 255.0,
            px[1] as f32 / 255.0,
            px[2] as f32 / 255.0,
            p,
            Some(&set),
            &hsl,
        );
        px[0] = (c[0] * 255.0 + 0.5) as u8;
        px[1] = (c[1] * 255.0 + 0.5) as u8;
        px[2] = (c[2] * 255.0 + 0.5) as u8;
    }
    out
}

/// Exports the grade (tone curves + HSL mix + color wheels) as a DaVinci Resolve / Premiere compliant `.cube` 3D LUT string.
pub fn export_cube_lut(
    size: u32,
    params: ColorParams,
    curves: CurveParams,
    hsl: Vec<f32>,
    title: Option<String>,
) -> String {
    let set = curves.to_set();
    color::export_cube_lut(
        size,
        params.to_core(),
        Some(&set),
        &to_hsl24(&hsl),
        title.as_deref(),
    )
}
