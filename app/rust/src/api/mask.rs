//! Masking / local adjustments API across the `flutter_rust_bridge` boundary.

use crate::api::color::ColorParams;
use crate::mask::{self, LocalAdjustment, MaskSpec};

/// One adjustment layer: a parametric mask + a point-wise sub-grade.
pub struct MaskLayer {
    /// Mask kind:
    /// 0 linear, 1 radial, 2 luminance, 3 brush, 4 subject, 5 sky, 6 bitmap.
    pub kind: u32,
    /// Parameter payload:
    /// - linear: `[x0, y0, x1, y1]`
    /// - radial: `[cx, cy, rx, ry, feather]`
    /// - luminance: `[lo, hi]`
    /// - brush: `[radius, feather, count, ...stroke_points_with_sentinels]`
    /// - subject: `[cx, cy, rx, ry, feather]`
    /// - sky: `[horizon_y, feather, blue_weight]`
    /// - bitmap: `[w, h, ...unpacked_alphas]`
    pub mask: Vec<f32>,
    pub params: ColorParams,
    /// When true, inverts the mask coverage (`1.0 - coverage`).
    pub inverted: bool,
}

/// Composites [layers] over [rgba] (RGBA8, `width*height*4`), in order.
pub fn apply_masks(rgba: Vec<u8>, width: u32, height: u32, layers: Vec<MaskLayer>) -> Vec<u8> {
    let core: Vec<LocalAdjustment> = layers
        .into_iter()
        .map(|l| LocalAdjustment {
            mask: MaskSpec {
                kind: l.kind,
                params: l.mask,
            },
            params: l.params.to_core(),
            inverted: l.inverted,
        })
        .collect();
    mask::apply_local(&rgba, width as usize, height as usize, &core)
}

/// Detected sky parameters from a proxy image.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct DetectedSky {
    pub horizon_y: f32,
    pub feather: f32,
    pub blue_weight: f32,
}

/// Automatically detects sky horizon, transition feather, and blue chromaticity weight.
pub fn detect_sky(rgba: Vec<u8>, width: u32, height: u32) -> Option<DetectedSky> {
    mask::detect_sky(&rgba, width as usize, height as usize).map(|d| DetectedSky {
        horizon_y: d.horizon_y,
        feather: d.feather,
        blue_weight: d.blue_weight,
    })
}
