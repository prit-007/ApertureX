//! Depth-aware Lens Blur and Synthetic Bokeh Engine (Lightroom Parity).
//!
//! Simulates optical DSLR/mirrorless lenses with adjustable aperture blur (f/1.4..f/22),
//! focal plane isolation, specular highlight boost, and polygonal aperture blade shapes
//! (circle, 5-blade pentagon, 6-blade hexagon, swirl).

/// Bokeh aperture blade shape.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BokehShape {
    Circle,
    Pentagon,
    Hexagon,
    Septagon,
    Swirl,
}

impl BokehShape {
    /// Bridge-facing index (`0..4`, matching the Dart `BokehShape` enum order).
    pub fn from_index(index: u8) -> Self {
        match index {
            0 => BokehShape::Circle,
            1 => BokehShape::Pentagon,
            2 => BokehShape::Hexagon,
            3 => BokehShape::Septagon,
            _ => BokehShape::Swirl,
        }
    }
}

/// Parameters for depth-guided optical lens blur.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct LensBlurParams {
    pub enabled: bool,
    /// Amount of aperture blur (`0..1`, where 1.0 = wide open f/1.2).
    pub amount: f32,
    /// Focal depth plane in focus (`0..1`).
    pub focal_point: f32,
    /// Depth of field range in sharp focus (`0..1`).
    pub focal_range: f32,
    /// Bokeh aperture blade shape.
    pub bokeh_shape: BokehShape,
    /// Specular highlight boost (`0..1`).
    pub bokeh_boost: f32,
}

impl Default for LensBlurParams {
    fn default() -> Self {
        Self {
            enabled: false,
            amount: 0.0,
            focal_point: 0.5,
            focal_range: 0.2,
            bokeh_shape: BokehShape::Circle,
            bokeh_boost: 0.0,
        }
    }
}

impl LensBlurParams {
    pub fn is_neutral(&self) -> bool {
        !self.enabled || self.amount <= 1e-4
    }

    /// Builds params from the flat bridge fields shared by
    /// `PreviewBaseSpec` (preview bake) and `ExportSpec` (export pipeline).
    pub fn from_fields(
        enabled: bool,
        amount: f32,
        focal_point: f32,
        focal_range: f32,
        bokeh_shape: u8,
        bokeh_boost: f32,
    ) -> Self {
        Self {
            enabled,
            amount,
            focal_point,
            focal_range,
            bokeh_shape: BokehShape::from_index(bokeh_shape),
            bokeh_boost,
        }
    }
}

/// Computes the Circle of Confusion (CoC) radius `0..1` for a given pixel depth.
#[inline(always)]
pub fn circle_of_confusion(depth: f32, focal_point: f32, focal_range: f32, amount: f32) -> f32 {
    let diff = (depth - focal_point).abs();
    let half_range = (focal_range * 0.5).max(1e-4);
    if diff <= half_range {
        0.0
    } else {
        let t = ((diff - half_range) / (1.0 - half_range).max(1e-4)).clamp(0.0, 1.0);
        t * amount
    }
}

/// Evaluates aperture blade distance threshold at polar angle `theta`.
#[inline(always)]
fn aperture_radius_limit(theta: f32, shape: BokehShape) -> f32 {
    match shape {
        BokehShape::Circle => 1.0,
        BokehShape::Pentagon => {
            let n = 5.0;
            let segment = std::f32::consts::TAU / n;
            let alpha = (theta % segment + segment) % segment - (segment * 0.5);
            (std::f32::consts::PI / n).cos() / alpha.cos().max(1e-3)
        }
        BokehShape::Hexagon => {
            let n = 6.0;
            let segment = std::f32::consts::TAU / n;
            let alpha = (theta % segment + segment) % segment - (segment * 0.5);
            (std::f32::consts::PI / n).cos() / alpha.cos().max(1e-3)
        }
        BokehShape::Septagon => {
            let n = 7.0;
            let segment = std::f32::consts::TAU / n;
            let alpha = (theta % segment + segment) % segment - (segment * 0.5);
            (std::f32::consts::PI / n).cos() / alpha.cos().max(1e-3)
        }
        BokehShape::Swirl => {
            // Anamorphic/Petzval swirl: elliptical compression with radial twist
            1.0 + 0.25 * (2.0 * theta).sin()
        }
    }
}

/// Applies depth-guided lens blur with synthetic bokeh.
///
/// If `depth_map` is empty, generates an optical distance gradient from optical center
/// and vertical portrait perspective.
pub fn apply_lens_blur(
    rgba: &[u8],
    w: usize,
    h: usize,
    params: LensBlurParams,
    depth_map: Option<&[f32]>,
) -> Vec<u8> {
    if params.is_neutral() || w <= 1 || h <= 1 {
        return rgba.to_vec();
    }

    let min_dim = w.min(h) as f32;
    let max_radius = (params.amount * min_dim * 0.08).clamp(1.0, 24.0);
    let mut out = vec![0u8; w * h * 4];

    // Precalculate synthetic depth map if not provided.
    // Portrait perspective: bottom foreground is close (depth ~ 0.2), center subject is ~0.5,
    // top background is far (depth ~ 0.9).
    let get_depth = |x: usize, y: usize| -> f32 {
        if let Some(dm) = depth_map {
            if dm.len() == w * h {
                return dm[y * w + x].clamp(0.0, 1.0);
            }
        }
        let py = y as f32 / (h - 1).max(1) as f32;
        let px = x as f32 / (w - 1).max(1) as f32;
        let dx = px - 0.5;
        let dy = py - 0.5;
        let center_dist = (dx * dx * 1.5 + dy * dy).sqrt();
        // Foreground near bottom, background near top/periphery, center subject at 0.5
        (0.35 + 0.45 * py + 0.3 * center_dist).clamp(0.0, 1.0)
    };

    for y in 0..h {
        for x in 0..w {
            let idx = (y * w + x) * 4;
            let pixel_depth = get_depth(x, y);
            let coc = circle_of_confusion(
                pixel_depth,
                params.focal_point,
                params.focal_range,
                params.amount,
            );

            // In sharp focal plane: copy pixel intact
            if coc <= 1e-3 {
                out[idx..idx + 4].copy_from_slice(&rgba[idx..idx + 4]);
                continue;
            }

            let kernel_r = (coc * max_radius).max(1.0);
            let kernel_r_int = kernel_r.ceil() as isize;

            let mut r_acc = 0.0f32;
            let mut g_acc = 0.0f32;
            let mut b_acc = 0.0f32;
            let mut weight_acc = 0.0f32;

            for dy in -kernel_r_int..=kernel_r_int {
                let ny = y as isize + dy;
                if ny < 0 || ny >= h as isize {
                    continue;
                }
                for dx in -kernel_r_int..=kernel_r_int {
                    let nx = x as isize + dx;
                    if nx < 0 || nx >= w as isize {
                        continue;
                    }

                    let dist = ((dx * dx + dy * dy) as f32).sqrt();
                    if dist > kernel_r {
                        continue;
                    }

                    let theta = (dy as f32).atan2(dx as f32);
                    let shape_limit = aperture_radius_limit(theta, params.bokeh_shape);
                    let norm_dist = dist / kernel_r;
                    if norm_dist > shape_limit {
                        continue;
                    }

                    // Depth-aware weighting: foreground should not bleed into sharp background
                    let sample_depth = get_depth(nx as usize, ny as usize);
                    let depth_weight = if sample_depth < pixel_depth - 0.15 {
                        0.1 // de-weight foreground bleeding onto background
                    } else {
                        1.0
                    };

                    let s_idx = (ny as usize * w + nx as usize) * 4;
                    let mut sr = rgba[s_idx] as f32;
                    let mut sg = rgba[s_idx + 1] as f32;
                    let mut sb = rgba[s_idx + 2] as f32;

                    // Specular highlight boost: amplify bright out-of-focus spots
                    if params.bokeh_boost > 0.0 {
                        let luma = 0.2126 * sr + 0.7152 * sg + 0.0722 * sb;
                        if luma > 180.0 {
                            let boost = 1.0 + params.bokeh_boost * ((luma - 180.0) / 75.0);
                            sr *= boost;
                            sg *= boost;
                            sb *= boost;
                        }
                    }

                    let w_val = depth_weight * (1.0 - (norm_dist / shape_limit).powi(2) * 0.3);
                    r_acc += sr * w_val;
                    g_acc += sg * w_val;
                    b_acc += sb * w_val;
                    weight_acc += w_val;
                }
            }

            if weight_acc > 0.0 {
                out[idx] = (r_acc / weight_acc).round().clamp(0.0, 255.0) as u8;
                out[idx + 1] = (g_acc / weight_acc).round().clamp(0.0, 255.0) as u8;
                out[idx + 2] = (b_acc / weight_acc).round().clamp(0.0, 255.0) as u8;
                out[idx + 3] = rgba[idx + 3];
            } else {
                out[idx..idx + 4].copy_from_slice(&rgba[idx..idx + 4]);
            }
        }
    }

    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn neutral_lens_blur_is_noop() {
        let src = vec![128u8; 16 * 16 * 4];
        let out = apply_lens_blur(&src, 16, 16, LensBlurParams::default(), None);
        assert_eq!(out, src);
    }

    #[test]
    fn focal_plane_preserves_sharpness_while_background_blurs() {
        let (w, h) = (16, 16);
        // Create an image with high contrast checkerboard
        let mut src = vec![0u8; w * h * 4];
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                let v = if (x + y) % 2 == 0 { 255 } else { 0 };
                src[idx] = v;
                src[idx + 1] = v;
                src[idx + 2] = v;
                src[idx + 3] = 255;
            }
        }

        // Custom depth map: left side is in-focus (depth 0.5), right side is background (depth 1.0)
        let mut depth_map = vec![0.0f32; w * h];
        for y in 0..h {
            for x in 0..w {
                depth_map[y * w + x] = if x < 8 { 0.5 } else { 1.0 };
            }
        }

        let params = LensBlurParams {
            enabled: true,
            amount: 0.8,
            focal_point: 0.5,
            focal_range: 0.1,
            bokeh_shape: BokehShape::Circle,
            bokeh_boost: 0.0,
        };

        let out = apply_lens_blur(&src, w, h, params, Some(&depth_map));

        // In-focus left side (x=2, y=2): should retain high contrast checkerboard
        let in_focus_idx = (2 * w + 2) * 4;
        assert_eq!(out[in_focus_idx], src[in_focus_idx]);

        // Out-of-focus right side (x=12, y=12): checkerboard (initially 255) should be heavily blurred away from 255
        let out_focus_idx = (12 * w + 12) * 4;
        assert!(
            out[out_focus_idx] < 150,
            "Blurred background pixel should blend away from 255: got {}",
            out[out_focus_idx]
        );
    }

    #[test]
    fn bokeh_boost_amplifies_specular_highlights() {
        let (w, h) = (16, 16);
        let mut src = vec![10u8; w * h * 4];
        // Specular highlight dot at (12, 12) in background
        let dot_idx = (12 * w + 12) * 4;
        src[dot_idx] = 250;
        src[dot_idx + 1] = 250;
        src[dot_idx + 2] = 250;
        src[dot_idx + 3] = 255;

        // Entire image is out of focus (depth 1.0 vs focal point 0.0)
        let depth_map = vec![1.0f32; w * h];

        let base_params = LensBlurParams {
            enabled: true,
            amount: 0.5,
            focal_point: 0.0,
            focal_range: 0.1,
            bokeh_shape: BokehShape::Circle,
            bokeh_boost: 0.0,
        };
        let out_normal = apply_lens_blur(&src, w, h, base_params, Some(&depth_map));

        let boosted_params = LensBlurParams {
            bokeh_boost: 1.0,
            ..base_params
        };
        let out_boosted = apply_lens_blur(&src, w, h, boosted_params, Some(&depth_map));

        // Surrounding bokeh disc around (12, 12) should be brighter with bokeh_boost
        let sample_idx = (12 * w + 11) * 4;
        assert!(
            out_boosted[sample_idx] > out_normal[sample_idx],
            "Boosted bokeh disc should be brighter: normal={}, boosted={}",
            out_normal[sample_idx],
            out_boosted[sample_idx]
        );
    }
}
