//! Color science core + 3D LUT baking (P2 Slice D spike).
//!
//! Pipeline order (ARCHITECTURE §8):
//!   sRGB decode → **linear** → exposure (multiplicative, ×2^EV) → encode sRGB
//!   → contrast (S-curve) → saturation → clamp.
//!
//! Tone (exposure) is applied in **linear** light (the "Secret 2" rule); tone
//! shape and colour are applied perceptually. White balance (Von Kries),
//! vibrance, curves and the shadows/highlights edge-aware split land with their
//! parameters in the full Slice D — this spike validates the *mechanism*: bake a
//! 3D LUT on the CPU, pack it into a 2D atlas, and reproduce the same result by
//! trilinear lookup.

/// The 3D LUT edge length (33³ = 35,937 entries).
pub const LUT_SIZE: u32 = 33;

/// sRGB EOTF: encoded `[0,1]` → linear `[0,1]`.
pub fn srgb_to_linear(c: f32) -> f32 {
    if c <= 0.04045 {
        c / 12.92
    } else {
        ((c + 0.055) / 1.055).powf(2.4)
    }
}

/// sRGB OETF: linear `[0,1]` → encoded `[0,1]`.
pub fn linear_to_srgb(c: f32) -> f32 {
    if c <= 0.0031308 {
        c * 12.92
    } else {
        1.055 * c.powf(1.0 / 2.4) - 0.055
    }
}

/// Smooth contrast around mid-grey. `contrast` ∈ [-1,1]; 0 is identity.
///
/// Positive contrast blends toward a smoothstep S-curve; negative blends toward
/// its exact inverse. (Slice D will re-pivot this at 0.18 linear per the spec.)
fn contrast_curve(x: f32, contrast: f32) -> f32 {
    let x = x.clamp(0.0, 1.0);
    let s = x * x * (3.0 - 2.0 * x); // smoothstep, S centred at 0.5
    if contrast >= 0.0 {
        x + (s - x) * contrast
    } else {
        let inv = 0.5 - ((1.0 - 2.0 * x).clamp(-1.0, 1.0)).asin() / 3.0;
        x + (inv - x) * (-contrast)
    }
}

/// Applies the colour pipeline to one sRGB-encoded pixel, returning sRGB.
pub fn grade_pixel_srgb(
    r: f32,
    g: f32,
    b: f32,
    exposure: f32,
    contrast: f32,
    saturation: f32,
) -> [f32; 3] {
    // 1. decode to linear, 2. exposure in linear (multiplicative).
    let ev = 2f32.powf(exposure);
    let mut c = [
        linear_to_srgb((srgb_to_linear(r) * ev).max(0.0)),
        linear_to_srgb((srgb_to_linear(g) * ev).max(0.0)),
        linear_to_srgb((srgb_to_linear(b) * ev).max(0.0)),
    ];

    // 3. contrast S-curve (perceptual).
    for v in &mut c {
        *v = contrast_curve(*v, contrast);
    }

    // 4. saturation toward luma.
    let luma = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
    for v in &mut c {
        *v = luma + (*v - luma) * (1.0 + saturation);
    }

    [
        c[0].clamp(0.0, 1.0),
        c[1].clamp(0.0, 1.0),
        c[2].clamp(0.0, 1.0),
    ]
}

/// Bakes the colour pipeline into a 3D LUT packed as a 2D RGBA8 atlas.
///
/// **Atlas layout** (matches `shaders/lut.frag`):
///   width  = `size * size`
///   height = `size`
///   the blue slice `b ∈ [0,size)` occupies columns `[b*size, b*size+size)`;
///   within a slice, `x = red index`, `y = green index`.
pub fn bake_lut3d(size: u32, exposure: f32, contrast: f32, saturation: f32) -> Vec<u8> {
    let n = size as usize;
    let (w, h) = (n * n, n);
    let inv = 1.0 / (n - 1) as f32;
    let mut rgba = vec![0u8; w * h * 4];

    for bi in 0..n {
        for gi in 0..n {
            for ri in 0..n {
                let out = grade_pixel_srgb(
                    ri as f32 * inv,
                    gi as f32 * inv,
                    bi as f32 * inv,
                    exposure,
                    contrast,
                    saturation,
                );
                let x = bi * n + ri;
                let idx = (gi * w + x) * 4;
                rgba[idx] = (out[0] * 255.0 + 0.5) as u8;
                rgba[idx + 1] = (out[1] * 255.0 + 0.5) as u8;
                rgba[idx + 2] = (out[2] * 255.0 + 0.5) as u8;
                rgba[idx + 3] = 255;
            }
        }
    }
    rgba
}

/// Trilinear lookup into a `bake_lut3d` atlas — the CPU twin of `lut.frag`.
pub fn sample_lut(atlas: &[u8], size: u32, r: f32, g: f32, b: f32) -> [f32; 3] {
    let n = size as usize;
    let w = n * n;
    let texel = |ri: usize, gi: usize, bi: usize| -> [f32; 3] {
        let idx = (gi * w + (bi * n + ri)) * 4;
        [
            atlas[idx] as f32 / 255.0,
            atlas[idx + 1] as f32 / 255.0,
            atlas[idx + 2] as f32 / 255.0,
        ]
    };

    let s = [r.clamp(0.0, 1.0), g.clamp(0.0, 1.0), b.clamp(0.0, 1.0)];
    let last = (n - 1) as f32;
    let sf = [s[0] * last, s[1] * last, s[2] * last];

    let b0 = sf[2].floor();
    let b1 = (b0 + 1.0).min(last);
    let fb = sf[2] - b0;

    let slice = |bi: f32| -> [f32; 3] {
        let bi = bi as usize;
        let x0 = sf[0].floor();
        let x1 = (x0 + 1.0).min(last);
        let y0 = sf[1].floor();
        let y1 = (y0 + 1.0).min(last);
        let fx = sf[0] - x0;
        let fy = sf[1] - y0;

        let lerp = |a: [f32; 3], b: [f32; 3], t: f32| {
            [
                a[0] + (b[0] - a[0]) * t,
                a[1] + (b[1] - a[1]) * t,
                a[2] + (b[2] - a[2]) * t,
            ]
        };
        let c00 = texel(x0 as usize, y0 as usize, bi);
        let c10 = texel(x1 as usize, y0 as usize, bi);
        let c01 = texel(x0 as usize, y1 as usize, bi);
        let c11 = texel(x1 as usize, y1 as usize, bi);
        lerp(lerp(c00, c10, fx), lerp(c01, c11, fx), fy)
    };

    let lo = slice(b0);
    let hi = slice(b1);
    [
        lo[0] + (hi[0] - lo[0]) * fb,
        lo[1] + (hi[1] - lo[1]) * fb,
        lo[2] + (hi[2] - lo[2]) * fb,
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn atlas_dimensions_are_packed_as_documented() {
        let size = 8;
        let rgba = bake_lut3d(size, 0.0, 0.0, 0.0);
        assert_eq!(rgba.len(), (size * size * size * 4) as usize);
    }

    #[test]
    fn srgb_round_trips() {
        for i in 0..=255 {
            let c = i as f32 / 255.0;
            let back = linear_to_srgb(srgb_to_linear(c));
            assert!((back - c).abs() < 1e-5, "{c} -> {back}");
        }
    }

    #[test]
    fn identity_lut_looks_like_its_input() {
        let atlas = bake_lut3d(LUT_SIZE, 0.0, 0.0, 0.0);
        for &(r, g, b) in &[
            (0.0, 0.0, 0.0),
            (0.5, 0.5, 0.5),
            (1.0, 1.0, 1.0),
            (0.2, 0.7, 0.4),
        ] {
            let out = sample_lut(&atlas, LUT_SIZE, r, g, b);
            // Only lattice quantisation error should remain.
            assert!((out[0] - r).abs() < 2.0 / 255.0, "{:?}", (out, r, g, b));
            assert!((out[1] - g).abs() < 2.0 / 255.0);
            assert!((out[2] - b).abs() < 2.0 / 255.0);
        }
    }

    #[test]
    fn trilinear_lut_matches_the_direct_pipeline() {
        let (e, c, s) = (0.8, 0.35, 0.3);
        let atlas = bake_lut3d(LUT_SIZE, e, c, s);
        let mut worst = 0.0f32;
        for ri in 0..16 {
            for gi in 0..16 {
                for bi in 0..16 {
                    // Off-lattice sample points.
                    let r = (ri as f32 + 0.37) / 16.0;
                    let g = (gi as f32 + 0.11) / 16.0;
                    let b = (bi as f32 + 0.63) / 16.0;
                    let direct = grade_pixel_srgb(r, g, b, e, c, s);
                    let via = sample_lut(&atlas, LUT_SIZE, r, g, b);
                    for k in 0..3 {
                        worst = worst.max((direct[k] - via[k]).abs());
                    }
                }
            }
        }
        // A 33³ grid trilinearly reproduces this smooth pipeline closely.
        assert!(worst < 0.02, "worst LUT error {worst}");
    }

    #[test]
    fn exposure_is_monotonic_and_brightens() {
        let neutral = grade_pixel_srgb(0.4, 0.4, 0.4, 0.0, 0.0, 0.0)[0];
        let up = grade_pixel_srgb(0.4, 0.4, 0.4, 1.0, 0.0, 0.0)[0];
        let down = grade_pixel_srgb(0.4, 0.4, 0.4, -1.0, 0.0, 0.0)[0];
        assert!(up > neutral && down < neutral);
    }

    #[test]
    fn saturation_on_grey_is_a_no_op() {
        let out = grade_pixel_srgb(0.5, 0.5, 0.5, 0.0, 0.0, 1.0);
        assert!((out[0] - out[1]).abs() < 1e-4 && (out[1] - out[2]).abs() < 1e-4);
        assert!((out[0] - 0.5).abs() < 1e-3);
    }
}
