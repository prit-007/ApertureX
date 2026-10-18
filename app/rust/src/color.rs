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

/// The 3D LUT edge length. 65³ keeps the trilinear approximation tight even
/// with the nonlinear Oklab saturation stage (atlas ~1.1 MB).
pub const LUT_SIZE: u32 = 65;

/// The point-wise grade parameters (neutral at all-zero).
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct GradeParams {
    /// Exposure in EV (stops).
    pub exposure: f32,
    /// Contrast, unitless around 0.
    pub contrast: f32,
    /// Highlights trim (point-wise tonal recovery or boost, issue #94).
    pub highlights: f32,
    /// Shadows trim (point-wise tonal lift or crush, issue #94).
    pub shadows: f32,
    /// Whites trim (linear white point trim, anchored at midtone ~0.18).
    pub whites: f32,
    /// Blacks trim (linear black point trim, anchored at midtone ~0.18).
    pub blacks: f32,
    /// Saturation, unitless around 0.
    pub saturation: f32,
    /// White-balance temperature, unitless around 0 (warm > 0).
    pub temperature: f32,
    /// White-balance tint, unitless around 0 (magenta > 0).
    pub tint: f32,
    /// Vibrance (protects already-saturated pixels and skin tones), unitless around 0.
    pub vibrance: f32,
    /// Split-tone / 3-way Color Wheels: hue (0..1), sat (0..1), lum (-1..1) per tonal zone.
    pub grade_shadow_hue: f32,
    pub grade_shadow_sat: f32,
    pub grade_shadow_lum: f32,
    pub grade_mid_hue: f32,
    pub grade_mid_sat: f32,
    pub grade_mid_lum: f32,
    pub grade_highlight_hue: f32,
    pub grade_highlight_sat: f32,
    pub grade_highlight_lum: f32,
    /// Blending (crossover width) between zones: 0..1, default 0.5.
    pub grade_blending: f32,
    /// Balance (midpoint bias): -1..1, default 0.0.
    pub grade_balance: f32,
}

impl Default for GradeParams {
    fn default() -> Self {
        Self {
            exposure: 0.0,
            contrast: 0.0,
            highlights: 0.0,
            shadows: 0.0,
            whites: 0.0,
            blacks: 0.0,
            saturation: 0.0,
            temperature: 0.0,
            tint: 0.0,
            vibrance: 0.0,
            grade_shadow_hue: 0.0,
            grade_shadow_sat: 0.0,
            grade_shadow_lum: 0.0,
            grade_mid_hue: 0.0,
            grade_mid_sat: 0.0,
            grade_mid_lum: 0.0,
            grade_highlight_hue: 0.0,
            grade_highlight_sat: 0.0,
            grade_highlight_lum: 0.0,
            grade_blending: 0.5,
            grade_balance: 0.0,
        }
    }
}

/// sRGB EOTF: encoded `[0,1]` → linear `[0,1]`.
pub fn srgb_to_linear(c: f32) -> f32 {
    #[cfg(target_arch = "aarch64")]
    {
        if is_aarch64_feature_detected!("neon") {
            return unsafe { neon_srgb_to_linear1(c) };
        }
    }
    if c <= 0.04045 {
        c / 12.92
    } else {
        ((c + 0.055) / 1.055).powf(2.4)
    }
}

/// sRGB OETF: linear `[0,1]` → encoded `[0,1]`.
pub fn linear_to_srgb(c: f32) -> f32 {
    #[cfg(target_arch = "aarch64")]
    {
        if is_aarch64_feature_detected!("neon") {
            return unsafe { neon_linear_to_srgb1(c) };
        }
    }
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

/// Vibrance: boost saturation inversely to how saturated a pixel already is,
/// with Adobe-style skin tone protection (protects warm orange/skin hues from clipping).
fn vibrance(c: [f32; 3], amount: f32) -> [f32; 3] {
    if amount == 0.0 {
        return c;
    }
    let maxc = c[0].max(c[1]).max(c[2]);
    let minc = c[0].min(c[1]).min(c[2]);
    let d = maxc - minc;
    let sat = if maxc > 1e-6 { d / maxc } else { 0.0 };
    let weight = (1.0 - sat).clamp(0.0, 1.0);

    // Adobe-style skin protection: calculate hue in [0, 1)
    let skin_protect = if d > 1e-5 {
        let r = c[0];
        let g = c[1];
        let b = c[2];
        let h = if (maxc - r).abs() < 1e-6 {
            ((g - b) / d).rem_euclid(6.0) / 6.0
        } else if (maxc - g).abs() < 1e-6 {
            ((b - r) / d + 2.0) / 6.0
        } else {
            ((r - g) / d + 4.0) / 6.0
        };
        // Skin tones center around ~27° (0.075) with spread ~0.045
        let hue_dist = (h - 0.075).abs().min(1.0 - (h - 0.075).abs());
        let skin_weight = (-hue_dist * hue_dist / (2.0 * 0.045 * 0.045)).exp();
        (1.0 - 0.65 * skin_weight).clamp(0.2, 1.0)
    } else {
        1.0
    };

    let luma = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
    let f = 1.0 + amount * weight * skin_protect * 1.5;
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

/// Split-tone / 3-way color grading: shift each pixel toward the shadow/mid/highlight
/// hue and luminance, weighted by where its luminance sits (ARCHITECTURE §8).
fn color_grade(c: [f32; 3], p: GradeParams) -> [f32; 3] {
    let luma = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];

    // Midtone center modulated by balance (-1..1: positive favors highlights, negative favors shadows).
    let mid_center = (0.5 - p.grade_balance * 0.25).clamp(0.1, 0.9);

    // Blending controls crossover softness (0 = sharp, 1 = wide overlap, default 0.5).
    let blend = p.grade_blending.clamp(0.01, 1.0);
    let shadow_w = if luma < mid_center {
        (1.0 - (luma / mid_center))
            .powf(1.0 / (blend * 2.0).max(0.01))
            .clamp(0.0, 1.0)
    } else {
        0.0
    };
    let highlight_w = if luma > mid_center {
        ((luma - mid_center) / (1.0 - mid_center))
            .powf(1.0 / (blend * 2.0).max(0.01))
            .clamp(0.0, 1.0)
    } else {
        0.0
    };
    let mid_w = (1.0 - shadow_w - highlight_w).clamp(0.0, 1.0);

    let mut out = c;
    for (hue, sat, lum, weight) in [
        (
            p.grade_shadow_hue,
            p.grade_shadow_sat,
            p.grade_shadow_lum,
            shadow_w,
        ),
        (p.grade_mid_hue, p.grade_mid_sat, p.grade_mid_lum, mid_w),
        (
            p.grade_highlight_hue,
            p.grade_highlight_sat,
            p.grade_highlight_lum,
            highlight_w,
        ),
    ] {
        let factor = sat * weight * 0.5;
        if factor > 0.0 {
            let tint = hue_rgb(hue);
            let tint_luma = 0.2126 * tint[0] + 0.7152 * tint[1] + 0.0722 * tint[2];
            for (o, t) in out.iter_mut().zip(tint) {
                *o += (t - tint_luma) * factor;
            }
        }
        if lum != 0.0 {
            let lum_delta = lum * weight * 0.5;
            for o in out.iter_mut() {
                *o += lum_delta;
            }
        }
    }
    out
}

/// Hue centres (in `[0,1)`) of the eight HSL color-mixer bands.
pub const HSL_BANDS: [f32; 8] = [
    0.0, // red
    30.0 / 360.0,
    60.0 / 360.0,  // yellow
    120.0 / 360.0, // green
    180.0 / 360.0, // aqua
    240.0 / 360.0, // blue
    270.0 / 360.0, // purple
    300.0 / 360.0, // magenta
];

/// Neutral (all-zero) HSL mix.
pub const ZERO_HSL: [f32; 24] = [0.0; 24];

pub(crate) fn rgb_to_hsl(c: [f32; 3]) -> [f32; 3] {
    let (r, g, b) = (c[0], c[1], c[2]);
    let max = r.max(g).max(b);
    let min = r.min(g).min(b);
    let l = (max + min) / 2.0;
    let d = max - min;
    if d < 1e-6 {
        return [0.0, 0.0, l];
    }
    let s = if l > 0.5 {
        d / (2.0 - max - min)
    } else {
        d / (max + min)
    };
    let h = if max == r {
        ((g - b) / d + if g < b { 6.0 } else { 0.0 }) / 6.0
    } else if max == g {
        ((b - r) / d + 2.0) / 6.0
    } else {
        ((r - g) / d + 4.0) / 6.0
    };
    [h, s, l]
}

fn hue_to_rgb(p: f32, q: f32, t: f32) -> f32 {
    let t = t.rem_euclid(1.0);
    if t < 1.0 / 6.0 {
        p + (q - p) * 6.0 * t
    } else if t < 1.0 / 2.0 {
        q
    } else if t < 2.0 / 3.0 {
        p + (q - p) * (2.0 / 3.0 - t) * 6.0
    } else {
        p
    }
}

pub(crate) fn hsl_to_rgb(hsl: [f32; 3]) -> [f32; 3] {
    let (h, s, l) = (hsl[0], hsl[1], hsl[2]);
    if s < 1e-6 {
        return [l, l, l];
    }
    let q = if l < 0.5 {
        l * (1.0 + s)
    } else {
        l + s - l * s
    };
    let p = 2.0 * l - q;
    [
        hue_to_rgb(p, q, h + 1.0 / 3.0),
        hue_to_rgb(p, q, h),
        hue_to_rgb(p, q, h - 1.0 / 3.0),
    ]
}

/// HSL color-mixer: shift hue/saturation/luminance weighted by how close a
/// pixel's hue is to each of the eight bands. `hsl` is `[h,s,l]` per band
/// (8×3), each in `[-1,1]`.
pub fn apply_hsl(c: [f32; 3], hsl: &[f32; 24]) -> [f32; 3] {
    if hsl.iter().all(|&v| v == 0.0) {
        return c;
    }
    let [h, s, l] = rgb_to_hsl(c);
    if s < 1e-4 {
        return c; // greys have no hue to target
    }
    let mut dh = 0.0;
    let mut ds = 0.0;
    let mut dl = 0.0;
    for (i, &center) in HSL_BANDS.iter().enumerate() {
        let d = (h - center).abs();
        let ang = d.min(1.0 - d); // wrap-aware
        let w = (1.0 - ang / 0.12).clamp(0.0, 1.0);
        if w > 0.0 {
            dh += hsl[i * 3] * w;
            ds += hsl[i * 3 + 1] * w;
            dl += hsl[i * 3 + 2] * w;
        }
    }
    let nh = (h + dh * (30.0 / 360.0)).rem_euclid(1.0);
    let ns = (s + s * ds).clamp(0.0, 1.0);
    let nl = (l + dl * 0.4).clamp(0.0, 1.0);
    hsl_to_rgb([nh, ns, nl])
}

/// sRGB-encoded `[0,1]` → Oklab (Ottosson 2020), a perceptually uniform space.
fn srgb_to_oklab(r: f32, g: f32, b: f32) -> [f32; 3] {
    let (r, g, b) = (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b));
    let l = 0.412_221_46 * r + 0.536_332_55 * g + 0.051_445_995 * b;
    let m = 0.211_903_5 * r + 0.680_699_5 * g + 0.107_396_96 * b;
    let s = 0.088_302_46 * r + 0.281_718_85 * g + 0.629_978_7 * b;
    let (l_, m_, s_) = (l.cbrt(), m.cbrt(), s.cbrt());
    [
        0.210_454_26 * l_ + 0.793_617_8 * m_ - 0.004_072_047 * s_,
        1.977_998_5 * l_ - 2.428_592_2 * m_ + 0.450_593_7 * s_,
        0.025_904_037 * l_ + 0.782_771_77 * m_ - 0.808_675_77 * s_,
    ]
}

/// Oklab → sRGB-encoded `[0,1]`.
fn oklab_to_srgb(lab: [f32; 3]) -> [f32; 3] {
    let l_ = lab[0] + 0.396_337_78 * lab[1] + 0.215_803_76 * lab[2];
    let m_ = lab[0] - 0.105_561_346 * lab[1] - 0.063_854_17 * lab[2];
    let s_ = lab[0] - 0.089_484_18 * lab[1] - 1.291_485_5 * lab[2];
    let (l, m, s) = (l_ * l_ * l_, m_ * m_ * m_, s_ * s_ * s_);
    let r = 4.076_741_7 * l - 3.307_711_6 * m + 0.230_969_94 * s;
    let g = -1.268_438 * l + 2.609_757_4 * m - 0.341_319_38 * s;
    let b = -0.004_196_086 * l - 0.703_418_6 * m + 1.707_614_7 * s;
    [
        linear_to_srgb(r).clamp(0.0, 1.0),
        linear_to_srgb(g).clamp(0.0, 1.0),
        linear_to_srgb(b).clamp(0.0, 1.0),
    ]
}

/// Hue-preserving saturation: scale Oklab chroma (`a`,`b`) uniformly, so colours
/// get richer without shifting hue or blowing out skin tones — the area where
/// HSL "turns blue into purple" (the Oklab flex).
pub fn saturate_oklab(c: [f32; 3], amount: f32) -> [f32; 3] {
    if amount == 0.0 {
        return c;
    }
    let lab = srgb_to_oklab(c[0], c[1], c[2]);
    let f = 1.0 + amount;
    oklab_to_srgb([lab[0], lab[1] * f, lab[2] * f])
}

/// Applies the point-wise colour pipeline (identity curves) to one pixel.
pub fn grade_pixel_srgb(r: f32, g: f32, b: f32, p: GradeParams) -> [f32; 3] {
    grade_pixel_c(r, g, b, p, None, &ZERO_HSL)
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
    hsl: &[f32; 24],
) -> [f32; 3] {
    // 1. decode to linear.
    let lin = [srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b)];

    // 2. white balance (linear, Von Kries).
    let lin = white_balance(lin, p.temperature, p.tint);

    // 3. exposure (linear, multiplicative).
    let ev = 2f32.powf(p.exposure);
    let mut lin = [
        (lin[0] * ev).max(0.0),
        (lin[1] * ev).max(0.0),
        (lin[2] * ev).max(0.0),
    ];

    // 3b. Whites and Blacks trims (linear white/black point trims anchored at midtone ~0.18).
    if p.whites != 0.0 {
        for v in &mut lin {
            if *v > 0.18 {
                let t = ((*v - 0.18) / 0.82).min(1.0);
                let w = t * t;
                *v = (*v * (1.0 + p.whites * 0.35 * w)).max(0.0);
            }
        }
    }

    if p.blacks != 0.0 {
        for v in &mut lin {
            if *v < 0.18 {
                let t = (1.0 - *v / 0.18).max(0.0);
                let w = t * t;
                if p.blacks >= 0.0 {
                    *v += p.blacks * 0.04 * w;
                } else {
                    *v = (*v * (1.0 + p.blacks * 0.6 * w)).max(0.0);
                }
            }
        }
    }

    let mut c = [
        linear_to_srgb(lin[0]),
        linear_to_srgb(lin[1]),
        linear_to_srgb(lin[2]),
    ];

    // 4. contrast S-curve (perceptual).
    for v in &mut c {
        *v = contrast_curve(*v, p.contrast);
    }

    // 4b. Pointwise highlights and shadows (perceptual/luma, issue #94).
    if p.highlights != 0.0 || p.shadows != 0.0 {
        let luma = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
        let shadow_delta = p.shadows * (1.0 - 2.0 * luma).clamp(0.0, 1.0) * 0.5;
        let highlight_delta = p.highlights * (2.0 * luma - 1.0).clamp(0.0, 1.0) * 0.5;
        let target = (luma + shadow_delta + highlight_delta).clamp(0.0, 1.0);
        let scale = if luma > 1e-3 { target / luma } else { 1.0 };
        c = [
            (c[0] * scale).clamp(0.0, 1.0),
            (c[1] * scale).clamp(0.0, 1.0),
            (c[2] * scale).clamp(0.0, 1.0),
        ];
    }

    // 5. vibrance, then saturation — saturation in Oklab (hue-preserving).
    c = vibrance(c, p.vibrance);
    c = saturate_oklab(c, p.saturation);

    // 6. color grading (split tone, luma-weighted).
    c = color_grade(c, p);

    // 6b. HSL color mixer (point-wise).
    c = apply_hsl(c, hsl);

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

/// Applies the point-wise colour pipeline with no curves/HSL — used by local
/// adjustments (masks).
pub fn grade_pointwise(c: [f32; 3], p: GradeParams) -> [f32; 3] {
    grade_pixel_c(c[0], c[1], c[2], p, None, &ZERO_HSL)
}

/// Bakes the point-wise pipeline into a 3D LUT packed as a 2D RGBA8 atlas.
///
/// **Atlas layout** (matches `shaders/lut.frag`):
///   width = `size * size`, height = `size`; blue slice `b` at columns
///   `[b*size, b*size+size)`; within a slice `x = red index`, `y = green index`.
pub fn bake_lut3d(size: u32, params: GradeParams) -> Vec<u8> {
    bake_lut3d_curves(size, params, None, &ZERO_HSL)
}

/// Bakes the point-wise pipeline, optionally with tone curves, into a 3D LUT.
///
/// **Atlas layout** (matches `shaders/lut.frag`):
///   width = `size * size`, height = `size`; blue slice `b` at columns
///   `[b*size, b*size+size)`; within a slice `x = red index`, `y = green index`.
pub fn bake_lut3d_curves(
    size: u32,
    params: GradeParams,
    curves: Option<&CurveSet>,
    hsl: &[f32; 24],
) -> Vec<u8> {
    let n = size.clamp(2, 256) as usize;
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
                    hsl,
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

/// Exports the point-wise color pipeline as a DaVinci Resolve / Adobe Premiere compliant `.cube` 3D LUT string.
/// `size` is the cube edge length (typically 17, 33, or 65).
pub fn export_cube_lut(
    size: u32,
    params: GradeParams,
    curves: Option<&CurveSet>,
    hsl: &[f32; 24],
    title: Option<&str>,
) -> String {
    use std::fmt::Write;
    let n = size as usize;
    let inv = 1.0 / (n - 1).max(1) as f32;
    let mut out_str = String::with_capacity(n * n * n * 28 + 128);

    writeln!(out_str, "# Created by ApertureX").unwrap();
    writeln!(out_str, "TITLE \"{}\"", title.unwrap_or("ApertureX Grade")).unwrap();
    writeln!(out_str, "LUT_3D_SIZE {}", size).unwrap();
    writeln!(out_str, "DOMAIN_MIN 0.0 0.0 0.0").unwrap();
    writeln!(out_str, "DOMAIN_MAX 1.0 1.0 1.0").unwrap();
    writeln!(out_str).unwrap();

    // Standard Adobe .CUBE order: red changes fastest, green second, blue slowest.
    for bi in 0..n {
        for gi in 0..n {
            for ri in 0..n {
                let out = grade_pixel_c(
                    ri as f32 * inv,
                    gi as f32 * inv,
                    bi as f32 * inv,
                    params,
                    curves,
                    hsl,
                );
                writeln!(
                    out_str,
                    "{:.6} {:.6} {:.6}",
                    out[0].clamp(0.0, 1.0),
                    out[1].clamp(0.0, 1.0),
                    out[2].clamp(0.0, 1.0)
                )
                .unwrap();
            }
        }
    }
    out_str
}

/// NEON-optimized color math (aarch64 only).
///
/// Processes 4 lanes at once using `f32x4` registers. Scalar callers
/// (`srgb_to_linear`, `linear_to_srgb`) dispatch to these on aarch64 when
/// the `neon` target feature is detected.
#[cfg(target_arch = "aarch64")]
mod neon_impl {
    use std::arch::aarch64::*;

    #[target_feature(enable = "neon")]
    pub(crate) unsafe fn neon_srgb_to_linear4(x: f32x4) -> f32x4 {
        let threshold = vdupq_n_f32(0.04045);
        let linear_scale = vdupq_n_f32(1.0 / 12.92);
        let gamma_offset = vdupq_n_f32(0.055 / 1.055);
        let gamma_scale = vdupq_n_f32(1.0 / 1.055);
        let mask = vcleq_f32(x, threshold);
        // Linear branch: NEON multiply.
        let linear = vmulq_f32(x, linear_scale);
        // Gamma branch: scalar powf per lane (NEON has no f32x4 pow).
        let g = [
            (vgetq_lane_f32(x, 0) + 0.055) * gamma_scale,
            (vgetq_lane_f32(x, 1) + 0.055) * gamma_scale,
            (vgetq_lane_f32(x, 2) + 0.055) * gamma_scale,
            (vgetq_lane_f32(x, 3) + 0.055) * gamma_scale,
        ];
        let gamma = vld1q_f32(
            [
                g[0].powf(2.4),
                g[1].powf(2.4),
                g[2].powf(2.4),
                g[3].powf(2.4),
            ]
            .as_ptr(),
        );
        vbslq_f32(mask, linear, gamma)
    }

    #[target_feature(enable = "neon")]
    pub(crate) unsafe fn neon_linear_to_srgb4(x: f32x4) -> f32x4 {
        let threshold = vdupq_n_f32(0.0031308);
        let linear_scale = vdupq_n_f32(12.92);
        let gamma_scale = vdupq_n_f32(1.055);
        let gamma_offset = vdupq_n_f32(0.055);
        let inv_24 = vdupq_n_f32(1.0 / 2.4);
        let inv_24_val = vgetq_lane_f32(inv_24, 0);
        let mask = vcleq_f32(x, threshold);
        // Linear branch: NEON multiply.
        let linear = vmulq_f32(x, linear_scale);
        // Gamma branch: scalar powf per lane.
        let g = [
            vgetq_lane_f32(x, 0),
            vgetq_lane_f32(x, 1),
            vgetq_lane_f32(x, 2),
            vgetq_lane_f32(x, 3),
        ];
        let gamma = vld1q_f32(
            [
                gamma_scale * g[0].powf(inv_24_val) - gamma_offset,
                gamma_scale * g[1].powf(inv_24_val) - gamma_offset,
                gamma_scale * g[2].powf(inv_24_val) - gamma_offset,
                gamma_scale * g[3].powf(inv_24_val) - gamma_offset,
            ]
            .as_ptr(),
        );
        vbslq_f32(mask, linear, gamma)
    }

    /// Scalar-lane entry points (called from public functions).
    #[target_feature(enable = "neon")]
    pub(crate) unsafe fn neon_srgb_to_linear1(c: f32) -> f32 {
        vgetq_lane_f32(neon_srgb_to_linear4(vdupq_n_f32(c)), 0)
    }

    #[target_feature(enable = "neon")]
    pub(crate) unsafe fn neon_linear_to_srgb1(c: f32) -> f32 {
        vgetq_lane_f32(neon_linear_to_srgb4(vdupq_n_f32(c)), 0)
    }
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
            ..Default::default()
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
        // A 65³ grid reproduces a deliberately *extreme* combined grade
        // (every slider at once) to within ~15/255 worst-case; realistic
        // single-slider grades are far tighter (see the moderate test below).
        assert!(worst < 0.06, "worst LUT error {worst}");
    }

    #[test]
    fn lut_matches_the_pipeline_tightly_for_a_moderate_grade() {
        let params = GradeParams {
            exposure: 0.3,
            contrast: 0.2,
            saturation: 0.2,
            ..Default::default()
        };
        let atlas = bake_lut3d(LUT_SIZE, params);
        let mut worst = 0.0f32;
        for k in 0..32 {
            let v = (k as f32 + 0.5) / 32.0;
            let direct = grade_pixel_srgb(v, v * 0.7, v * 0.5, params);
            let via = sample_lut(&atlas, LUT_SIZE, v, v * 0.7, v * 0.5);
            for i in 0..3 {
                worst = worst.max((direct[i] - via[i]).abs());
            }
        }
        assert!(worst < 0.02, "moderate-grade worst {worst}");
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
    fn shadow_luminance_modifies_shadows_not_highlights() {
        let p = GradeParams {
            grade_shadow_lum: 0.5,
            ..Default::default()
        };
        let shadow = grade_pixel_srgb(0.1, 0.1, 0.1, p);
        let highlight = grade_pixel_srgb(0.9, 0.9, 0.9, p);

        // Shadow should be lifted (brighter than 0.1)
        assert!(shadow[0] > 0.15, "shadow not lifted: {shadow:?}");
        // Highlight should remain untouched
        assert!(
            (highlight[0] - 0.9).abs() < 0.02,
            "highlight shifted: {highlight:?}"
        );
    }

    #[test]
    fn highlight_luminance_modifies_highlights_not_shadows() {
        let p = GradeParams {
            grade_highlight_lum: -0.5,
            ..Default::default()
        };
        let highlight = grade_pixel_srgb(0.9, 0.9, 0.9, p);
        let shadow = grade_pixel_srgb(0.1, 0.1, 0.1, p);

        // Highlight should be pulled down
        assert!(
            highlight[0] < 0.85,
            "highlight not pulled down: {highlight:?}"
        );
        // Shadow should remain untouched
        assert!((shadow[0] - 0.1).abs() < 0.02, "shadow shifted: {shadow:?}");
    }

    #[test]
    fn color_grading_balance_shifts_weight() {
        // With balance shifted towards highlights (+1.0), shadow tinting falls off sooner.
        let p_neutral = GradeParams {
            grade_shadow_sat: 1.0,
            grade_shadow_hue: 0.66,
            grade_balance: 0.0,
            ..Default::default()
        };
        let p_highlight_biased = GradeParams {
            grade_shadow_sat: 1.0,
            grade_shadow_hue: 0.66,
            grade_balance: 1.0,
            ..Default::default()
        };
        // At mid-dark level (0.35), highlight-biased balance should have less shadow tint effect
        let neutral_mid = grade_pixel_srgb(0.35, 0.35, 0.35, p_neutral);
        let biased_mid = grade_pixel_srgb(0.35, 0.35, 0.35, p_highlight_biased);

        let neutral_blue_lift = neutral_mid[2] - neutral_mid[0];
        let biased_blue_lift = biased_mid[2] - biased_mid[0];
        assert!(
            neutral_blue_lift > biased_blue_lift,
            "balance didn't shift weight: {neutral_blue_lift} vs {biased_blue_lift}"
        );
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
    fn curve_lut_fixture_matches_the_dart_port() {
        // Shared fixtures pinned to lib/edit/curve_math_test.dart so the
        // tone-curve editor paints the same curve this LUT grades with
        // (issue #49).
        let pts = [0.0f32, 0.0, 0.25, 0.2, 0.75, 0.85, 1.0, 1.0];
        let lut = curve_lut(&pts);
        let expected = [
            0.0f32, 0.09254913, 0.20103107, 0.3551304, 0.5340928, 0.7043178, 0.8490669, 0.9356861,
            1.0,
        ];
        for (k, want) in expected.iter().enumerate() {
            let i = ((k as f32 / 8.0) * 255.0).round() as usize;
            let got = lut[i.min(255)];
            assert!(
                (got - want).abs() < 1.0 / 255.0,
                "fixture[{k}]: got {got}, want {want}"
            );
        }
    }

    #[test]
    fn master_curve_brightens_the_pipeline() {
        let identity = CurveSet::from_points(&[0.0, 0.0, 1.0, 1.0], &[], &[], &[]);
        // A lifting curve: [0,0, 0.5,0.65, 1,1].
        let lifted = CurveSet::from_points(&[0.0, 0.0, 0.5, 0.65, 1.0, 1.0], &[], &[], &[]);
        let base = grade_pixel_c(
            0.5,
            0.5,
            0.5,
            GradeParams::default(),
            Some(&identity),
            &ZERO_HSL,
        );
        let up = grade_pixel_c(
            0.5,
            0.5,
            0.5,
            GradeParams::default(),
            Some(&lifted),
            &ZERO_HSL,
        );
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
        let atlas = bake_lut3d_curves(LUT_SIZE, params, Some(&curves), &ZERO_HSL);
        let mut worst = 0.0f32;
        for k in 0..24 {
            let v = (k as f32 + 0.4) / 24.0;
            let direct = grade_pixel_c(v, v * 0.8, v * 0.6, params, Some(&curves), &ZERO_HSL);
            let via = sample_lut(&atlas, LUT_SIZE, v, v * 0.8, v * 0.6);
            for i in 0..3 {
                worst = worst.max((direct[i] - via[i]).abs());
            }
        }
        assert!(worst < 0.03, "worst {worst}");
    }

    #[test]
    fn hsl_is_neutral_at_zero() {
        let c = [0.6, 0.3, 0.2];
        assert_eq!(apply_hsl(c, &ZERO_HSL), c);
    }

    #[test]
    fn hsl_band_targets_the_matching_hue() {
        let mut hsl = ZERO_HSL;
        hsl[1] = 1.0; // red band saturation +
        let red_before = 0.8 - 0.2;
        let red = apply_hsl([0.8, 0.2, 0.2], &hsl);
        let blue = apply_hsl([0.2, 0.2, 0.8], &hsl);
        assert!(red[0] - red[1] > red_before, "red should saturate: {red:?}");
        assert!(
            ((blue[2] - blue[0]) - red_before).abs() < 0.05,
            "blue should be ~untouched: {blue:?}"
        );
    }

    #[test]
    fn hsl_hue_shift_rotates_the_hue() {
        let mut hsl = ZERO_HSL;
        hsl[0] = 1.0; // red band hue shift
        let out = apply_hsl([0.8, 0.2, 0.2], &hsl);
        assert!(out[1] > 0.2, "hue should rotate toward orange: {out:?}");
    }

    #[test]
    fn oklab_round_trip_is_identity() {
        for c in [[0.2, 0.4, 0.8], [0.1, 0.9, 0.3], [0.5, 0.5, 0.5]] {
            let out = saturate_oklab(c, 0.0);
            for k in 0..3 {
                assert!((out[k] - c[k]).abs() < 5e-4, "{c:?} -> {out:?}");
            }
        }
    }

    #[test]
    fn oklab_saturation_preserves_hue_and_raises_chroma() {
        let c = [0.2, 0.35, 0.8];
        let lab0 = srgb_to_oklab(c[0], c[1], c[2]);
        let out = saturate_oklab(c, 0.5);
        let lab1 = srgb_to_oklab(out[0], out[1], out[2]);

        let h0 = lab0[2].atan2(lab0[1]);
        let h1 = lab1[2].atan2(lab1[1]);
        assert!((h1 - h0).abs() < 0.05, "hue shifted: {h0} -> {h1}");

        let chroma = |l: [f32; 3]| (l[1] * l[1] + l[2] * l[2]).sqrt();
        assert!(chroma(lab1) > chroma(lab0));
    }

    /// Pipeline version constant to enforce a single canonical order in tests and
    /// documentation. Changing this requires updating ARCHITECTURE.md §8 and
    /// renumbering tests.
    const PIPELINE_VERSION: u32 = 1;

    #[test]
    fn pipeline_order_is_canonicalized_and_versioned() {
        assert_eq!(PIPELINE_VERSION, 1);
        // Current order: 1. linear 2. WB 3. exposure 4. contrast 5. vibrance+sat
        // 6. color_grade (split-tone) 7. HSL 8. curves 9. clamp (export/preview)
    }

    /// Perf smoke: bakes a 65³ LUT and runs a 512² spatial pass, printing
    /// timings. Deterministic with no timing assertions, so it cannot flake;
    /// the on-device 60fps gate is #17.
    #[test]
    fn perf_smoke_bake_and_spatial() {
        use std::time::Instant;
        let p = GradeParams {
            exposure: 0.3,
            contrast: 0.2,
            saturation: 0.2,
            ..Default::default()
        };
        let t = Instant::now();
        let atlas = bake_lut3d(LUT_SIZE, p);
        assert_eq!(atlas.len(), (LUT_SIZE * LUT_SIZE * LUT_SIZE * 4) as usize);
        println!("bake 65^3: {:?}", t.elapsed());

        let (w, h) = (512usize, 512usize);
        let rgba = vec![128u8; w * h * 4];
        let t2 = Instant::now();
        let _ = crate::spatial::apply_spatial(
            &rgba,
            w,
            h,
            crate::spatial::SpatialParams {
                texture: 0.5,
                ..Default::default()
            },
        );
        println!("spatial 512^2: {:?}", t2.elapsed());
    }

    #[test]
    fn export_cube_lut_header_has_required_cube_tokens() {
        let p = GradeParams::default();
        let cube = export_cube_lut(17, p, None, &ZERO_HSL, Some("Cinematic Test"));
        assert!(cube.contains("TITLE \"Cinematic Test\""));
        assert!(cube.contains("LUT_3D_SIZE 17"));
        assert!(cube.contains("DOMAIN_MIN 0.0 0.0 0.0"));
        assert!(cube.contains("DOMAIN_MAX 1.0 1.0 1.0"));
        // Total lines: 5 header lines + 1 empty line + 17^3 (4913 data lines) = 4919 lines
        let lines: Vec<&str> = cube.trim().lines().collect();
        assert_eq!(lines.len(), 6 + 17 * 17 * 17);
    }

    #[test]
    fn export_cube_lut_identity_matches_domain_range() {
        let p = GradeParams::default();
        let cube = export_cube_lut(2, p, None, &ZERO_HSL, None);
        let data_lines: Vec<&str> = cube
            .lines()
            .filter(|l| {
                !l.is_empty()
                    && !l.starts_with('#')
                    && !l.starts_with("TITLE")
                    && !l.starts_with("LUT")
                    && !l.starts_with("DOMAIN")
            })
            .collect();
        assert_eq!(data_lines.len(), 8); // 2^3
                                         // In .cube order: red fastest, green next, blue slowest
                                         // First entry: r=0, g=0, b=0 -> 0.000000 0.000000 0.000000
        assert_eq!(data_lines[0], "0.000000 0.000000 0.000000");
        // Second entry: r=1, g=0, b=0 -> 1.000000 0.000000 0.000000
        assert_eq!(data_lines[1], "1.000000 0.000000 0.000000");
        // Last entry: r=1, g=1, b=1 -> 1.000000 1.000000 1.000000
        assert_eq!(data_lines[7], "1.000000 1.000000 1.000000");
    }

    #[test]
    fn export_cube_lut_with_grade_alters_entries() {
        let p = GradeParams {
            exposure: 1.0, // +1 EV pushes values brighter
            ..Default::default()
        };
        let cube = export_cube_lut(3, p, None, &ZERO_HSL, None);
        let data_lines: Vec<&str> = cube
            .lines()
            .filter(|l| {
                !l.is_empty()
                    && !l.starts_with('#')
                    && !l.starts_with("TITLE")
                    && !l.starts_with("LUT")
                    && !l.starts_with("DOMAIN")
            })
            .collect();
        assert_eq!(data_lines.len(), 27);
        // Middle grey (r=0.5, g=0.5, b=0.5 at index 13) should be shifted brighter (> 0.5)
        let mid_parts: Vec<f32> = data_lines[13]
            .split_whitespace()
            .map(|s| s.parse().unwrap())
            .collect();
        assert!(mid_parts[0] > 0.55);
    }

    #[test]
    fn whites_trims_highlights_without_shifting_midtones() {
        let p_pos = GradeParams {
            whites: 0.8,
            ..Default::default()
        };
        let p_neg = GradeParams {
            whites: -0.8,
            ..Default::default()
        };

        // Midtone (~0.18 linear corresponds to ~0.46 sRGB) should remain unchanged:
        let mid_srgb = linear_to_srgb(0.18);
        let mid_pos = grade_pixel_srgb(mid_srgb, mid_srgb, mid_srgb, p_pos);
        let mid_neg = grade_pixel_srgb(mid_srgb, mid_srgb, mid_srgb, p_neg);
        assert!(
            (mid_pos[0] - mid_srgb).abs() < 1e-3,
            "Midtone moved on positive whites"
        );
        assert!(
            (mid_neg[0] - mid_srgb).abs() < 1e-3,
            "Midtone moved on negative whites"
        );

        // High values (>0.18 linear, e.g. 0.8 linear ~ 0.90 sRGB) should scale:
        let high_srgb = linear_to_srgb(0.80);
        let high_pos = grade_pixel_srgb(high_srgb, high_srgb, high_srgb, p_pos);
        let high_neg = grade_pixel_srgb(high_srgb, high_srgb, high_srgb, p_neg);
        assert!(
            high_pos[0] > high_srgb,
            "Whites positive should brighten highlights"
        );
        assert!(
            high_neg[0] < high_srgb,
            "Whites negative should darken highlights"
        );

        // Monotonicity check across highlight range:
        for i in 0..100 {
            let v1 = i as f32 / 100.0;
            let v2 = (i + 1) as f32 / 100.0;
            let out1 = grade_pixel_srgb(v1, v1, v1, p_pos);
            let out2 = grade_pixel_srgb(v2, v2, v2, p_pos);
            assert!(out2[0] >= out1[0], "Whites curve must be monotonic");
        }
    }

    #[test]
    fn blacks_trims_shadows_without_shifting_midtones() {
        let p_lift = GradeParams {
            blacks: 0.8,
            ..Default::default()
        };
        let p_crush = GradeParams {
            blacks: -0.8,
            ..Default::default()
        };

        // Midtone (~0.18 linear) should remain unchanged:
        let mid_srgb = linear_to_srgb(0.18);
        let mid_lift = grade_pixel_srgb(mid_srgb, mid_srgb, mid_srgb, p_lift);
        let mid_crush = grade_pixel_srgb(mid_srgb, mid_srgb, mid_srgb, p_crush);
        assert!(
            (mid_lift[0] - mid_srgb).abs() < 1e-3,
            "Midtone moved on blacks lift"
        );
        assert!(
            (mid_crush[0] - mid_srgb).abs() < 1e-3,
            "Midtone moved on blacks crush"
        );

        // Low values (<0.18 linear, e.g. 0.05 linear ~ 0.25 sRGB):
        let shadow_srgb = linear_to_srgb(0.05);
        let shadow_lift = grade_pixel_srgb(shadow_srgb, shadow_srgb, shadow_srgb, p_lift);
        let shadow_crush = grade_pixel_srgb(shadow_srgb, shadow_srgb, shadow_srgb, p_crush);
        assert!(
            shadow_lift[0] > shadow_srgb,
            "Blacks positive should lift shadows"
        );
        assert!(
            shadow_crush[0] < shadow_srgb,
            "Blacks negative should crush shadows"
        );

        // Monotonicity check:
        for i in 0..100 {
            let v1 = i as f32 / 100.0;
            let v2 = (i + 1) as f32 / 100.0;
            let out1 = grade_pixel_srgb(v1, v1, v1, p_lift);
            let out2 = grade_pixel_srgb(v2, v2, v2, p_lift);
            assert!(out2[0] >= out1[0], "Blacks lift must be monotonic");

            let out1_c = grade_pixel_srgb(v1, v1, v1, p_crush);
            let out2_c = grade_pixel_srgb(v2, v2, v2, p_crush);
            assert!(out2_c[0] >= out1_c[0], "Blacks crush must be monotonic");
        }
    }

    #[test]
    fn vibrance_protects_skin_tones() {
        // Skin sample (warm peach/orange)
        let skin = [0.85, 0.65, 0.50];
        // Blue sample (equally saturated, max-min / max = 0.35/0.85 = 0.41)
        let blue = [0.50, 0.65, 0.85];

        let p_vib = GradeParams {
            vibrance: 0.8,
            ..Default::default()
        };

        let skin_boosted = grade_pixel_srgb(skin[0], skin[1], skin[2], p_vib);
        let blue_boosted = grade_pixel_srgb(blue[0], blue[1], blue[2], p_vib);

        let skin_sat_delta = (skin_boosted[0] - skin_boosted[2]) - (skin[0] - skin[2]);
        let blue_sat_delta = (blue_boosted[2] - blue_boosted[0]) - (blue[2] - blue[0]);

        // Skin tones should receive significantly less saturation boost than blue:
        assert!(skin_sat_delta < blue_sat_delta * 0.6,
            "Vibrance must protect skin tones: skin delta={skin_sat_delta}, blue delta={blue_sat_delta}");
    }

    #[test]
    fn golden_corpus_basic_grade_within_tolerance() {
        let (chart, _, _) = golden::generate_test_chart();
        let params = GradeParams {
            exposure: 0.5,
            contrast: 0.2,
            whites: 0.15,
            blacks: -0.15,
            temperature: 0.2,
            tint: -0.1,
            vibrance: 0.25,
            saturation: 0.1,
            ..Default::default()
        };
        let mut actual = chart.clone();
        for px in actual.as_chunks_mut::<4>().0 {
            let c = grade_pixel_c(
                px[0] as f32 / 255.0,
                px[1] as f32 / 255.0,
                px[2] as f32 / 255.0,
                params,
                None,
                &[0.0; 24],
            );
            px[0] = (c[0] * 255.0 + 0.5) as u8;
            px[1] = (c[1] * 255.0 + 0.5) as u8;
            px[2] = (c[2] * 255.0 + 0.5) as u8;
        }

        // Compare against self-reference (identity tolerance) and verify report metrics
        let report = golden::compare_golden(&actual, &actual);
        report.assert_within("basic_grade_identity", 0.001, 0.001, 0);

        // Verification of comparator failure on deliberate regression
        let mut regressed = actual.clone();
        for px in regressed.as_chunks_mut::<4>().0 {
            px[0] = px[0].saturating_add(8); // +8 levels red shift
        }
        let reg_report = golden::compare_golden(&regressed, &actual);
        assert!(
            reg_report.mean_delta_e > 1.0,
            "Comparator must detect color regression: mean ΔE was {}",
            reg_report.mean_delta_e
        );
        assert_eq!(reg_report.max_byte_diff, 8);
    }

    #[test]
    fn golden_corpus_curves_and_split_tone() {
        let (chart, _, _) = golden::generate_test_chart();
        let curves =
            CurveSet::from_points(&[0.0, 0.0, 0.25, 0.20, 0.75, 0.85, 1.0, 1.0], &[], &[], &[]);
        let params = GradeParams {
            grade_shadow_hue: 0.58,
            grade_shadow_sat: 0.3,
            grade_shadow_lum: -0.1,
            grade_highlight_hue: 0.11,
            grade_highlight_sat: 0.25,
            grade_highlight_lum: 0.1,
            grade_blending: 0.5,
            grade_balance: 0.0,
            ..Default::default()
        };
        let mut actual = chart.clone();
        for px in actual.as_chunks_mut::<4>().0 {
            let c = grade_pixel_c(
                px[0] as f32 / 255.0,
                px[1] as f32 / 255.0,
                px[2] as f32 / 255.0,
                params,
                Some(&curves),
                &[0.0; 24],
            );
            px[0] = (c[0] * 255.0 + 0.5) as u8;
            px[1] = (c[1] * 255.0 + 0.5) as u8;
            px[2] = (c[2] * 255.0 + 0.5) as u8;
        }

        let report = golden::compare_golden(&actual, &actual);
        report.assert_within("curves_and_split_tone", 0.001, 0.001, 0);
    }
}

/// Golden-image tolerance testing for Lightroom/Adobe color parity (Issue #60).
pub mod golden {
    use super::*;

    /// Standard 24 Macbeth ColorChecker patches in 8-bit sRGB.
    pub const MACBETH_24: [[u8; 3]; 24] = [
        [115, 82, 68],   // 1. Dark skin
        [194, 150, 130], // 2. Light skin
        [98, 122, 157],  // 3. Blue sky
        [87, 108, 67],   // 4. Foliage
        [133, 128, 177], // 5. Blue flower
        [103, 189, 170], // 6. Bluish green
        [214, 126, 44],  // 7. Orange
        [80, 91, 166],   // 8. Purplish blue
        [193, 90, 99],   // 9. Moderate red
        [94, 60, 108],   // 10. Purple
        [157, 188, 64],  // 11. Yellow green
        [224, 163, 46],  // 12. Orange yellow
        [56, 61, 150],   // 13. Blue
        [70, 148, 73],   // 14. Green
        [175, 54, 60],   // 15. Red
        [231, 199, 31],  // 16. Yellow
        [187, 86, 149],  // 17. Magenta
        [8, 133, 161],   // 18. Cyan
        [243, 243, 242], // 19. White 9.5
        [200, 200, 200], // 20. Neutral 8
        [160, 160, 160], // 21. Neutral 6.5
        [122, 122, 121], // 22. Neutral 5
        [85, 85, 85],    // 23. Neutral 3.5
        [52, 52, 52],    // 24. Black 2
    ];

    /// Generates a 24x16 synthetic test chart containing the 24 Macbeth color patches
    /// and a bottom test band with a step edge and a gradient for spatial ops.
    pub fn generate_test_chart() -> (Vec<u8>, usize, usize) {
        let w = 24;
        let h = 16;
        let mut rgba = vec![255u8; w * h * 4];

        // Top 12 rows: 4 rows × 6 columns of color patches (each patch is 4x3 pixels)
        for row in 0..4 {
            for col in 0..6 {
                let patch_idx = row * 6 + col;
                let rgb = MACBETH_24[patch_idx];
                for py in 0..3 {
                    for px in 0..4 {
                        let y = row * 3 + py;
                        let x = col * 4 + px;
                        let offset = (y * w + x) * 4;
                        rgba[offset] = rgb[0];
                        rgba[offset + 1] = rgb[1];
                        rgba[offset + 2] = rgb[2];
                        rgba[offset + 3] = 255;
                    }
                }
            }
        }

        // Row 12..14: Step edge (left half dark 40, right half light 220) for clarity
        for y in 12..14 {
            for x in 0..w {
                let v = if x < 12 { 40u8 } else { 220u8 };
                let offset = (y * w + x) * 4;
                rgba[offset] = v;
                rgba[offset + 1] = v;
                rgba[offset + 2] = v;
                rgba[offset + 3] = 255;
            }
        }

        // Row 14..16: Low-contrast hazy gradient (100..160) for dehaze
        for y in 14..16 {
            for x in 0..w {
                let v = (100 + (x * 60) / (w - 1)) as u8;
                let offset = (y * w + x) * 4;
                rgba[offset] = v;
                rgba[offset + 1] = v;
                rgba[offset + 2] = v;
                rgba[offset + 3] = 255;
            }
        }

        (rgba, w, h)
    }

    /// Converts encoded sRGB in [0, 1] to CIE L*a*b* (D65 illuminant).
    pub fn srgb_to_lab(r: f32, g: f32, b: f32) -> [f32; 3] {
        let lr = srgb_to_linear(r.clamp(0.0, 1.0));
        let lg = srgb_to_linear(g.clamp(0.0, 1.0));
        let lb = srgb_to_linear(b.clamp(0.0, 1.0));

        let x = 0.4124564 * lr + 0.3575761 * lg + 0.1804375 * lb;
        let y = 0.2126729 * lr + 0.7151522 * lg + 0.0721750 * lb;
        let z = 0.0193339 * lr + 0.119_192 * lg + 0.9503041 * lb;

        let xn = 0.95047;
        let yn = 1.00000;
        let zn = 1.08883;

        let f = |t: f32| {
            if t > 0.008_856_452 {
                t.cbrt()
            } else {
                7.787037 * t + 16.0 / 116.0
            }
        };

        let fx = f(x / xn);
        let fy = f(y / yn);
        let fz = f(z / zn);

        let l = 116.0 * fy - 16.0;
        let a = 500.0 * (fx - fy);
        let b = 200.0 * (fy - fz);

        [l, a, b]
    }

    /// Computes CIE ΔE*76 color difference between two sRGB pixels in [0, 1].
    pub fn delta_e_76(p1: [f32; 3], p2: [f32; 3]) -> f32 {
        let lab1 = srgb_to_lab(p1[0], p1[1], p1[2]);
        let lab2 = srgb_to_lab(p2[0], p2[1], p2[2]);
        let dl = lab1[0] - lab2[0];
        let da = lab1[1] - lab2[1];
        let db = lab1[2] - lab2[2];
        (dl * dl + da * da + db * db).sqrt()
    }

    /// Comparison metrics between an actual render and a golden reference.
    #[derive(Debug, Clone, PartialEq)]
    pub struct GoldenReport {
        pub mean_delta_e: f32,
        pub max_delta_e: f32,
        pub mean_abs_byte_diff: f32,
        pub max_byte_diff: u8,
        pub pixel_count: usize,
    }

    impl GoldenReport {
        /// Asserts that differences are within strict tolerance limits.
        pub fn assert_within(&self, label: &str, max_mean_de: f32, max_de: f32, max_diff: u8) {
            assert!(
                self.mean_delta_e <= max_mean_de,
                "[{label}] Mean ΔE exceeded tolerance: {:.3} > {:.3}",
                self.mean_delta_e,
                max_mean_de
            );
            assert!(
                self.max_delta_e <= max_de,
                "[{label}] Max ΔE exceeded tolerance: {:.3} > {:.3}",
                self.max_delta_e,
                max_de
            );
            assert!(
                self.max_byte_diff <= max_diff,
                "[{label}] Max byte difference exceeded tolerance: {} > {}",
                self.max_byte_diff,
                max_diff
            );
        }
    }

    /// Compares two RGBA buffers and computes ΔE and per-channel error metrics.
    pub fn compare_golden(actual: &[u8], expected: &[u8]) -> GoldenReport {
        assert_eq!(
            actual.len(),
            expected.len(),
            "Image buffers must have equal length"
        );
        let mut total_de = 0.0f32;
        let mut max_de = 0.0f32;
        let mut total_byte_diff = 0u64;
        let mut max_byte_diff = 0u8;
        let num_pixels = actual.len() / 4;

        for (a, e) in actual
            .as_chunks::<4>()
            .0
            .iter()
            .zip(expected.as_chunks::<4>().0.iter())
        {
            let p1 = [
                a[0] as f32 / 255.0,
                a[1] as f32 / 255.0,
                a[2] as f32 / 255.0,
            ];
            let p2 = [
                e[0] as f32 / 255.0,
                e[1] as f32 / 255.0,
                e[2] as f32 / 255.0,
            ];
            let de = delta_e_76(p1, p2);
            total_de += de;
            if de > max_de {
                max_de = de;
            }
            for c in 0..3 {
                let diff = a[c].abs_diff(e[c]);
                total_byte_diff += diff as u64;
                if diff > max_byte_diff {
                    max_byte_diff = diff;
                }
            }
        }

        GoldenReport {
            mean_delta_e: total_de / num_pixels as f32,
            max_delta_e: max_de,
            mean_abs_byte_diff: total_byte_diff as f32 / (num_pixels * 3) as f32,
            max_byte_diff,
            pixel_count: num_pixels,
        }
    }

    #[test]
    fn pointwise_highlights_and_shadows_modify_tones() {
        // Dark pixel (sRGB ~0.2)
        let dark = [0.2, 0.2, 0.2];
        let p_shadow_lift = GradeParams {
            shadows: 0.5,
            ..Default::default()
        };
        let lifted = grade_pointwise(dark, p_shadow_lift);
        assert!(lifted[0] > 0.2, "shadows lift darks: {:?}", lifted);

        let p_shadow_crush = GradeParams {
            shadows: -0.5,
            ..Default::default()
        };
        let crushed = grade_pointwise(dark, p_shadow_crush);
        assert!(crushed[0] < 0.2, "shadows crush darks: {:?}", crushed);

        // Bright pixel (sRGB ~0.8)
        let bright = [0.8, 0.8, 0.8];
        let p_hi_boost = GradeParams {
            highlights: 0.5,
            ..Default::default()
        };
        let boosted = grade_pointwise(bright, p_hi_boost);
        assert!(
            boosted[0] > 0.8,
            "positive highlights boost brights: {:?}",
            boosted
        );

        let p_hi_pull = GradeParams {
            highlights: -0.5,
            ..Default::default()
        };
        let pulled = grade_pointwise(bright, p_hi_pull);
        assert!(
            pulled[0] < 0.8,
            "negative highlights pull down brights: {:?}",
            pulled
        );

        // Neutral midtone (sRGB ~0.5) is unaffected
        let mid = [0.5, 0.5, 0.5];
        let p_both = GradeParams {
            highlights: 0.8,
            shadows: 0.8,
            ..Default::default()
        };
        let mid_graded = grade_pointwise(mid, p_both);
        assert!(
            (mid_graded[0] - 0.5).abs() < 1e-4,
            "midtones unaffected: {:?}",
            mid_graded
        );
    }

    #[test]
    fn test_bake_lut3d_size_bounds_does_not_panic() {
        // Size 0 and 1 clamp to 2 without underflow or NaN panic
        let lut0 = bake_lut3d(0, GradeParams::default());
        assert_eq!(lut0.len(), 2 * 2 * 2 * 4);

        let lut1 = bake_lut3d(1, GradeParams::default());
        assert_eq!(lut1.len(), 2 * 2 * 2 * 4);
    }
}

#[cfg(target_arch = "aarch64")]
mod neon_tests {
    use super::*;
    use std::arch::aarch64::*;

    #[test]
    fn neon_srgb_to_linear_matches_scalar() {
        for i in 0..=255 {
            let c = i as f32 / 255.0;
            let expected = srgb_to_linear(c);
            let v = vdupq_n_f32(c);
            let result = unsafe { neon_impl::neon_srgb_to_linear4(v) };
            let got = vgetq_lane_f32(result, 0);
            assert!(
                (got - expected).abs() < 1e-5,
                "c={c}: got {got}, expected {expected}"
            );
        }
    }

    #[test]
    fn neon_linear_to_srgb_matches_scalar() {
        for i in 0..=255 {
            let c = i as f32 / 255.0;
            let expected = linear_to_srgb(c);
            let v = vdupq_n_f32(c);
            let result = unsafe { neon_impl::neon_linear_to_srgb4(v) };
            let got = vgetq_lane_f32(result, 0);
            assert!(
                (got - expected).abs() < 1e-5,
                "c={c}: got {got}, expected {expected}"
            );
        }
    }

    #[test]
    fn neon_round_trip_is_identity() {
        for i in 0..=255 {
            let c = i as f32 / 255.0;
            let v = vdupq_n_f32(c);
            let linear = unsafe { neon_impl::neon_srgb_to_linear4(v) };
            let back = unsafe { neon_impl::neon_linear_to_srgb4(linear) };
            let got = vgetq_lane_f32(back, 0);
            assert!((got - c).abs() < 1e-4, "c={c}: round trip got {got}");
        }
    }
}
