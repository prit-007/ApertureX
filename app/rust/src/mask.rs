//! Masking & local adjustments (P2.5). One model behind Lightroom "local
//! adjustments" and Snapseed "Stack": an adjustment layer = a mask + a
//! point-wise sub-grade, composited over the base. Masks are analytic
//! (linear / radial / luminance) so they stay small + non-destructive.

use crate::color::{grade_pointwise, GradeParams};

/// Mask kinds.
pub const MASK_LINEAR: u32 = 0;
pub const MASK_RADIAL: u32 = 1;
pub const MASK_LUMINANCE: u32 = 2;

/// A parametric mask.
pub struct MaskSpec {
    pub kind: u32,
    /// linear `[x0,y0,x1,y1]`, radial `[cx,cy,rx,ry]`, luminance `[lo,hi]`.
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

/// Mask coverage in `[0,1]` at normalised `(u,v)` (0..1) with luminance [luma].
pub fn coverage(kind: u32, p: &[f32], u: f32, v: f32, luma: f32) -> f32 {
    match kind {
        MASK_RADIAL => {
            let (cx, cy) = (p[0], p[1]);
            let (rx, ry) = (p[2].max(1e-3), p[3].max(1e-3));
            let feather = p.get(4).copied().unwrap_or(0.3).clamp(1e-3, 1.0);
            let d = (((u - cx) / rx).powi(2) + ((v - cy) / ry).powi(2)).sqrt();
            1.0 - smoothstep(1.0 - feather, 1.0, d)
        }
        MASK_LUMINANCE => {
            // Selects dark tones: coverage 1 below `lo`, fading to 0 at `hi`.
            let (lo, hi) = (p[0], p[1]);
            1.0 - smoothstep(lo, hi, luma)
        }
        // MASK_LINEAR: gradient from (x0,y0) to (x1,y1).
        _ => {
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
    for layer in layers {
        for i in 0..w * h {
            let u = ((i % w) as f32 + 0.5) / w as f32;
            let v = ((i / w) as f32 + 0.5) / h as f32;
            let base = [
                out[i * 4] as f32 / 255.0,
                out[i * 4 + 1] as f32 / 255.0,
                out[i * 4 + 2] as f32 / 255.0,
            ];
            let luma = 0.2126 * base[0] + 0.7152 * base[1] + 0.0722 * base[2];
            let cov = coverage(layer.mask.kind, &layer.mask.params, u, v, luma);
            if cov <= 0.0 {
                continue;
            }
            let adjusted = grade_pointwise(base, layer.params);
            for c in 0..3 {
                let mixed = base[c] + (adjusted[c] - base[c]) * cov;
                out[i * 4 + c] = (mixed * 255.0 + 0.5).clamp(0.0, 255.0) as u8;
            }
        }
    }
    out
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
}
