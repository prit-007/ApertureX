//! Masking & local adjustments (P2.5). One model behind Lightroom "local
//! adjustments" and Snapseed "Stack": an adjustment layer = a mask + a
//! point-wise sub-grade, composited over the base. Masks are analytic
//! (linear / radial / luminance) so they stay small + non-destructive.

use crate::color::{grade_pointwise, GradeParams};

/// Mask kinds.
pub const MASK_LINEAR: u32 = 0;
pub const MASK_RADIAL: u32 = 1;
pub const MASK_LUMINANCE: u32 = 2;
pub const MASK_BRUSH: u32 = 3;
pub const MASK_SUBJECT: u32 = 4;
pub const MASK_SKY: u32 = 5;

/// A parametric mask.
pub struct MaskSpec {
    pub kind: u32,
    /// linear `[x0,y0,x1,y1]`, radial `[cx,cy,rx,ry]`, luminance `[lo,hi]`,
    /// brush `[radius, feather, count, x0, y0, p0, ...]`,
    /// subject `[cx, cy, rx, ry, feather]`,
    /// sky `[horizon_y, feather, blue_weight]`.
    pub params: Vec<f32>,
}

/// A stack entry: where ([`MaskSpec`]) and what ([`GradeParams`]) to adjust.
pub struct LocalAdjustment {
    pub mask: MaskSpec,
    pub params: GradeParams,
}

fn smoothstep(a: f32, b: f32, x: f32) -> f32 {
    if (b - a).abs() < 1e-6 {
        return if x >= b { 1.0 } else { 0.0 };
    }
    let t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}

/// Computes the distance from `(u, v)` to a line segment `(x0, y0) -> (x1, y1)`
/// along with the projected parameter `t in [0, 1]`.
pub fn dist_to_segment(u: f32, v: f32, x0: f32, y0: f32, x1: f32, y1: f32) -> (f32, f32) {
    let dx = x1 - x0;
    let dy = y1 - y0;
    let len2 = dx * dx + dy * dy;
    if len2 < 1e-7 {
        let dist = ((u - x0).powi(2) + (v - y0).powi(2)).sqrt();
        return (dist, 0.0);
    }
    let t = (((u - x0) * dx + (v - y0) * dy) / len2).clamp(0.0, 1.0);
    let px = x0 + t * dx;
    let py = y0 + t * dy;
    let dist = ((u - px).powi(2) + (v - py).powi(2)).sqrt();
    (dist, t)
}

/// Mask coverage in `[0,1]` at normalised `(u,v)` (0..1) with luminance [luma].
pub fn coverage(kind: u32, p: &[f32], u: f32, v: f32, luma: f32) -> f32 {
    coverage_rgb(kind, p, u, v, luma, [luma, luma, luma])
}

/// Mask coverage in `[0,1]` at normalised `(u,v)` (0..1) with luminance [luma]
/// and source color [rgb].
pub fn coverage_rgb(kind: u32, p: &[f32], u: f32, v: f32, luma: f32, rgb: [f32; 3]) -> f32 {
    match kind {
        MASK_RADIAL => {
            if p.len() < 4 {
                return 0.0;
            }
            let (cx, cy) = (p[0], p[1]);
            let (rx, ry) = (p[2].max(1e-3), p[3].max(1e-3));
            let feather = p.get(4).copied().unwrap_or(0.3).clamp(1e-3, 1.0);
            let d = (((u - cx) / rx).powi(2) + ((v - cy) / ry).powi(2)).sqrt();
            1.0 - smoothstep(1.0 - feather, 1.0, d)
        }
        MASK_LUMINANCE => {
            if p.len() < 2 {
                return 0.0;
            }
            // Selects dark tones: coverage 1 below `lo`, fading to 0 at `hi`.
            let (lo, hi) = (p[0], p[1]);
            1.0 - smoothstep(lo, hi, luma)
        }
        MASK_BRUSH => {
            // [radius, feather, count, x0, y0, p0, x1, y1, p1, ...]
            if p.len() < 3 {
                return 0.0;
            }
            let radius = p[0].max(1e-4);
            let feather = p[1].clamp(1e-3, 1.0);
            let count = p[2] as usize;
            if count == 0 || p.len() < 3 + count * 3 {
                return 0.0;
            }
            let points = &p[3..3 + count * 3];

            // Fast bounding box check
            let mut min_x = f32::MAX;
            let mut max_x = f32::MIN;
            let mut min_y = f32::MAX;
            let mut max_y = f32::MIN;
            for chunk in points.as_chunks::<3>().0 {
                min_x = min_x.min(chunk[0]);
                max_x = max_x.max(chunk[0]);
                min_y = min_y.min(chunk[1]);
                max_y = max_y.max(chunk[1]);
            }
            if u < min_x - radius || u > max_x + radius || v < min_y - radius || v > max_y + radius
            {
                return 0.0;
            }

            let mut max_cov = 0.0f32;
            if count == 1 {
                let (px, py, pr) = (points[0], points[1], points[2].clamp(0.0, 1.0));
                let dist = ((u - px).powi(2) + (v - py).powi(2)).sqrt();
                let eff_r = radius * pr.max(0.1);
                if dist < eff_r {
                    max_cov = (1.0 - smoothstep(eff_r * (1.0 - feather), eff_r, dist)) * pr;
                }
            } else {
                for i in 0..count - 1 {
                    let (x0, y0, pr0) = (
                        points[i * 3],
                        points[i * 3 + 1],
                        points[i * 3 + 2].clamp(0.0, 1.0),
                    );
                    let (x1, y1, pr1) = (
                        points[(i + 1) * 3],
                        points[(i + 1) * 3 + 1],
                        points[(i + 1) * 3 + 2].clamp(0.0, 1.0),
                    );
                    let (dist, t) = dist_to_segment(u, v, x0, y0, x1, y1);
                    let pr = pr0 + t * (pr1 - pr0);
                    let eff_r = radius * pr.max(0.1);
                    if dist < eff_r {
                        let cov = (1.0 - smoothstep(eff_r * (1.0 - feather), eff_r, dist)) * pr;
                        max_cov = max_cov.max(cov);
                    }
                }
            }
            max_cov
        }
        MASK_SUBJECT => {
            // [cx, cy, rx, ry, feather]
            let cx = p.first().copied().unwrap_or(0.5);
            let cy = p.get(1).copied().unwrap_or(0.5);
            let rx = p.get(2).copied().unwrap_or(0.28).max(1e-3);
            let ry = p.get(3).copied().unwrap_or(0.38).max(1e-3);
            let feather = p.get(4).copied().unwrap_or(0.3).clamp(1e-3, 1.0);
            let d = (((u - cx) / rx).powi(2) + ((v - cy) / ry).powi(2)).sqrt();
            1.0 - smoothstep(1.0 - feather, 1.0, d)
        }
        MASK_SKY => {
            // [horizon_y, feather, blue_weight]
            let horizon = p.first().copied().unwrap_or(0.55);
            let feather = p.get(1).copied().unwrap_or(0.2).clamp(1e-3, 1.0);
            let blue_weight = p.get(2).copied().unwrap_or(0.5).clamp(0.0, 1.0);
            let v_cov = 1.0 - smoothstep(horizon - feather, horizon + feather, v);
            if v_cov <= 1e-4 {
                return 0.0;
            }
            // Sky chromaticity prior: blue dominance or bright cloud
            let is_blue_sky = rgb[2] > rgb[0] * 0.85 && luma > 0.2;
            let is_cloud = luma > 0.65 && (rgb[0] - rgb[2]).abs() < 0.25;
            let color_score = if is_blue_sky || is_cloud { 1.0 } else { 0.35 };
            v_cov * (1.0 - blue_weight + blue_weight * color_score)
        }
        // MASK_LINEAR: gradient from (x0,y0) to (x1,y1).
        _ => {
            if p.len() < 4 {
                return 0.0;
            }
            let (x0, y0, x1, y1) = (p[0], p[1], p[2], p[3]);
            let (dx, dy) = (x1 - x0, y1 - y0);
            let len2 = dx * dx + dy * dy;
            let t = if len2 < 1e-6 {
                0.0
            } else {
                ((u - x0) * dx + (v - y0) * dy) / len2
            };
            smoothstep(0.0, 1.0, t)
        }
    }
}

/// Composites every layer over [rgba] (RGBA8, `w*h*4`), in order.
pub fn apply_local(rgba: &[u8], w: usize, h: usize, layers: &[LocalAdjustment]) -> Vec<u8> {
    let mut out = rgba.to_vec();
    if layers.is_empty() || w == 0 || h == 0 {
        return out;
    }
    apply_local_rows(&mut out, w, 0, 0, w, h, layers);
    out
}

/// Composites every layer over a **band** of rows `y0..y0+bh` (RGBA8,
/// `w*bh*4`), where `full_h` is the full image height.
///
/// Masks are analytic and per-pixel (no neighbourhood), so a band needs no
/// halo: the only tile-awareness is that `u,v` are normalised against the
/// **full** image, which is what makes bands stitch seamlessly.
pub fn apply_local_band(
    band: &[u8],
    w: usize,
    full_h: usize,
    y0: usize,
    layers: &[LocalAdjustment],
) -> Vec<u8> {
    let mut out = band.to_vec();
    if layers.is_empty() || w == 0 || full_h == 0 {
        return out;
    }
    apply_local_rows(&mut out, w, 0, y0, w, full_h, layers);
    out
}

/// Composites every layer over a **rect (tile)** whose top-left pixel sits at
/// `(x0, y0)` of the `full_w x full_h` image (RGBA8, `tw*th*4`, [tw] per row).
///
/// Same seam-free argument as [`apply_local_band`]: `u,v` normalise against
/// the **full** image, so neighbouring tiles agree at their shared pixels.
pub fn apply_local_rect(
    band: &[u8],
    tw: usize,
    x0: usize,
    y0: usize,
    full_w: usize,
    full_h: usize,
    layers: &[LocalAdjustment],
) -> Vec<u8> {
    let mut out = band.to_vec();
    if layers.is_empty() || tw == 0 || full_w == 0 || full_h == 0 {
        return out;
    }
    apply_local_rows(&mut out, tw, x0, y0, full_w, full_h, layers);
    out
}

/// The shared per-pixel body of [`apply_local`] / [`apply_local_band`] /
/// [`apply_local_rect`]. `(x_origin, row_origin)` is the global position of
/// the buffer's first pixel (0,0 for the full image; tile/band offsets
/// otherwise), so normalised `u,v` always span the full frame.
fn apply_local_rows(
    buf: &mut [u8],
    buf_w: usize,
    x_origin: usize,
    row_origin: usize,
    full_w: usize,
    full_h: usize,
    layers: &[LocalAdjustment],
) {
    for layer in layers {
        for y in 0..buf.len() / (buf_w * 4).max(1) {
            let v = ((row_origin + y) as f32 + 0.5) / full_h as f32;
            for x in 0..buf_w {
                let i = (y * buf_w + x) * 4;
                let u = ((x_origin + x) as f32 + 0.5) / full_w as f32;
                let base = [
                    buf[i] as f32 / 255.0,
                    buf[i + 1] as f32 / 255.0,
                    buf[i + 2] as f32 / 255.0,
                ];
                let luma = 0.2126 * base[0] + 0.7152 * base[1] + 0.0722 * base[2];
                let cov = coverage(layer.mask.kind, &layer.mask.params, u, v, luma);
                if cov <= 0.0 {
                    continue;
                }
                let adjusted = grade_pointwise(base, layer.params);
                for c in 0..3 {
                    let mixed = base[c] + (adjusted[c] - base[c]) * cov;
                    buf[i + c] = (mixed * 255.0 + 0.5).clamp(0.0, 255.0) as u8;
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn grey(w: usize, h: usize, v: u8) -> Vec<u8> {
        let mut b = Vec::with_capacity(w * h * 4);
        for _ in 0..w * h {
            b.extend_from_slice(&[v, v, v, 255]);
        }
        b
    }

    fn brighten() -> GradeParams {
        GradeParams {
            exposure: 1.0,
            ..Default::default()
        }
    }

    #[test]
    fn empty_layers_is_identity() {
        let src = grey(8, 8, 100);
        assert_eq!(apply_local(&src, 8, 8, &[]), src);
    }

    #[test]
    fn radial_mask_brightens_the_centre_only() {
        let src = grey(32, 32, 100);
        let layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_RADIAL,
                params: vec![0.5, 0.5, 0.3, 0.3, 0.3],
            },
            params: brighten(),
        };
        let out = apply_local(&src, 32, 32, &[layer]);
        let centre = out[(16 * 32 + 16) * 4];
        let corner = out[0];
        assert!(centre > 120, "centre should brighten: {centre}");
        assert_eq!(corner, 100, "corner untouched");
    }

    #[test]
    fn linear_mask_brightens_one_side() {
        let src = grey(16, 16, 100);
        let layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_LINEAR,
                params: vec![0.0, 0.0, 0.0, 1.0],
            },
            params: brighten(),
        };
        let out = apply_local(&src, 16, 16, &[layer]);
        let top = out[(16 + 8) * 4];
        let bottom = out[(15 * 16 + 8) * 4];
        assert!(bottom > top, "gradient brightens downward: {top} {bottom}");
    }

    #[test]
    fn luminance_mask_targets_darks() {
        let mut img = grey(16, 8, 0);
        for y in 0..8 {
            for x in 0..16 {
                let v = if x < 8 { 40u8 } else { 220u8 };
                let i = (y * 16 + x) * 4;
                img[i] = v;
                img[i + 1] = v;
                img[i + 2] = v;
            }
        }
        let layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_LUMINANCE,
                params: vec![0.0, 0.5],
            },
            params: brighten(),
        };
        let out = apply_local(&img, 16, 8, &[layer]);
        let dark = out[(4 * 16 + 2) * 4];
        let bright = out[(4 * 16 + 13) * 4];
        assert!(dark > 48, "darks brightened: {dark}");
        assert!(bright.abs_diff(220) < 8, "brights ~untouched: {bright}");
    }

    /// A deterministic per-pixel ramp so mask coverage varies across the frame.
    fn ramp(w: usize, h: usize) -> Vec<u8> {
        let mut v = Vec::with_capacity(w * h * 4);
        for y in 0..h {
            for x in 0..w {
                let r = ((x * 13 + y * 5) % 256) as u8;
                let g = ((x * 7 + y * 29) % 256) as u8;
                let b = ((x * 3 + y * 11) % 256) as u8;
                v.extend_from_slice(&[r, g, b, 255]);
            }
        }
        v
    }

    /// A representative stack: one of each mask kind, with distinct sub-grades.
    fn stack() -> Vec<LocalAdjustment> {
        vec![
            LocalAdjustment {
                mask: MaskSpec {
                    kind: MASK_RADIAL,
                    params: vec![0.5, 0.5, 0.4, 0.35, 0.3],
                },
                params: brighten(),
            },
            LocalAdjustment {
                mask: MaskSpec {
                    kind: MASK_LINEAR,
                    params: vec![0.1, 0.1, 0.9, 0.8],
                },
                params: GradeParams {
                    saturation: 0.5,
                    ..Default::default()
                },
            },
            LocalAdjustment {
                mask: MaskSpec {
                    kind: MASK_LUMINANCE,
                    params: vec![0.3, 0.8],
                },
                params: GradeParams {
                    contrast: 0.4,
                    ..Default::default()
                },
            },
        ]
    }

    #[test]
    fn banded_masks_stitch_to_the_full_frame() {
        let (w, h) = (48, 40);
        let src = ramp(w, h);
        let layers = stack();
        let full = apply_local(&src, w, h, &layers);
        for band_rows in [1usize, 7, 13, 20, 40] {
            let mut stitched = Vec::with_capacity(w * h * 4);
            let mut y0 = 0;
            while y0 < h {
                let bh = band_rows.min(h - y0);
                let band: Vec<u8> = (y0..y0 + bh)
                    .flat_map(|y| src[y * w * 4..(y + 1) * w * 4].iter().copied())
                    .collect();
                stitched.extend_from_slice(&apply_local_band(&band, w, h, y0, &layers));
                y0 += bh;
            }
            assert_eq!(stitched, full, "band_rows={band_rows} diverged");
        }
    }

    #[test]
    fn band_without_layers_is_a_copy() {
        let band = ramp(8, 3);
        assert_eq!(
            apply_local_band(&band, 8, 32, 4, &[]),
            band,
            "empty layers must not touch pixels"
        );
    }

    #[test]
    fn brush_mask_brightens_along_stroke() {
        let src = grey(32, 32, 100);
        // Single horizontal stroke at y = 0.5 from x = 0.2 to x = 0.8
        let layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_BRUSH,
                params: vec![
                    0.15, // radius
                    0.2,  // feather
                    2.0,  // count
                    0.2, 0.5, 1.0, // p0
                    0.8, 0.5, 1.0, // p1
                ],
            },
            params: brighten(),
        };
        let out = apply_local(&src, 32, 32, &[layer]);
        let center = out[(16 * 32 + 16) * 4];
        let corner = out[0];
        assert!(center > 130, "center of stroke brightens: {center}");
        assert_eq!(corner, 100, "corner outside stroke is untouched");
    }

    #[test]
    fn subject_mask_brightens_center_figure() {
        let src = grey(32, 32, 100);
        let layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_SUBJECT,
                params: vec![0.5, 0.5, 0.25, 0.35, 0.2],
            },
            params: brighten(),
        };
        let out = apply_local(&src, 32, 32, &[layer]);
        let center = out[(16 * 32 + 16) * 4];
        let corner = out[0];
        assert!(center > 130, "subject center brightens: {center}");
        assert_eq!(corner, 100, "corner outside subject is untouched");
    }

    #[test]
    fn sky_mask_brightens_upper_frame() {
        // Image with upper half blue (sky) and lower half green (ground)
        let mut img = Vec::with_capacity(32 * 32 * 4);
        for y in 0..32 {
            for _ in 0..32 {
                if y < 16 {
                    img.extend_from_slice(&[80, 120, 200, 255]); // blue sky
                } else {
                    img.extend_from_slice(&[50, 140, 50, 255]); // ground
                }
            }
        }
        let layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_SKY,
                params: vec![0.5, 0.1, 0.6],
            },
            params: brighten(),
        };
        let out = apply_local(&img, 32, 32, &[layer]);
        let sky_pixel = out[(4 * 32 + 16) * 4 + 2]; // Blue channel in sky
        let ground_pixel = out[(28 * 32 + 16) * 4 + 1]; // Green channel in ground
        assert!(sky_pixel > 200, "sky pixel brightened: {sky_pixel}");
        assert_eq!(ground_pixel, 140, "ground pixel untouched: {ground_pixel}");
    }
}
