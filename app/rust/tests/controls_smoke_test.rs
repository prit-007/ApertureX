//! Controls regression smoke test (#batch fix: Whites/Blacks dead, Highlights
//! inverted, "every control works" ask).
//!
//! Loads a real RAW fixture once, then drives each user-facing control through
//! the *same* Rust math the preview LUT and the export share
//! (`grade_pixel_srgb` + the `spatial` ops) and asserts the image moves in the
//! direction the slider promises. This is deliberately directional, not
//! golden-pixel: any wiring/sign regression (e.g. `highlights` inverted again,
//! or `whites`/`blacks` silently ignored) fails immediately.

#![allow(
    clippy::chunks_exact_to_as_chunks,
    clippy::needless_borrow,
    clippy::four_forward_slashes
)]

use std::fs;
use std::path::Path;

use rust_lib_aperturex::api::raw::decode_raw_roi;
use rust_lib_aperturex::blur::{apply_lens_blur, BokehShape, LensBlurParams};
use rust_lib_aperturex::color::{grade_pixel_srgb, srgb_to_linear, GradeParams};
use rust_lib_aperturex::spatial::{
    apply_clarity, apply_sharpen_advanced, apply_texture, denoise, grain, vignette,
};
use rust_lib_aperturex::watermark::decode_png_rgba;

/// Decodes a purpose-built mid-grey patch out of the synthetic math-breaker PNG.
///
/// The fixture is a 2048² grid of ramps/checkerboards over a black background.
/// Its horizontal 8-bit ramp lives at roughly y∈[128,192), x∈[128,1920) with
/// values spanning ~8..246 — i.e. a wide, mid-grey band with headroom in both
/// directions and no clipped whites. That makes it the right probe for
/// exposure, which must move linear light by exactly ×2^ev; a bright RAW
/// region that clips at 255 saturates under +1 EV and can appear not to
/// brighten at all. Used only where the assertion is about the *math*, not
/// about photographic content.
fn load_png_roi() -> Option<(Vec<u8>, usize, usize)> {
    let fixture = Path::new("tests/golden_fixtures/synthetic_math_breaker.png");
    if !fixture.exists() {
        return None;
    }
    let bytes = fs::read(fixture).ok()?;
    let (rgba, fw, fh) = decode_png_rgba(&bytes).ok()?;
    // The math ramp: rows y in [128,256) carry a horizontal 0..255 ramp across
    // x in [~512,1792]. Cropping the full span gives true darks AND true
    // brights: the dark band falls below the 0.18 midtone anchor (blacks
    // trim applies) and the bright band sits in real highlight headroom
    // (whites trim applies) instead of sRGB's compressed shoulder.
    let (ox, oy, w, h) = (512usize, 128usize, 1280usize, 128usize);
    if (fw as usize) < ox + w || (fh as usize) < oy + h {
        return None;
    }
    let mut out = Vec::with_capacity(w * h * 4);
    for y in oy..oy + h {
        let row = (y * fw as usize) * 4;
        let start = row + ox * 4;
        out.extend_from_slice(&rgba[start..start + w * 4]);
    }
    Some((out, w, h))
}

/// Decodes a real 256×256 ROI from the CR2 fixture (skips if absent).
fn load_roi() -> Option<(Vec<u8>, usize, usize)> {
    let fixture = Path::new("tests/golden_fixtures/image_1.CR2");
    if !fixture.exists() {
        return None;
    }
    let bytes = fs::read(fixture).ok()?;
    // Pick the ROI whose mean luma sits nearest mid-grey (0.5) so exposure /
    // highlights / shadows all have headroom in both directions.
    let mut best: Option<(Vec<u8>, usize, usize, f32)> = None;
    for (ox, oy) in [(0, 0), (200, 200), (400, 300), (300, 500), (600, 200)] {
        let Ok(roi) = decode_raw_roi(bytes.clone(), ox, oy, 256, 256) else {
            continue;
        };
        let m = mean_luma(&roi.rgba);
        let score = (m - 0.5).abs();
        if best.as_ref().map(|b| score < b.3).unwrap_or(true) {
            best = Some((roi.rgba, roi.width as usize, roi.height as usize, score));
        }
    }
    best.map(|(rgba, w, h, _)| (rgba, w, h))
}

fn luma_of(r: u8, g: u8, b: u8) -> f32 {
    (0.2126 * r as f32 + 0.7152 * g as f32 + 0.0722 * b as f32) / 255.0
}

fn mean_luma(rgba: &[u8]) -> f32 {
    let mut sum = 0.0f32;
    let mut n = 0usize;
    for px in rgba.chunks_exact(4) {
        sum += luma_of(px[0], px[1], px[2]);
        n += 1;
    }
    sum / n as f32
}

/// Mean luma in **linear** light. Exposure, whites and blacks are multiplicative
/// / additive in linear light, so directional assertions for those controls are
/// far more robust here than against the perceptually-compressed encoded luma
/// (which barely moves on a bright, highlight-clipping ROI — the same
/// encoded-vs-linear confusion that once inverted Highlights).
fn mean_linear_luma(rgba: &[u8]) -> f32 {
    let mut sum = 0.0f32;
    let mut n = 0usize;
    for px in rgba.chunks_exact(4) {
        sum += 0.2126 * srgb_to_linear(px[0] as f32 / 255.0)
            + 0.7152 * srgb_to_linear(px[1] as f32 / 255.0)
            + 0.0722 * srgb_to_linear(px[2] as f32 / 255.0);
        n += 1;
    }
    sum / n as f32
}

/// (dark_mask, bright_mask): bottom / top quartile of the *baseline* luma.
fn quartile_masks(rgba: &[u8]) -> (Vec<bool>, Vec<bool>) {
    let lumas: Vec<f32> = rgba
        .chunks_exact(4)
        .map(|px| luma_of(px[0], px[1], px[2]))
        .collect();
    let mut sorted = lumas.clone();
    sorted.sort_by(f32::total_cmp);
    let lo = sorted[sorted.len() / 4];
    let hi = sorted[(sorted.len() * 3) / 4];
    (
        lumas.iter().map(|l| *l <= lo).collect(),
        lumas.iter().map(|l| *l >= hi).collect(),
    )
}

/// Mean luma (encoded sRGB) over a masked band — used for perceptual controls
/// (highlights/shadows) whose delta is defined on the encoded curve.
fn band_mean_luma(rgba: &[u8], mask: &[bool]) -> f32 {
    let mut sum = 0.0f32;
    let mut n = 0usize;
    for (px, keep) in rgba.chunks_exact(4).zip(mask) {
        if *keep {
            sum += luma_of(px[0], px[1], px[2]);
            n += 1;
        }
    }
    assert!(n > 0, "band mask selected no pixels");
    sum / n as f32
}

fn mean_rb_delta(rgba: &[u8]) -> f32 {
    let (mut r, mut b, mut n) = (0.0f32, 0.0f32, 0usize);
    for px in rgba.chunks_exact(4) {
        r += px[0] as f32;
        b += px[2] as f32;
        n += 1;
    }
    (r - b) / (n as f32 * 255.0)
}

fn mean_magenta_delta(rgba: &[u8]) -> f32 {
    let (mut s, mut n) = (0.0f32, 0usize);
    for px in rgba.chunks_exact(4) {
        let mid = (px[0] as f32 + px[2] as f32) / 2.0;
        s += (mid - px[1] as f32) / 255.0;
        n += 1;
    }
    s / n as f32
}

fn mean_chroma(rgba: &[u8]) -> f32 {
    let (mut s, mut n) = (0.0f32, 0usize);
    for px in rgba.chunks_exact(4) {
        let (r, g, b) = (px[0] as f32, px[1] as f32, px[2] as f32);
        s += (r.max(g).max(b) - r.min(g).min(b)) / 255.0;
        n += 1;
    }
    s / n as f32
}

/// High-frequency energy: mean horizontal |Δluma| — rises with sharpen/grain
////texture, falls with denoise/blur.
fn hf_energy(rgba: &[u8], w: usize) -> f32 {
    let mut s = 0.0f32;
    let mut n = 0usize;
    for y in 0..(rgba.len() / 4 / w) {
        for x in 0..(w - 1) {
            let i = (y * w + x) * 4;
            let a = luma_of(rgba[i], rgba[i + 1], rgba[i + 2]);
            let bl = luma_of(rgba[i + 4], rgba[i + 5], rgba[i + 6]);
            s += (a - bl).abs();
            n += 1;
        }
    }
    s / n as f32
}

/// Mean luma over a 10% border ring (vignette probes).
fn corner_mean_luma(rgba: &[u8], w: usize, h: usize) -> f32 {
    let (mx, my) = ((w * 10 / 100).max(1), (h * 10 / 100).max(1));
    let (mut s, mut n) = (0.0f32, 0usize);
    for y in 0..h {
        for x in 0..w {
            if x < mx || x >= w - mx || y < my || y >= h - my {
                let i = (y * w + x) * 4;
                s += luma_of(rgba[i], rgba[i + 1], rgba[i + 2]);
                n += 1;
            }
        }
    }
    s / n as f32
}

fn grade_rgba(rgba: &[u8], params: GradeParams) -> Vec<u8> {
    rgba.chunks_exact(4)
        .flat_map(|px| {
            let out = grade_pixel_srgb(
                px[0] as f32 / 255.0,
                px[1] as f32 / 255.0,
                px[2] as f32 / 255.0,
                params,
            );
            let mut v: Vec<u8> = out
                .iter()
                .map(|c| (c * 255.0).round().clamp(0.0, 255.0) as u8)
                .collect();
            v.push(px[3]);
            v
        })
        .collect()
}

#[test]
fn every_control_moves_a_real_photo_in_the_direction_the_slider_promises() {
    let Some((rgba, w, h)) = load_roi() else {
        eprintln!("Skipping controls smoke test: tests/golden_fixtures/image_1.CR2 not found");
        return;
    };
    let (dark, bright) = quartile_masks(&rgba);

    let base_bright = band_mean_luma(&rgba, &bright);
    let base_hf = hf_energy(&rgba, w);
    let base_rb = mean_rb_delta(&rgba);

    // Synthetic math-breaker ramp (full 0..255 tonal range). The CR2 fixture
    // was chosen for mid-grey and has a near-black floor, so its dark band
    // cannot crush further under negative shadows; exposure likewise needs true
    // mid-grey headroom to see the ×2^ev ratio. This probe supplies both.
    let png_probe = load_png_roi();

    // --- Tone -----------------------------------------------------------------

    // Exposure moves overall brightness both ways. Measured on the synthetic
    // math-breaker PNG's mid-grey ramp strip: it has headroom in both
    // directions, so +1 EV cannot clip at 255 and hide the brightening (which
    // is what a clipped RAW region does). A raw fixture has no mid-grey
    // pixels at all, so the exact ×2^ev ratio can only be probed here.
    {
        let Some((prgba, _pw, _ph)) = png_probe.as_ref() else {
            eprintln!(
                "Skipping exposure probe: tests/golden_fixtures/synthetic_math_breaker.png not found"
            );
            return;
        };
        // Compare in float space: rounding to u8 first quantizes a dark linear
        // value enough to bend the ratio off 0.5 and mask a real wiring bug.
        let mut checked = 0usize;
        for a in prgba.chunks_exact(4) {
            // Only mid-range, near-neutral pixels: away from both clips so the
            // ratio is exact, and low chroma so all channels track together.
            let (r0, g0, b0) = (
                a[0] as f32 / 255.0,
                a[1] as f32 / 255.0,
                a[2] as f32 / 255.0,
            );
            let chroma = r0.max(g0).max(b0) - r0.min(g0).min(b0);
            if !(0.25..=0.75).contains(&r0) || chroma > 0.04 {
                continue;
            }
            let lin_in = srgb_to_linear(r0);
            let out = grade_pixel_srgb(
                r0,
                g0,
                b0,
                GradeParams {
                    exposure: -1.0,
                    ..Default::default()
                },
            );
            let lin_out = srgb_to_linear(out[0]);
            assert!(
                (lin_out - lin_in * 0.5).abs() < 2e-4,
                "exposure -1.0 must halve linear mid value: in {:.6} -> out {:.6}",
                lin_in,
                lin_out
            );
            checked += 1;
            if checked >= 64 {
                break;
            }
        }
        assert!(
            checked > 0,
            "synthetic fixture has no mid-grey pixels to probe exposure against \
             (sample R/G/B: {:?})",
            prgba
                .chunks_exact(4)
                .take(8)
                .map(|p| (p[0], p[1], p[2]))
                .collect::<Vec<_>>()
        );

        let base_linear = mean_linear_luma(&prgba);
        let up = grade_rgba(
            &prgba,
            GradeParams {
                exposure: 1.0,
                ..Default::default()
            },
        );
        let down = grade_rgba(
            &prgba,
            GradeParams {
                exposure: -1.0,
                ..Default::default()
            },
        );
        let lin_up = mean_linear_luma(&up);
        let lin_down = mean_linear_luma(&down);
        assert!(
            lin_up > base_linear * 1.5,
            "exposure +1.0 must brighten linearly: {} vs {}",
            lin_up,
            base_linear
        );
        assert!(
            lin_down < base_linear * 0.7,
            "exposure -1.0 must darken linearly: {} vs {}",
            lin_down,
            base_linear
        );
    }

    // Contrast widens the tonal spread.
    let contrasted = grade_rgba(
        &rgba,
        GradeParams {
            contrast: 0.6,
            ..Default::default()
        },
    );
    let std = |px: &[u8]| {
        let m = mean_luma(px);
        (px.chunks_exact(4)
            .map(|p| (luma_of(p[0], p[1], p[2]) - m).powi(2))
            .sum::<f32>()
            / (px.len() / 4) as f32)
            .sqrt()
    };
    assert!(
        std(&contrasted) > std(&rgba) + 1e-4,
        "contrast +0.6 must widen the tonal spread"
    );

    // Highlights: positive brightens the brights, negative recovers them
    // (regression: the spatial path once inverted this, issue #94).
    let hl_pos = grade_rgba(
        &rgba,
        GradeParams {
            highlights: 0.6,
            ..Default::default()
        },
    );
    let hl_neg = grade_rgba(
        &rgba,
        GradeParams {
            highlights: -0.6,
            ..Default::default()
        },
    );
    assert!(
        band_mean_luma(&hl_pos, &bright) > base_bright + 0.004,
        "highlights +0.6 must brighten the bright band"
    );
    assert!(
        band_mean_luma(&hl_neg, &bright) < base_bright - 0.004,
        "highlights -0.6 must recover the bright band"
    );

    // Shadows lift / crush the dark band. Measured on the synthetic ramp: the
    // CR2 fixture's dark band sits on a near-black floor that cannot crush
    // further, so its negative-shadows delta is too small to assert against.
    let (sh_rgba, sh_dark) = match png_probe.as_ref() {
        Some((p, _, _)) => {
            let m = quartile_masks(p);
            ((*p).clone(), m.0)
        }
        None => (rgba.clone(), dark.clone()),
    };
    let sh_base = band_mean_luma(&sh_rgba, &sh_dark);
    let sh_pos = grade_rgba(
        &sh_rgba,
        GradeParams {
            shadows: 0.6,
            ..Default::default()
        },
    );
    let sh_neg = grade_rgba(
        &sh_rgba,
        GradeParams {
            shadows: -0.6,
            ..Default::default()
        },
    );
    assert!(
        band_mean_luma(&sh_pos, &sh_dark) > sh_base + 0.004,
        "shadows +0.6 must lift the dark band"
    );
    assert!(
        band_mean_luma(&sh_neg, &sh_dark) < sh_base - 0.004,
        "shadows -0.6 must crush the dark band: base_dark={:.5} sh_neg={:.5}",
        sh_base,
        band_mean_luma(&sh_neg, &sh_dark)
    );

    // Whites: linear white-point trim anchored at the midtone ~0.18, applied
    // only above that anchor. On the CR2 ROI's bright band (already near white)
    // a positive trim lands entirely in sRGB's compressed shoulder, where u8
    // rounding erases it; the synthetic ramp has true mid-highlight headroom.
    let (wh_rgba, wh_bright) = match png_probe.as_ref() {
        Some((p, _, _)) => {
            let m = quartile_masks(p);
            ((*p).clone(), m.1)
        }
        None => (rgba.clone(), bright.clone()),
    };
    let wh_base = band_mean_luma(&wh_rgba, &wh_bright);
    let wh_pos = grade_rgba(
        &wh_rgba,
        GradeParams {
            whites: 0.6,
            ..Default::default()
        },
    );
    let wh_neg = grade_rgba(
        &wh_rgba,
        GradeParams {
            whites: -0.6,
            ..Default::default()
        },
    );
    assert!(
        band_mean_luma(&wh_pos, &wh_bright) > wh_base + 0.003,
        "whites +0.6 must lift the bright band: base_bright={:.5} wh_pos={:.5}",
        wh_base,
        band_mean_luma(&wh_pos, &wh_bright)
    );
    assert!(
        band_mean_luma(&wh_neg, &wh_bright) < wh_base - 0.003,
        "whites -0.6 must trim the bright band: base_bright={:.5} wh_neg={:.5}",
        wh_base,
        band_mean_luma(&wh_neg, &wh_bright)
    );

    // Blacks: linear black-point trim anchored at the midtone ~0.18. The trim
    // only touches pixels below that anchor, so it needs a fixture with real
    // near-black content — the CR2 ROI's bottom quartile sits at linear ~0.24
    // (above the anchor) and would be a legitimate no-op there. The synthetic
    // ramp spans the full range, so its bottom quartile falls below 0.18.
    let (bl_rgba, bl_dark) = match png_probe.as_ref() {
        Some((p, _, _)) => {
            let m = quartile_masks(p);
            ((*p).clone(), m.0)
        }
        None => (rgba.clone(), dark.clone()),
    };
    let bl_base = band_mean_luma(&bl_rgba, &bl_dark);
    let bl_pos = grade_rgba(
        &bl_rgba,
        GradeParams {
            blacks: 0.6,
            ..Default::default()
        },
    );
    let bl_neg = grade_rgba(
        &bl_rgba,
        GradeParams {
            blacks: -0.6,
            ..Default::default()
        },
    );
    assert!(
        band_mean_luma(&bl_pos, &bl_dark) > bl_base + 0.002,
        "blacks +0.6 must lift the dark band"
    );
    assert!(
        band_mean_luma(&bl_neg, &bl_dark) < bl_base - 0.002,
        "blacks -0.6 must crush the dark band: base_dark={:.5} bl_neg={:.5}",
        bl_base,
        band_mean_luma(&bl_neg, &bl_dark)
    );

    // --- Color ----------------------------------------------------------------

    // Temperature: warm > 0 pushes red over blue.
    let warm = grade_rgba(
        &rgba,
        GradeParams {
            temperature: 0.6,
            ..Default::default()
        },
    );
    let cool = grade_rgba(
        &rgba,
        GradeParams {
            temperature: -0.6,
            ..Default::default()
        },
    );
    assert!(
        mean_rb_delta(&warm) > base_rb + 0.005,
        "temperature +0.6 must warm"
    );
    assert!(
        mean_rb_delta(&cool) < base_rb - 0.005,
        "temperature -0.6 must cool"
    );

    // Tint: magenta > 0 pushes green down against red/blue. Probed on the
    // synthetic neutral ramp: the CR2 ROI is packed with clipped magenta pixels
    // (r=b=255, g near 0) where the (r+b)/2 − g metric is saturated — green
    // cannot fall further and r/b cannot rise, so even a correct tint direction
    // reads as a decrease. The ramp is neutral, so the metric has headroom both
    // ways and tint +0.6 must raise it (verified: ~+0.01 mean on this content).
    let base_mag = mean_magenta_delta(&rgba);
    let (tint_rgba, tint_base) = match png_probe.as_ref() {
        Some((p, _, _)) => ((*p).clone(), mean_magenta_delta(p)),
        None => (rgba.clone(), base_mag),
    };
    let magenta = grade_rgba(
        &tint_rgba,
        GradeParams {
            tint: 0.6,
            ..Default::default()
        },
    );
    let greenish = grade_rgba(
        &tint_rgba,
        GradeParams {
            tint: -0.6,
            ..Default::default()
        },
    );
    assert!(
        mean_magenta_delta(&magenta) > tint_base + 0.004,
        "tint +0.6 must go magenta: base={:.5} magenta={:.5} greenish={:.5}",
        tint_base,
        mean_magenta_delta(&magenta),
        mean_magenta_delta(&greenish)
    );
    assert!(
        mean_magenta_delta(&greenish) < tint_base - 0.004,
        "tint -0.6 must go green"
    );

    // Saturation / vibrance increase chroma.
    let base_chroma = mean_chroma(&rgba);
    let sat_up = grade_rgba(
        &rgba,
        GradeParams {
            saturation: 0.6,
            ..Default::default()
        },
    );
    assert!(
        mean_chroma(&sat_up) > base_chroma + 0.005,
        "saturation +0.6 must add chroma"
    );
    let vib_up = grade_rgba(
        &rgba,
        GradeParams {
            vibrance: 0.8,
            ..Default::default()
        },
    );
    assert!(
        mean_chroma(&vib_up) > base_chroma + 0.002,
        "vibrance +0.8 must add chroma"
    );

    // --- Detail / optical ------------------------------------------------------

    // Clarity, texture, sharpening: high-frequency energy rises.
    let clarity = apply_clarity(&rgba, w, h, 0.7);
    assert!(
        hf_energy(&clarity, w) > base_hf + 1e-4,
        "clarity +0.7 must raise local contrast"
    );
    let texture = apply_texture(&rgba, w, h, 0.7);
    assert!(
        hf_energy(&texture, w) > base_hf + 1e-5,
        "texture +0.7 must raise fine detail energy"
    );
    let sharpened = apply_sharpen_advanced(&rgba, w, h, 0.8, 1.0, 0.5, 0.2);
    assert!(
        hf_energy(&sharpened, w) > base_hf + 1e-4,
        "sharpen must raise edge energy"
    );

    // Denoise: noise (high-frequency energy) drops.
    let smooth = denoise(&rgba, w, h, 0.7, 0.6);
    assert!(
        hf_energy(&smooth, w) < base_hf - 1e-4,
        "denoise must suppress high-frequency noise"
    );

    // Grain: deterministic high-frequency energy rises.
    let grained = grain(&rgba, w, h, 0.6);
    assert!(
        hf_energy(&grained, w) > base_hf + 1e-4,
        "grain +0.6 must add high-frequency energy"
    );

    // Vignette: positive amount darkens the border ring (Rust contract:
    // "darkens (amount > 0) or lightens (amount < 0) toward the corners").
    let base_corner = corner_mean_luma(&rgba, w, h);
    let vig = vignette(&rgba, w, h, 0.8);
    assert!(
        corner_mean_luma(&vig, w, h) < base_corner - 0.01,
        "vignette +0.8 must darken the corners"
    );

    // Lens blur smooths the frame (depth-free synthetic focal plane).
    let blurred = apply_lens_blur(
        &rgba,
        w,
        h,
        LensBlurParams {
            enabled: true,
            amount: 0.7,
            focal_point: 0.5,
            focal_range: 0.15,
            bokeh_shape: BokehShape::Hexagon,
            bokeh_boost: 0.2,
        },
        None,
        36,
    );
    assert!(
        hf_energy(&blurred, w) < base_hf - 1e-3,
        "lens blur must smooth the frame"
    );
}
