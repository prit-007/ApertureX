//! Color science core + 3D LUT baking (P2 Slice D).
//!
//! Pipeline order (ARCHITECTURE §8):
//!   sRGB decode → **linear** → white balance (Von Kries, Bradford) → exposure
//!   (multiplicative, ×2^EV) → encode sRGB → contrast (S-curve) → vibrance →
//!   saturation → clamp.
//!
//! Tone (exposure) is multiplicative in linear light; WB is a proper LMS Von
//! Kries transform; the S-curve/vibrance/saturation are perceptual. Spatial
//! operations (clarity, texture, edge-aware shadows/highlights, dehaze,
//! sharpening) are NOT point-wise and live in separate padded passes — they do
//! not belong in this per-pixel LUT.

/// The 3D LUT edge length (33³ = 35,937 entries).
pub const LUT_SIZE: u32 = 33;

/// The point-wise grade parameters (neutral at all-zero).
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct GradeParams {
    /// Exposure in EV (stops).
    pub exposure: f32,
    /// Contrast, unitless around 0.
    pub contrast: f32,
    /// Saturation, unitless around 0.
    pub saturation: f32,
    /// White-balance temperature, unitless around 0 (warm > 0).
    pub temperature: f32,
    /// White-balance tint, unitless around 0 (magenta > 0).
    pub tint: f32,
    /// Vibrance (protects already-saturated pixels), unitless around 0.
    pub vibrance: f32,
    /// Split-tone: hue (0..1) and strength (0..1) per tonal zone.
    pub grade_shadow_hue: f32,
    pub grade_shadow_sat: f32,
    pub grade_mid_hue: f32,
    pub grade_mid_sat: f32,
    pub grade_highlight_hue: f32,
    pub grade_highlight_sat: f32,
}

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

/// Bradford RGB→LMS cone-response matrix.
const BRADFORD: [[f32; 3]; 3] = [
    [0.8951, 0.2664, -0.1614],
    [-0.7502, 1.7135, 0.0367],
    [0.0389, -0.0685, 1.0296],
];

/// Inverse of [`BRADFORD`].
const BRADFORD_INV: [[f32; 3]; 3] = [
    [0.986_992_9, -0.147_054_3, 0.159_962_7],
    [0.432_305_3, 0.518_360_3, 0.049_291_2],
    [-0.008_528_7, 0.040_042_8, 0.968_486_7],
];

fn mul(m: &[[f32; 3]; 3], v: [f32; 3]) -> [f32; 3] {
    [
        m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
        m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
        m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2],
    ]
}

/// Von Kries white balance: scale the LMS cone responses, then back to RGB.
/// Temperature pushes warm (more L, less S); tint pushes magenta (less M).
fn white_balance(lin: [f32; 3], temperature: f32, tint: f32) -> [f32; 3] {
    if temperature == 0.0 && tint == 0.0 {
        return lin;
    }
    let lms = mul(&BRADFORD, lin);
    let gain = [
        (1.0 + 0.20 * temperature).max(0.0),
        (1.0 - 0.20 * tint).max(0.0),
        (1.0 - 0.30 * temperature).max(0.0),
    ];
    mul(
        &BRADFORD_INV,
        [lms[0] * gain[0], lms[1] * gain[1], lms[2] * gain[2]],
    )
}

/// Smooth contrast around mid-grey via a smoothstep S-curve. 0 is identity;
/// positive blends toward the S, negative toward its exact inverse.
fn contrast_curve(x: f32, contrast: f32) -> f32 {
    let x = x.clamp(0.0, 1.0);
    let s = x * x * (3.0 - 2.0 * x);
    if contrast >= 0.0 {
        x + (s - x) * contrast
    } else {
        let inv = 0.5 - ((1.0 - 2.0 * x).clamp(-1.0, 1.0)).asin() / 3.0;
        x + (inv - x) * (-contrast)
    }
}

/// Vibrance: boost saturation inversely to how saturated a pixel already is
/// (protects already-vivid colours), leaving the luma untouched.
fn vibrance(c: [f32; 3], amount: f32) -> [f32; 3] {
    if amount == 0.0 {
        return c;
    }
    let maxc = c[0].max(c[1]).max(c[2]);
    let minc = c[0].min(c[1]).min(c[2]);
    let sat = if maxc > 1e-6 {
        (maxc - minc) / maxc
    } else {
        0.0
    };
    let weight = (1.0 - sat).clamp(0.0, 1.0);
    let luma = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
    let f = 1.0 + amount * weight * 1.5;
    [
        luma + (c[0] - luma) * f,
        luma + (c[1] - luma) * f,
        luma + (c[2] - luma) * f,
    ]
}

/// Fully-saturated RGB for a hue in `[0,1)` (HSV with S=V=1).
fn hue_rgb(hue: f32) -> [f32; 3] {
    let h = hue.rem_euclid(1.0) * 6.0;
    let x = 1.0 - (h.rem_euclid(2.0) - 1.0).abs();
    match h as i32 {
        0 => [1.0, x, 0.0],
        1 => [x, 1.0, 0.0],
        2 => [0.0, 1.0, x],
        3 => [0.0, x, 1.0],
        4 => [x, 0.0, 1.0],
        _ => [1.0, 0.0, x],
    }
}

/// Split-tone color grading: shift each pixel toward the shadow/mid/highlight
/// hue weighted by where its luminance sits, adding a **luma-preserving** chroma
/// offset so tones separate without darkening or brightening (ARCHITECTURE §8).
fn color_grade(c: [f32; 3], p: GradeParams) -> [f32; 3] {
    let luma = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
    let shadow_w = (1.0 - luma * 2.0).clamp(0.0, 1.0);
    let highlight_w = ((luma - 0.5) * 2.0).clamp(0.0, 1.0);
    let mid_w = (1.0 - shadow_w - highlight_w).clamp(0.0, 1.0);

    let mut out = c;
    for (hue, sat, weight) in [
        (p.grade_shadow_hue, p.grade_shadow_sat, shadow_w),
        (p.grade_mid_hue, p.grade_mid_sat, mid_w),
        (p.grade_highlight_hue, p.grade_highlight_sat, highlight_w),
    ] {
        let factor = sat * weight * 0.5;
        if factor <= 0.0 {
            continue;
        }
        let tint = hue_rgb(hue);
        let tint_luma = 0.2126 * tint[0] + 0.7152 * tint[1] + 0.0722 * tint[2];
        for (o, t) in out.iter_mut().zip(tint) {
            *o += (t - tint_luma) * factor;
        }
    }
    out
}

/// Applies the point-wise colour pipeline (identity curves) to one pixel.
pub fn grade_pixel_srgb(r: f32, g: f32, b: f32, p: GradeParams) -> [f32; 3] {
    grade_pixel_c(r, g, b, p, None)
}

/// Builds a 256-entry LUT from monotone-cubic control points.
///
/// `points` is flat `[x0,y0,x1,y1,...]` in `[0,1]²`, sorted by x. Fewer than two
/// points yields the identity. Fritsch–Carlson tangents keep it monotone (no
/// overshoot ringing).
pub fn curve_lut(points: &[f32]) -> [f32; 256] {
    let identity = || std::array::from_fn(|i| i as f32 / 255.0);
    let n = points.len() / 2;
    if n < 2 {
        return identity();
    }
    let xs: Vec<f32> = (0..n).map(|i| points[i * 2]).collect();
    let ys: Vec<f32> = (0..n).map(|i| points[i * 2 + 1]).collect();

    let mut d = vec![0f32; n - 1];
    for i in 0..n - 1 {
        d[i] = (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]).max(1e-6);
    }
    let mut m = vec![0f32; n];
    m[0] = d[0];
    m[n - 1] = d[n - 2];
    for i in 1..n - 1 {
        m[i] = (d[i - 1] + d[i]) / 2.0;
    }
    for i in 0..n - 1 {
        if d[i].abs() < 1e-6 {
            m[i] = 0.0;
            m[i + 1] = 0.0;
        } else {
            let a = m[i] / d[i];
            let b = m[i + 1] / d[i];
            let s = a * a + b * b;
            if s > 9.0 {
                let t = 3.0 / s.sqrt();
                m[i] = t * a * d[i];
                m[i + 1] = t * b * d[i];
            }
        }
    }

    std::array::from_fn(|k| {
        let x = k as f32 / 255.0;
        if x <= xs[0] {
            return ys[0].clamp(0.0, 1.0);
        }
        if x >= xs[n - 1] {
            return ys[n - 1].clamp(0.0, 1.0);
        }
        let mut i = 0;
        while i < n - 2 && x > xs[i + 1] {
            i += 1;
        }
        let h = xs[i + 1] - xs[i];
        let t = (x - xs[i]) / h;
        let (t2, t3) = (t * t, t * t * t);
        let h00 = 2.0 * t3 - 3.0 * t2 + 1.0;
        let h10 = t3 - 2.0 * t2 + t;
        let h01 = -2.0 * t3 + 3.0 * t2;
        let h11 = t3 - t2;
        (h00 * ys[i] + h10 * h * m[i] + h01 * ys[i + 1] + h11 * h * m[i + 1]).clamp(0.0, 1.0)
    })
}

/// Tone-curve LUTs: a master (RGB) curve plus per-channel curves.
pub struct CurveSet {
    pub master: [f32; 256],
    pub r: [f32; 256],
    pub g: [f32; 256],
    pub b: [f32; 256],
}

impl CurveSet {
    /// All-identity curves (applying it is a no-op).
    pub fn identity() -> Self {
        let id = curve_lut(&[]);
        Self {
            master: id,
            r: id,
            g: id,
            b: id,
        }
    }

    /// Builds the set from flat control-point lists (`[x0,y0,...]`).
    pub fn from_points(master: &[f32], r: &[f32], g: &[f32], b: &[f32]) -> Self {
        Self {
            master: curve_lut(master),
            r: curve_lut(r),
            g: curve_lut(g),
            b: curve_lut(b),
        }
    }
}

fn apply_curve(v: f32, lut: &[f32; 256]) -> f32 {
    let x = v.clamp(0.0, 1.0) * 255.0;
    let i = x.floor() as usize;
    let f = x - i as f32;
    let a = lut[i.min(255)];
    let b = lut[(i + 1).min(255)];
    a + (b - a) * f
}

/// Applies the point-wise colour pipeline to one sRGB-encoded pixel, optionally
/// finishing with tone curves (master then per-channel).
pub fn grade_pixel_c(
    r: f32,
    g: f32,
    b: f32,
    p: GradeParams,
    curves: Option<&CurveSet>,
) -> [f32; 3] {
    // 1. decode to linear.
    let lin = [srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b)];

    // 2. white balance (linear, Von Kries).
    let lin = white_balance(lin, p.temperature, p.tint);

    // 3. exposure (linear, multiplicative).
    let ev = 2f32.powf(p.exposure);
    let mut c = [
        linear_to_srgb((lin[0] * ev).max(0.0)),
        linear_to_srgb((lin[1] * ev).max(0.0)),
        linear_to_srgb((lin[2] * ev).max(0.0)),
    ];

    // 4. contrast S-curve (perceptual).
    for v in &mut c {
        *v = contrast_curve(*v, p.contrast);
    }

    // 5. vibrance, then saturation (perceptual).
    c = vibrance(c, p.vibrance);
    let luma = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
    for v in &mut c {
        *v = luma + (*v - luma) * (1.0 + p.saturation);
    }

    // 6. color grading (split tone, luma-weighted).
    c = color_grade(c, p);

    // 7. tone curves (master then per-channel), optional.
    if let Some(cs) = curves {
        c = [
            apply_curve(apply_curve(c[0], &cs.master), &cs.r),
            apply_curve(apply_curve(c[1], &cs.master), &cs.g),
            apply_curve(apply_curve(c[2], &cs.master), &cs.b),
        ];
    }

    [
        c[0].clamp(0.0, 1.0),
        c[1].clamp(0.0, 1.0),
        c[2].clamp(0.0, 1.0),
    ]
}

/// Bakes the point-wise pipeline into a 3D LUT packed as a 2D RGBA8 atlas.
///
/// **Atlas layout** (matches `shaders/lut.frag`):
///   width = `size * size`, height = `size`; blue slice `b` at columns
///   `[b*size, b*size+size)`; within a slice `x = red index`, `y = green index`.
pub fn bake_lut3d(size: u32, params: GradeParams) -> Vec<u8> {
    bake_lut3d_curves(size, params, None)
}

/// Bakes the point-wise pipeline, optionally with tone curves, into a 3D LUT.
///
/// **Atlas layout** (matches `shaders/lut.frag`):
///   width = `size * size`, height = `size`; blue slice `b` at columns
///   `[b*size, b*size+size)`; within a slice `x = red index`, `y = green index`.
pub fn bake_lut3d_curves(size: u32, params: GradeParams, curves: Option<&CurveSet>) -> Vec<u8> {
    let n = size as usize;
    let (w, h) = (n * n, n);
    let inv = 1.0 / (n - 1) as f32;
    let mut rgba = vec![0u8; w * h * 4];

    for bi in 0..n {
        for gi in 0..n {
            for ri in 0..n {
                let out = grade_pixel_c(
                    ri as f32 * inv,
                    gi as f32 * inv,
                    bi as f32 * inv,
                    params,
                    curves,
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
        let rgba = bake_lut3d(8, GradeParams::default());
        assert_eq!(rgba.len(), (8 * 8 * 8 * 4) as usize);
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
        let atlas = bake_lut3d(LUT_SIZE, GradeParams::default());
        for &(r, g, b) in &[
            (0.0, 0.0, 0.0),
            (0.5, 0.5, 0.5),
            (1.0, 1.0, 1.0),
            (0.2, 0.7, 0.4),
        ] {
            let out = sample_lut(&atlas, LUT_SIZE, r, g, b);
            assert!((out[0] - r).abs() < 2.0 / 255.0);
            assert!((out[1] - g).abs() < 2.0 / 255.0);
            assert!((out[2] - b).abs() < 2.0 / 255.0);
        }
    }

    #[test]
    fn trilinear_lut_matches_the_direct_pipeline() {
        let params = GradeParams {
            exposure: 0.8,
            contrast: 0.35,
            saturation: 0.3,
            temperature: 0.4,
            tint: -0.2,
            vibrance: 0.5,
            grade_shadow_hue: 0.6,
            grade_shadow_sat: 0.3,
            grade_mid_hue: 0.1,
            grade_mid_sat: 0.2,
            grade_highlight_hue: 0.1,
            grade_highlight_sat: 0.25,
        };
        let atlas = bake_lut3d(LUT_SIZE, params);
        let mut worst = 0.0f32;
        for ri in 0..16 {
            for gi in 0..16 {
                for bi in 0..16 {
                    let r = (ri as f32 + 0.37) / 16.0;
                    let g = (gi as f32 + 0.11) / 16.0;
                    let b = (bi as f32 + 0.63) / 16.0;
                    let direct = grade_pixel_srgb(r, g, b, params);
                    let via = sample_lut(&atlas, LUT_SIZE, r, g, b);
                    for k in 0..3 {
                        worst = worst.max((direct[k] - via[k]).abs());
                    }
                }
            }
        }
        // 33³ trilinear reproduces this *strongly graded* pipeline within ~6/255
        // (error grows with nonlinear ops; realistic single-slider grades are
        // far tighter). A 65³ LUT is the escape hatch if ever needed.
        assert!(worst < 0.03, "worst LUT error {worst}");
    }

    #[test]
    fn exposure_is_monotonic_and_brightens() {
        let at = |ev| {
            grade_pixel_srgb(
                0.4,
                0.4,
                0.4,
                GradeParams {
                    exposure: ev,
                    ..Default::default()
                },
            )[0]
        };
        assert!(at(1.0) > at(0.0) && at(-1.0) < at(0.0));
    }

    #[test]
    fn saturation_on_grey_is_a_no_op() {
        let out = grade_pixel_srgb(
            0.5,
            0.5,
            0.5,
            GradeParams {
                saturation: 1.0,
                ..Default::default()
            },
        );
        assert!((out[0] - out[1]).abs() < 1e-4 && (out[1] - out[2]).abs() < 1e-4);
        assert!((out[0] - 0.5).abs() < 1e-3);
    }

    #[test]
    fn warm_white_balance_raises_red_over_blue() {
        let neutral = grade_pixel_srgb(0.5, 0.5, 0.5, GradeParams::default());
        let warm = grade_pixel_srgb(
            0.5,
            0.5,
            0.5,
            GradeParams {
                temperature: 0.5,
                ..Default::default()
            },
        );
        // Warmer: red/blue ratio increases.
        let ratio0 = neutral[0] / neutral[2];
        let ratio1 = warm[0] / warm[2];
        assert!(ratio1 > ratio0, "{ratio1} !> {ratio0}");
    }

    #[test]
    fn vibrance_protects_already_saturated_colors() {
        // A fully saturated red barely moves; a muted colour moves a lot.
        let muted = [0.6, 0.45, 0.45];
        let vivid = [1.0, 0.0, 0.0];
        let p = GradeParams {
            vibrance: 1.0,
            ..Default::default()
        };

        let muted_out = grade_pixel_srgb(muted[0], muted[1], muted[2], p);
        let vivid_out = grade_pixel_srgb(vivid[0], vivid[1], vivid[2], p);

        let muted_delta = (muted_out[0] - muted_out[1]).abs() - (muted[0] - muted[1]).abs();
        let vivid_delta = (vivid_out[0] - vivid_out[1]).abs() - (vivid[0] - vivid[1]).abs();
        assert!(muted_delta > vivid_delta);
    }

    #[test]
    fn color_grading_is_neutral_at_zero() {
        let base = [0.4, 0.5, 0.6];
        let out = grade_pixel_srgb(base[0], base[1], base[2], GradeParams::default());
        for k in 0..3 {
            assert!((out[k] - base[k]).abs() < 1e-4, "{out:?}");
        }
    }

    #[test]
    fn shadow_grade_tints_shadows_not_highlights() {
        // Blue shadow tint (hue ~0.66), highlights warm (hue ~0.08).
        let p = GradeParams {
            grade_shadow_hue: 0.66,
            grade_shadow_sat: 1.0,
            ..Default::default()
        };
        let shadow = grade_pixel_srgb(0.15, 0.15, 0.15, p);
        let highlight = grade_pixel_srgb(0.9, 0.9, 0.9, p);

        // In the shadow, blue is pushed above red.
        assert!(shadow[2] > shadow[0], "shadow not blue: {shadow:?}");
        // The highlight is essentially untouched (shadow weight ~0).
        assert!((highlight[2] - highlight[0]).abs() < 0.02, "{highlight:?}");
    }

    #[test]
    fn highlight_grade_tints_highlights_not_shadows() {
        let p = GradeParams {
            grade_highlight_hue: 0.08, // warm
            grade_highlight_sat: 1.0,
            ..Default::default()
        };
        let highlight = grade_pixel_srgb(0.9, 0.9, 0.9, p);
        let shadow = grade_pixel_srgb(0.1, 0.1, 0.1, p);

        assert!(
            highlight[0] > highlight[2],
            "highlight not warm: {highlight:?}"
        );
        assert!((shadow[0] - shadow[2]).abs() < 0.02, "{shadow:?}");
    }

    #[test]
    fn color_grading_preserves_luma() {
        let p = GradeParams {
            grade_mid_hue: 0.33,
            grade_mid_sat: 0.8,
            ..Default::default()
        };
        let base = [0.45, 0.5, 0.55];
        let out = grade_pixel_srgb(base[0], base[1], base[2], p);
        let luma = |c: [f32; 3]| 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
        assert!((luma(out) - luma(base)).abs() < 0.01, "{out:?}");
    }

    #[test]
    fn curve_lut_identity_maps_x_to_x() {
        let lut = curve_lut(&[]);
        for (i, v) in lut.iter().enumerate() {
            let x = i as f32 / 255.0;
            assert!((v - x).abs() < 1e-4, "bin {i}");
        }
    }

    #[test]
    fn curve_lut_is_monotone_and_brightens() {
        // Lift the midtones.
        let lut = curve_lut(&[0.0, 0.0, 0.5, 0.7, 1.0, 1.0]);
        assert!(lut[128] > 0.55, "mid lifted: {}", lut[128]);
        for w in lut.windows(2) {
            assert!(w[1] >= w[0] - 1e-6, "not monotone");
        }
    }

    #[test]
    fn master_curve_brightens_the_pipeline() {
        let identity = CurveSet::from_points(&[0.0, 0.0, 1.0, 1.0], &[], &[], &[]);
        // A lifting curve: [0,0, 0.5,0.65, 1,1].
        let lifted = CurveSet::from_points(&[0.0, 0.0, 0.5, 0.65, 1.0, 1.0], &[], &[], &[]);
        let base = grade_pixel_c(0.5, 0.5, 0.5, GradeParams::default(), Some(&identity));
        let up = grade_pixel_c(0.5, 0.5, 0.5, GradeParams::default(), Some(&lifted));
        assert!(up[0] > base[0] + 0.05, "{up:?} vs {base:?}");
    }

    #[test]
    fn lut_with_curves_matches_the_direct_pipeline() {
        let params = GradeParams {
            exposure: 0.3,
            contrast: 0.2,
            ..Default::default()
        };
        let curves = CurveSet::from_points(
            &[0.0, 0.0, 0.5, 0.6, 1.0, 1.0],
            &[0.0, 0.05, 1.0, 1.0],
            &[],
            &[],
        );
        let atlas = bake_lut3d_curves(LUT_SIZE, params, Some(&curves));
        let mut worst = 0.0f32;
        for k in 0..24 {
            let v = (k as f32 + 0.4) / 24.0;
            let direct = grade_pixel_c(v, v * 0.8, v * 0.6, params, Some(&curves));
            let via = sample_lut(&atlas, LUT_SIZE, v, v * 0.8, v * 0.6);
            for i in 0..3 {
                worst = worst.max((direct[i] - via[i]).abs());
            }
        }
        assert!(worst < 0.03, "worst {worst}");
    }
}
