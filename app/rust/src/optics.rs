//! Optics and lens corrections:
//! - Lateral Chromatic Aberration correction (radial R/B realignment)
//! - Longitudinal (Axial) Defringe (purple and green fringe desaturation on contrast edges)
//! - Lens profile distortion and vignetting

use crate::color::{hsl_to_rgb, rgb_to_hsl};

/// Parameters for lens optics and chromatic aberration corrections.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct OpticsParams {
    /// Automatic lateral chromatic aberration removal.
    pub remove_chromatic_aberration: bool,
    /// Purple fringe reduction amount (`0..1`).
    pub defringe_purple_amount: f32,
    /// Minimum purple hue (`0..1`, default ~0.70).
    pub defringe_purple_hue_min: f32,
    /// Maximum purple hue (`0..1`, default ~0.95).
    pub defringe_purple_hue_max: f32,
    /// Green fringe reduction amount (`0..1`).
    pub defringe_green_amount: f32,
    /// Minimum green hue (`0..1`, default ~0.17).
    pub defringe_green_hue_min: f32,
    /// Maximum green hue (`0..1`, default ~0.50).
    pub defringe_green_hue_max: f32,
    /// Enable lens profile corrections (distortion & vignette).
    pub profile_corrections: bool,
    /// Distortion correction scale (`0..2`, default 1.0 = 100%).
    pub profile_distortion: f32,
    /// Vignetting correction scale (`0..2`, default 1.0 = 100%).
    pub profile_vignetting: f32,
}

impl Default for OpticsParams {
    fn default() -> Self {
        Self {
            remove_chromatic_aberration: false,
            defringe_purple_amount: 0.0,
            defringe_purple_hue_min: 0.70,
            defringe_purple_hue_max: 0.95,
            defringe_green_amount: 0.0,
            defringe_green_hue_min: 0.17,
            defringe_green_hue_max: 0.50,
            profile_corrections: false,
            profile_distortion: 1.0,
            profile_vignetting: 1.0,
        }
    }
}

impl OpticsParams {
    /// True when optics would be a no-op.
    pub fn is_neutral(&self) -> bool {
        !self.remove_chromatic_aberration
            && self.defringe_purple_amount == 0.0
            && self.defringe_green_amount == 0.0
            && (!self.profile_corrections
                || (self.profile_distortion == 0.0 && self.profile_vignetting == 0.0))
    }
}

/// Bilinear sampling of a single color channel from RGBA buffer with border clamp.
#[inline(always)]
fn sample_channel_bilinear(rgba: &[u8], w: usize, h: usize, x: f32, y: f32, channel: usize) -> f32 {
    let x = x.clamp(0.0, (w - 1) as f32);
    let y = y.clamp(0.0, (h - 1) as f32);

    let x0 = x.floor() as usize;
    let y0 = y.floor() as usize;
    let x1 = (x0 + 1).min(w - 1);
    let y1 = (y0 + 1).min(h - 1);

    let fx = x - x0 as f32;
    let fy = y - y0 as f32;

    let v00 = rgba[(y0 * w + x0) * 4 + channel] as f32;
    let v10 = rgba[(y0 * w + x1) * 4 + channel] as f32;
    let v01 = rgba[(y1 * w + x0) * 4 + channel] as f32;
    let v11 = rgba[(y1 * w + x1) * 4 + channel] as f32;

    let top = v00 * (1.0 - fx) + v10 * fx;
    let bottom = v01 * (1.0 - fx) + v11 * fx;
    top * (1.0 - fy) + bottom * fy
}

/// Applies lateral chromatic aberration correction by subpixel radial scaling
/// of red and blue channels towards green optical center.
pub fn apply_lateral_ca(rgba: &[u8], w: usize, h: usize) -> Vec<u8> {
    if w <= 1 || h <= 1 {
        return rgba.to_vec();
    }
    let mut out = rgba.to_vec();
    let cx = (w - 1) as f32 * 0.5;
    let cy = (h - 1) as f32 * 0.5;
    let max_radius_sq = (cx * cx + cy * cy).max(1.0);

    // Standard optical lateral CA scale factor (sub-percent radial dispersion)
    const K_RED: f32 = -0.0018;
    const K_BLUE: f32 = 0.0018;

    for y in 0..h {
        let dy = y as f32 - cy;
        for x in 0..w {
            let dx = x as f32 - cx;
            let r2 = (dx * dx + dy * dy) / max_radius_sq;

            let scale_r = 1.0 + K_RED * r2;
            let scale_b = 1.0 + K_BLUE * r2;

            let rx = cx + dx * scale_r;
            let ry = cy + dy * scale_r;

            let bx = cx + dx * scale_b;
            let by = cy + dy * scale_b;

            let idx = (y * w + x) * 4;
            out[idx] = sample_channel_bilinear(rgba, w, h, rx, ry, 0)
                .round()
                .clamp(0.0, 255.0) as u8;
            // Green channel is reference, remains unchanged
            out[idx + 2] = sample_channel_bilinear(rgba, w, h, bx, by, 2)
                .round()
                .clamp(0.0, 255.0) as u8;
        }
    }
    out
}

/// Longitudinal (axial) defringe: detects high-contrast edges and desaturates
/// purple and green color fringes.
#[allow(clippy::too_many_arguments)]
pub fn apply_defringe(
    rgba: &[u8],
    w: usize,
    h: usize,
    purple_amount: f32,
    purple_min: f32,
    purple_max: f32,
    green_amount: f32,
    green_min: f32,
    green_max: f32,
) -> Vec<u8> {
    let n = w * h;
    if n == 0 || (purple_amount <= 0.0 && green_amount <= 0.0) {
        return rgba.to_vec();
    }

    // 1. Calculate luminance plane for contrast gradient
    let mut luma = Vec::with_capacity(n);
    for i in 0..n {
        let r = rgba[i * 4] as f32;
        let g = rgba[i * 4 + 1] as f32;
        let b = rgba[i * 4 + 2] as f32;
        luma.push(0.2126 * r + 0.7152 * g + 0.0722 * b);
    }

    let mut out = rgba.to_vec();

    for y in 0..h {
        let y_prev = y.saturating_sub(1);
        let y_next = (y + 1).min(h - 1);
        for x in 0..w {
            let x_prev = x.saturating_sub(1);
            let x_next = (x + 1).min(w - 1);

            let dx = luma[y * w + x_next] - luma[y * w + x_prev];
            let dy = luma[y_next * w + x] - luma[y_prev * w + x];
            let grad = (dx * dx + dy * dy).sqrt();

            // Ignore flat regions; fringes only occur at high-contrast transitions
            if grad < 8.0 {
                continue;
            }
            let edge_weight = ((grad - 8.0) / 40.0).clamp(0.0, 1.0);

            let idx = (y * w + x) * 4;
            let r = rgba[idx] as f32 / 255.0;
            let g = rgba[idx + 1] as f32 / 255.0;
            let b = rgba[idx + 2] as f32 / 255.0;

            let [h_val, s_val, l_val] = rgb_to_hsl([r, g, b]);
            if s_val < 0.05 {
                continue;
            }

            let mut new_s = s_val;

            // Purple fringe test
            if purple_amount > 0.0 && h_val >= purple_min && h_val <= purple_max {
                let damp = 1.0 - (purple_amount * edge_weight).clamp(0.0, 1.0);
                new_s *= damp;
            }

            // Green fringe test
            if green_amount > 0.0 && h_val >= green_min && h_val <= green_max {
                let damp = 1.0 - (green_amount * edge_weight).clamp(0.0, 1.0);
                new_s *= damp;
            }

            if (new_s - s_val).abs() > 1e-4 {
                let [nr, ng, nb] = hsl_to_rgb([h_val, new_s, l_val]);
                out[idx] = (nr * 255.0).round().clamp(0.0, 255.0) as u8;
                out[idx + 1] = (ng * 255.0).round().clamp(0.0, 255.0) as u8;
                out[idx + 2] = (nb * 255.0).round().clamp(0.0, 255.0) as u8;
            }
        }
    }

    out
}

/// Applies lens profile geometric distortion and vignetting correction.
///
/// - `distortion_scale`: scaling factor for lens distortion correction (barrel/pincushion).
/// - `vignetting_scale`: scaling factor for lens profile vignetting compensation.
pub fn apply_lens_profile(
    rgba: &[u8],
    w: usize,
    h: usize,
    distortion_scale: f32,
    vignetting_scale: f32,
) -> Vec<u8> {
    if w <= 1 || h <= 1 || (distortion_scale == 0.0 && vignetting_scale == 0.0) {
        return rgba.to_vec();
    }

    let mut out = vec![0u8; w * h * 4];
    let cx = (w - 1) as f32 * 0.5;
    let cy = (h - 1) as f32 * 0.5;
    let half_diag = (cx * cx + cy * cy).sqrt().max(f32::EPSILON);

    // Standard profile polynomial coefficients scaled by user parameters.
    // k_dist represents typical wide/zoom lens barrel distortion (k0 < 0, k1 > 0).
    let k_dist = [-0.04 * distortion_scale, 0.01 * distortion_scale, 0.0];
    let k_vig = [0.3 * vignetting_scale, 0.1 * vignetting_scale, 0.0];

    for y in 0..h {
        let dy = (y as f32 - cy) / half_diag;
        for x in 0..w {
            let dx = (x as f32 - cx) / half_diag;
            let r = (dx * dx + dy * dy).sqrt();

            let (src_x, src_y) = if distortion_scale != 0.0 && r > 1e-6 {
                let src_r = crate::raw::lens::undistort_radius(r, &k_dist);
                let scale = src_r / r;
                (cx + dx * scale * half_diag, cy + dy * scale * half_diag)
            } else {
                (x as f32, y as f32)
            };

            let gain = if vignetting_scale != 0.0 {
                crate::raw::lens::vignette_gain(r, &k_vig)
            } else {
                1.0
            };

            let r_val = (sample_channel_bilinear(rgba, w, h, src_x, src_y, 0) * gain)
                .round()
                .clamp(0.0, 255.0) as u8;
            let g_val = (sample_channel_bilinear(rgba, w, h, src_x, src_y, 1) * gain)
                .round()
                .clamp(0.0, 255.0) as u8;
            let b_val = (sample_channel_bilinear(rgba, w, h, src_x, src_y, 2) * gain)
                .round()
                .clamp(0.0, 255.0) as u8;
            let a_val = sample_channel_bilinear(rgba, w, h, src_x, src_y, 3)
                .round()
                .clamp(0.0, 255.0) as u8;

            let idx = (y * w + x) * 4;
            out[idx] = r_val;
            out[idx + 1] = g_val;
            out[idx + 2] = b_val;
            out[idx + 3] = a_val;
        }
    }

    out
}

/// Runs the full optics pass: lateral CA removal → lens profile corrections → longitudinal defringe.
pub fn apply_optics(rgba: &[u8], w: usize, h: usize, p: OpticsParams) -> Vec<u8> {
    if p.is_neutral() || w == 0 || h == 0 {
        return rgba.to_vec();
    }

    let ca_buf = if p.remove_chromatic_aberration {
        apply_lateral_ca(rgba, w, h)
    } else {
        rgba.to_vec()
    };

    let profile_buf =
        if p.profile_corrections && (p.profile_distortion != 0.0 || p.profile_vignetting != 0.0) {
            apply_lens_profile(&ca_buf, w, h, p.profile_distortion, p.profile_vignetting)
        } else {
            ca_buf
        };

    if p.defringe_purple_amount > 0.0 || p.defringe_green_amount > 0.0 {
        apply_defringe(
            &profile_buf,
            w,
            h,
            p.defringe_purple_amount,
            p.defringe_purple_hue_min,
            p.defringe_purple_hue_max,
            p.defringe_green_amount,
            p.defringe_green_hue_min,
            p.defringe_green_hue_max,
        )
    } else {
        profile_buf
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn neutral_optics_params_is_a_noop() {
        let src = vec![128u8; 16 * 16 * 4];
        let out = apply_optics(&src, 16, 16, OpticsParams::default());
        assert_eq!(out, src);
    }

    #[test]
    fn defringe_purple_preserves_neutral_contrast_edge() {
        // High-contrast black and white edge: no chromatic fringe
        let mut src = vec![0u8; 8 * 8 * 4];
        for y in 0..8 {
            for x in 4..8 {
                let idx = (y * 8 + x) * 4;
                src[idx] = 255;
                src[idx + 1] = 255;
                src[idx + 2] = 255;
                src[idx + 3] = 255;
            }
        }
        let out = apply_defringe(&src, 8, 8, 1.0, 0.70, 0.95, 0.0, 0.17, 0.50);
        // Greyscale edges have saturation 0, so defringe should leave them completely intact
        assert_eq!(out, src);
    }

    #[test]
    fn defringe_purple_desaturates_purple_fringe_on_contrast_edge() {
        // Create an 8x8 image: left side dark (0,0,0), right side bright white (255,255,255),
        // with purple fringe pixels along the transition column (x=3)
        let mut src = vec![0u8; 8 * 8 * 4];
        for y in 0..8 {
            for x in 0..8 {
                let idx = (y * 8 + x) * 4;
                src[idx + 3] = 255;
                if x >= 4 {
                    src[idx] = 255;
                    src[idx + 1] = 255;
                    src[idx + 2] = 255;
                } else if x == 3 {
                    // Saturated purple fringe: high red and blue, low green
                    src[idx] = 200;
                    src[idx + 1] = 30;
                    src[idx + 2] = 220;
                }
            }
        }

        let out = apply_defringe(
            &src, 8, 8, 1.0, // full purple defringe
            0.70, 0.95, 0.0, 0.17, 0.50,
        );

        let fringe_before = &src[(4 * 8 + 3) * 4..(4 * 8 + 3) * 4 + 3];
        let fringe_after = &out[(4 * 8 + 3) * 4..(4 * 8 + 3) * 4 + 3];

        let [_, s_before, _] = rgb_to_hsl([
            fringe_before[0] as f32 / 255.0,
            fringe_before[1] as f32 / 255.0,
            fringe_before[2] as f32 / 255.0,
        ]);
        let [_, s_after, _] = rgb_to_hsl([
            fringe_after[0] as f32 / 255.0,
            fringe_after[1] as f32 / 255.0,
            fringe_after[2] as f32 / 255.0,
        ]);

        assert!(
            s_after < s_before * 0.5,
            "defringe should substantially reduce saturation: before={s_before}, after={s_after}"
        );
    }

    #[test]
    fn defringe_green_desaturates_green_fringe_on_contrast_edge() {
        // Create an 8x8 image with green fringe pixels along x=3
        let mut src = vec![0u8; 8 * 8 * 4];
        for y in 0..8 {
            for x in 0..8 {
                let idx = (y * 8 + x) * 4;
                src[idx + 3] = 255;
                if x >= 4 {
                    src[idx] = 255;
                    src[idx + 1] = 255;
                    src[idx + 2] = 255;
                } else if x == 3 {
                    // Saturated green fringe: low red and blue, high green
                    src[idx] = 30;
                    src[idx + 1] = 220;
                    src[idx + 2] = 50;
                }
            }
        }

        let out = apply_defringe(
            &src, 8, 8, 0.0, 0.70, 0.95, 1.0, // full green defringe
            0.17, 0.50,
        );

        let fringe_before = &src[(4 * 8 + 3) * 4..(4 * 8 + 3) * 4 + 3];
        let fringe_after = &out[(4 * 8 + 3) * 4..(4 * 8 + 3) * 4 + 3];

        let [_, s_before, _] = rgb_to_hsl([
            fringe_before[0] as f32 / 255.0,
            fringe_before[1] as f32 / 255.0,
            fringe_before[2] as f32 / 255.0,
        ]);
        let [_, s_after, _] = rgb_to_hsl([
            fringe_after[0] as f32 / 255.0,
            fringe_after[1] as f32 / 255.0,
            fringe_after[2] as f32 / 255.0,
        ]);

        assert!(
            s_after < s_before * 0.5,
            "defringe should reduce green saturation: before={s_before}, after={s_after}"
        );
    }

    #[test]
    fn lateral_ca_correction_leaves_center_pixel_unchanged() {
        let (w, h) = (33, 33);
        let mut src = vec![120u8; w * h * 4];
        let (cx, cy) = (16, 16);
        src[(cy * w + cx) * 4] = 250;
        src[(cy * w + cx) * 4 + 1] = 100;
        src[(cy * w + cx) * 4 + 2] = 50;

        let out = apply_lateral_ca(&src, w, h);
        let center_idx = (cy * w + cx) * 4;
        assert_eq!(out[center_idx], src[center_idx]);
        assert_eq!(out[center_idx + 1], src[center_idx + 1]);
        assert_eq!(out[center_idx + 2], src[center_idx + 2]);
    }

    #[test]
    fn lens_profile_neutral_is_noop() {
        let src = vec![128u8; 16 * 16 * 4];
        let out = apply_lens_profile(&src, 16, 16, 0.0, 0.0);
        assert_eq!(out, src);
    }

    #[test]
    fn lens_profile_vignette_brightens_corners_not_center() {
        let (w, h) = (33, 33);
        let src = vec![100u8; w * h * 4];
        let out = apply_lens_profile(&src, w, h, 0.0, 1.0);

        let (cx, cy) = (16, 16);
        let center_idx = (cy * w + cx) * 4;
        let corner_idx = 0; // (0, 0)

        // Center gain is 1.0, pixel should remain 100
        assert_eq!(out[center_idx], 100);
        assert_eq!(out[center_idx + 1], 100);
        assert_eq!(out[center_idx + 2], 100);

        // Corner gain > 1.0, pixel should be brightened
        assert!(
            out[corner_idx] > 100,
            "Corner should be brightened: got {}",
            out[corner_idx]
        );
    }

    #[test]
    fn lens_profile_distortion_leaves_center_unchanged() {
        let (w, h) = (33, 33);
        let mut src = vec![120u8; w * h * 4];
        let (cx, cy) = (16, 16);
        src[(cy * w + cx) * 4] = 200;
        src[(cy * w + cx) * 4 + 1] = 150;
        src[(cy * w + cx) * 4 + 2] = 80;

        let out = apply_lens_profile(&src, w, h, 1.0, 0.0);
        let center_idx = (cy * w + cx) * 4;
        assert_eq!(out[center_idx], 200);
        assert_eq!(out[center_idx + 1], 150);
        assert_eq!(out[center_idx + 2], 80);
    }
}
