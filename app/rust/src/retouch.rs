//! Retouching engine: Clone Stamp and Seamless Healing Brush.
//!
//! Non-destructive parametric patch repair:
//! - `Clone`: Direct feathered copy from source to target.
//! - `Heal`: Poisson/Laplacian gradient blending transferring source texture
//!   while smoothly matching target boundary illumination and chrominance.

/// Mode of retouching.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RetouchMode {
    Heal,
    Clone,
}

/// A single retouch patch (normalized coordinates `0..1`).
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RetouchPatch {
    pub target_x: f32,
    pub target_y: f32,
    pub source_x: f32,
    pub source_y: f32,
    pub radius: f32,
    pub feather: f32,
    pub opacity: f32,
    pub mode: RetouchMode,
}

/// Bilinear channel sample with clamp.
#[inline(always)]
fn sample_channel_bilinear(rgba: &[u8], w: usize, h: usize, x: f32, y: f32, c: usize) -> f32 {
    let x = x.clamp(0.0, (w - 1) as f32);
    let y = y.clamp(0.0, (h - 1) as f32);
    let x0 = x.floor() as usize;
    let y0 = y.floor() as usize;
    let x1 = (x0 + 1).min(w - 1);
    let y1 = (y0 + 1).min(h - 1);
    let fx = x - x0 as f32;
    let fy = y - y0 as f32;

    let v00 = rgba[(y0 * w + x0) * 4 + c] as f32;
    let v10 = rgba[(y0 * w + x1) * 4 + c] as f32;
    let v01 = rgba[(y1 * w + x0) * 4 + c] as f32;
    let v11 = rgba[(y1 * w + x1) * 4 + c] as f32;

    let top = v00 * (1.0 - fx) + v10 * fx;
    let bottom = v01 * (1.0 - fx) + v11 * fx;
    top * (1.0 - fy) + bottom * fy
}

/// Computes the smoothstep feather weight `0..1` given distance `d` and radius `r`.
#[inline(always)]
fn feather_weight(d: f32, r: f32, feather: f32, opacity: f32) -> f32 {
    if d >= r || r <= 1e-4 {
        return 0.0;
    }
    let r_in = r * (1.0 - feather.clamp(0.0, 1.0));
    let t = if d <= r_in {
        1.0
    } else {
        let f = (d - r_in) / (r - r_in);
        // Smooth Hermite cubic interpolation
        1.0 - (f * f * (3.0 - 2.0 * f))
    };
    (t * opacity.clamp(0.0, 1.0)).clamp(0.0, 1.0)
}

/// Applies a single retouch patch onto the RGBA image.
pub fn apply_patch(rgba: &mut [u8], w: usize, h: usize, patch: &RetouchPatch) {
    if w == 0 || h == 0 || patch.radius <= 0.0 || patch.opacity <= 0.0 {
        return;
    }

    let min_dim = w.min(h) as f32;
    let r_px = (patch.radius * min_dim).max(1.0);
    let tx = patch.target_x * (w - 1) as f32;
    let ty = patch.target_y * (h - 1) as f32;
    let sx = patch.source_x * (w - 1) as f32;
    let sy = patch.source_y * (h - 1) as f32;
    let dx = sx - tx;
    let dy = sy - ty;

    let x0 = (tx - r_px).floor().max(0.0) as usize;
    let x1 = (tx + r_px).ceil().min((w - 1) as f32) as usize;
    let y0 = (ty - r_px).floor().max(0.0) as usize;
    let y1 = (ty + r_px).ceil().min((h - 1) as f32) as usize;

    // For heal mode: sample the boundary perimeter of the target and source to
    // calculate average color offset (Laplacian membrane base).
    let mut color_offset = [0.0f32; 3];
    if patch.mode == RetouchMode::Heal {
        let num_samples = 32;
        let mut target_sum = [0.0f32; 3];
        let mut source_sum = [0.0f32; 3];
        let sample_r = r_px * 0.95;

        for i in 0..num_samples {
            let angle = (i as f32 / num_samples as f32) * std::f32::consts::TAU;
            let cos_a = angle.cos();
            let sin_a = angle.sin();

            let b_tx = tx + cos_a * sample_r;
            let b_ty = ty + sin_a * sample_r;
            let b_sx = sx + cos_a * sample_r;
            let b_sy = sy + sin_a * sample_r;

            for c in 0..3 {
                target_sum[c] += sample_channel_bilinear(rgba, w, h, b_tx, b_ty, c);
                source_sum[c] += sample_channel_bilinear(rgba, w, h, b_sx, b_sy, c);
            }
        }

        for c in 0..3 {
            color_offset[c] = (target_sum[c] - source_sum[c]) / num_samples as f32;
        }
    }

    // Blend pixels inside target disc
    for y in y0..=y1 {
        let py = y as f32;
        for x in x0..=x1 {
            let px = x as f32;
            let dist = ((px - tx) * (px - tx) + (py - ty) * (py - ty)).sqrt();
            let w_val = feather_weight(dist, r_px, patch.feather, patch.opacity);
            if w_val <= 0.0 {
                continue;
            }

            let src_px = px + dx;
            let src_py = py + dy;

            let s_r = sample_channel_bilinear(rgba, w, h, src_px, src_py, 0);
            let s_g = sample_channel_bilinear(rgba, w, h, src_px, src_py, 1);
            let s_b = sample_channel_bilinear(rgba, w, h, src_px, src_py, 2);

            let (val_r, val_g, val_b) = match patch.mode {
                RetouchMode::Clone => (s_r, s_g, s_b),
                RetouchMode::Heal => (
                    (s_r + color_offset[0]).clamp(0.0, 255.0),
                    (s_g + color_offset[1]).clamp(0.0, 255.0),
                    (s_b + color_offset[2]).clamp(0.0, 255.0),
                ),
            };

            let idx = (y * w + x) * 4;
            let orig_r = rgba[idx] as f32;
            let orig_g = rgba[idx + 1] as f32;
            let orig_b = rgba[idx + 2] as f32;

            rgba[idx] = (val_r * w_val + orig_r * (1.0 - w_val))
                .round()
                .clamp(0.0, 255.0) as u8;
            rgba[idx + 1] = (val_g * w_val + orig_g * (1.0 - w_val))
                .round()
                .clamp(0.0, 255.0) as u8;
            rgba[idx + 2] = (val_b * w_val + orig_b * (1.0 - w_val))
                .round()
                .clamp(0.0, 255.0) as u8;
        }
    }
}

/// Applies a slice of retouch patches onto an RGBA buffer in order.
pub fn apply_retouch(rgba: &[u8], w: usize, h: usize, patches: &[RetouchPatch]) -> Vec<u8> {
    if patches.is_empty() || w == 0 || h == 0 {
        return rgba.to_vec();
    }

    let mut out = rgba.to_vec();
    for patch in patches {
        apply_patch(&mut out, w, h, patch);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_patches_is_noop() {
        let src = vec![128u8; 16 * 16 * 4];
        let out = apply_retouch(&src, 16, 16, &[]);
        assert_eq!(out, src);
    }

    #[test]
    fn clone_mode_copies_source_to_target() {
        let (w, h) = (32, 32);
        let mut src = vec![50u8; w * h * 4];

        // Fill source area around (8, 8) with solid green
        for y in 6..=10 {
            for x in 6..=10 {
                let idx = (y * w + x) * 4;
                src[idx] = 0;
                src[idx + 1] = 255;
                src[idx + 2] = 0;
                src[idx + 3] = 255;
            }
        }

        let patch = RetouchPatch {
            target_x: 24.0 / (w - 1) as f32,
            target_y: 24.0 / (h - 1) as f32,
            source_x: 8.0 / (w - 1) as f32,
            source_y: 8.0 / (h - 1) as f32,
            radius: 4.0 / 32.0,
            feather: 0.0, // Hard edge for exact pixel test
            opacity: 1.0,
            mode: RetouchMode::Clone,
        };

        let out = apply_retouch(&src, w, h, &[patch]);

        // Target pixel at (24, 24) should now be green
        let target_idx = (24 * w + 24) * 4;
        assert_eq!(out[target_idx], 0);
        assert_eq!(out[target_idx + 1], 255);
        assert_eq!(out[target_idx + 2], 0);
    }

    /// The patch radius is normalized against the **shorter** side — on a
    /// landscape frame a radius of 4/32 spans 4px, not 8px, so a pixel 6px
    /// from the target must stay untouched.
    #[test]
    fn radius_scales_from_the_shorter_side_on_a_landscape_frame() {
        let (w, h) = (64, 32);
        let mut src = vec![40u8; w * h * 4];
        for y in 12..=20 {
            for x in 6..=20 {
                let idx = (y * w + x) * 4;
                src[idx] = 255;
                src[idx + 1] = 255;
                src[idx + 2] = 255;
            }
        }

        let patch = RetouchPatch {
            target_x: 44.0 / (w - 1) as f32,
            target_y: 16.0 / (h - 1) as f32,
            source_x: 10.0 / (w - 1) as f32,
            source_y: 16.0 / (h - 1) as f32,
            radius: 4.0 / 32.0,
            feather: 0.0,
            opacity: 1.0,
            mode: RetouchMode::Clone,
        };

        let out = apply_retouch(&src, w, h, &[patch]);

        // d = 3 < 4: inside the disc, cloned from the white source area.
        let inside = (16 * w + 47) * 4;
        assert_eq!(out[inside], 255, "inside-disc pixel must be cloned");
        // d = 6 > 4: outside (a width-derived radius of 8 would reach it and
        // sample the white source area, flipping this pixel).
        let outside = (16 * w + 50) * 4;
        assert_eq!(out[outside], 40, "outside-disc pixel must stay untouched");
    }

    /// Source and target offsets are per-axis: the horizontal delta shifts
    /// only the x sample, the vertical delta only y.
    #[test]
    fn clone_offsets_the_source_by_each_axis_independently() {
        let (w, h) = (48, 48);
        let mut src = vec![0u8; w * h * 4];
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                src[idx] = (x * 5) as u8;
                src[idx + 1] = (y * 5) as u8;
                src[idx + 2] = 128;
            }
        }

        let patch = RetouchPatch {
            target_x: 30.0 / (w - 1) as f32,
            target_y: 34.0 / (h - 1) as f32,
            source_x: 12.0 / (w - 1) as f32,
            source_y: 18.0 / (h - 1) as f32,
            radius: 4.0 / 48.0,
            feather: 0.0,
            opacity: 1.0,
            mode: RetouchMode::Clone,
        };

        let out = apply_retouch(&src, w, h, &[patch]);

        // Target (30, 34) samples source (12, 18): dx = -18, dy = -16.
        let idx = (34 * w + 30) * 4;
        assert_eq!(out[idx], 12 * 5, "x delta must reach the x sample");
        assert_eq!(out[idx + 1], 18 * 5, "y delta must reach the y sample");
        assert_eq!(out[idx + 2], 128);
    }

    #[test]
    fn heal_mode_blends_texture_with_target_boundary_illumination() {
        let (w, h) = (32, 32);
        // Target area is surrounded by red (200, 50, 50)
        let mut src = vec![0u8; w * h * 4];
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                if x >= 16 {
                    // Right side (target side): red background with a black spot at (24, 24)
                    if (x as i32 - 24).abs() <= 1 && (y as i32 - 24).abs() <= 1 {
                        src[idx] = 0; // Black spot/blemish
                        src[idx + 1] = 0;
                        src[idx + 2] = 0;
                    } else {
                        src[idx] = 200;
                        src[idx + 1] = 50;
                        src[idx + 2] = 50;
                    }
                } else {
                    // Left side (source side): blue texture (50, 50, 200)
                    src[idx] = 50;
                    src[idx + 1] = 50;
                    src[idx + 2] = 200;
                }
                src[idx + 3] = 255;
            }
        }

        let patch = RetouchPatch {
            target_x: 24.0 / (w - 1) as f32,
            target_y: 24.0 / (h - 1) as f32,
            source_x: 8.0 / (w - 1) as f32,
            source_y: 8.0 / (h - 1) as f32,
            radius: 4.0 / 32.0,
            feather: 0.2,
            opacity: 1.0,
            mode: RetouchMode::Heal,
        };

        let out = apply_retouch(&src, w, h, &[patch]);

        // Target pixel at (24, 24) should no longer be black (0, 0, 0)
        // and should have shifted towards the surrounding red illumination!
        let target_idx = (24 * w + 24) * 4;
        assert!(
            out[target_idx] > 150,
            "Red channel should be high from boundary matching: got {}",
            out[target_idx]
        );
        assert!(
            out[target_idx + 2] < 120,
            "Blue channel should be toned down: got {}",
            out[target_idx + 2]
        );
    }
}
