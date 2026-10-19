//! Colour + LUT API exposed across the `flutter_rust_bridge` boundary.
//!
//! Thin wrappers over [`crate::color`]: bake the point-wise grade (plus tone
//! curves) into a 2D-packed 3D LUT (preview), or apply the same pipeline
//! per-pixel (export). Both call the same core, so preview and export agree.

use std::collections::HashMap;

use crate::color::{self, CurveSet, GradeParams};
use crate::decode::decode_rgba;

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

/// Analyzes image luminance/color and returns suggested auto-tone adjustments.
///
/// Returns a map of parameter name → suggested value:
/// Analyzes image luminance/color and returns suggested auto-tone adjustments.
///
/// Accepts JPEG bytes (decodes internally). Returns a map of parameter name to
/// suggested value:
///   - `exposure`: EV to bring mean luminance to mid-gray (~0.18)
///   - `contrast`: based on luminance standard deviation
///   - `highlights`/`shadows`: based on histogram clipping
///   - `whites`/`blacks`: based on 99th/1st luminance percentiles
///   - `temperature`/`tint`: based on white balance analysis
pub fn auto_tone(jpeg: Vec<u8>) -> Option<HashMap<String, f64>> {
    // Decode JPEG to RGBA
    let decoded = match decode_rgba(&jpeg) {
        Ok(d) => d,
        Err(_) => return None,
    };

    let rgba = decoded.rgba;
    let width = decoded.width;
    let height = decoded.height;
    let n = width * height;
    if n == 0 || rgba.len() < n * 4 {
        return None;
    }

    // Collect luminance samples (downsample for speed)
    let step = (n / 50000).max(1);
    let mut luma_sum = 0.0f64;
    let mut luma_sq_sum = 0.0f64;
    let mut r_sum = 0.0f64;
    let mut g_sum = 0.0f64;
    let mut b_sum = 0.0f64;
    let mut count = 0usize;

    let mut lumas = Vec::with_capacity(n / step);
    for i in (0..n * 4).step_by(step * 4) {
        let r = rgba[i] as f64 / 255.0;
        let g = rgba[i + 1] as f64 / 255.0;
        let b = rgba[i + 2] as f64 / 255.0;
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        lumas.push(luma);
        luma_sum += luma;
        luma_sq_sum += luma * luma;
        r_sum += r;
        g_sum += g;
        b_sum += b;
        count += 1;
    }

    if count == 0 {
        return None;
    }

    let mean_luma = luma_sum / count as f64;
    let variance = luma_sq_sum / count as f64 - mean_luma * mean_luma;
    let std_luma = variance.max(0.0).sqrt();

    // Percentiles for whites/blacks
    lumas.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let p1_idx = (count as f64 * 0.01).round() as usize - 1;
    let p99_idx = (count as f64 * 0.99).round() as usize - 1;
    let p1 = lumas.get(p1_idx.min(count - 1)).copied().unwrap_or(0.0);
    let p99 = lumas.get(p99_idx.min(count - 1)).copied().unwrap_or(1.0);

    // Target mean luminance ~0.18 (mid-gray)
    let target_luma = 0.18;
    let exposure = (target_luma / mean_luma.max(0.001)).log2().clamp(-2.0, 2.0);

    // Contrast based on std deviation
    let contrast = (std_luma * 2.0 - 0.3).clamp(-0.5, 0.5);

    // Whites/blacks from percentiles
    let whites = ((p99 - 0.9) * 2.0).clamp(-1.0, 1.0);
    let blacks = ((0.1 - p1) * 2.0).clamp(-1.0, 1.0);

    // Highlights/shadows recovery
    let highlights = if p99 > 0.95 { -0.3 } else { 0.0 };
    let shadows = if p1 < 0.05 { 0.3 } else { 0.0 };

    // Temperature/tint from color balance
    let mean_r = r_sum / count as f64;
    let mean_g = g_sum / count as f64;
    let mean_b = b_sum / count as f64;
    let temperature = ((mean_r - mean_b) * 2.0).clamp(-0.5, 0.5);
    let tint = ((mean_g - (mean_r + mean_b) / 2.0) * 2.0).clamp(-0.5, 0.5);

    let mut map = HashMap::new();
    map.insert("exposure".to_string(), exposure);
    map.insert("contrast".to_string(), contrast);
    map.insert("highlights".to_string(), highlights);
    map.insert("shadows".to_string(), shadows);
    map.insert("whites".to_string(), whites);
    map.insert("blacks".to_string(), blacks);
    map.insert("temperature".to_string(), temperature);
    map.insert("tint".to_string(), tint);

    Some(map)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::export::encode_jpeg;

    fn make_gray_jpeg(gray: u8) -> Vec<u8> {
        let rgba = vec![gray; 16 * 16 * 4];
        encode_jpeg(&rgba, 16, 16, 80, &[]).unwrap()
    }

    #[test]
    fn auto_tone_neutral_gray_returns_neutral_adjustments() {
        // Uniform mid-gray image → minimal adjustments
        let jpeg = make_gray_jpeg(46u8); // ~18% gray
        let result = auto_tone(jpeg);
        assert!(result.is_some());
        let m = result.unwrap();
        // Exposure should be near 0 for 18% gray
        assert!((m["exposure"] - 0.0).abs() < 0.3);
    }

    #[test]
    fn auto_tone_dark_image_positive_exposure() {
        // Very dark image → positive exposure
        let jpeg = make_gray_jpeg(20u8);
        let result = auto_tone(jpeg);
        assert!(result.is_some());
        let m = result.unwrap();
        assert!(m["exposure"] > 0.0);
    }

    #[test]
    fn auto_tone_bright_image_negative_exposure() {
        // Very bright image → negative exposure
        let jpeg = make_gray_jpeg(240u8);
        let result = auto_tone(jpeg);
        assert!(result.is_some());
        let m = result.unwrap();
        assert!(m["exposure"] < 0.0);
    }

    #[test]
    fn auto_tone_empty_returns_none() {
        assert!(auto_tone(vec![]).is_none());
    }
}
