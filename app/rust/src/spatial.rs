//! Spatial (neighbour-aware) operations (P2). These cannot live in the
//! per-pixel LUT, so they run as their own pass.
//!
//! Every op is a function over a full RGBA buffer. The preview/export tile
//! engine must call them through [`process_tile_padded`], which fetches a
//! margin of neighbour pixels and crops it off afterwards — otherwise blur-based
//! ops leave visible seams at tile boundaries (ADR 0011).

/// Separable box blur of one channel (horizontal then vertical), edge-clamped.
///
/// Uses prefix sums so each output pixel costs **O(1)** regardless of radius —
/// a large clarity/sharpen radius stays fast on the preview proxy.
fn box_blur_1d(src: &[f32], w: usize, h: usize, radius: usize) -> Vec<f32> {
    if radius == 0 {
        return src.to_vec();
    }
    let mut tmp = vec![0f32; w * h];
    // The prefix accumulator is `f64`: it is the only place summation order (and
    // therefore the region origin) could perturb the result, and a wider
    // accumulator keeps banded tiles bit-comparable to the full-frame pass. The
    // pixel buffers stay `f32` — the accumulator is one row/column, not a frame.
    let mut prefix = vec![0f64; w.max(h) + 1];
    // Horizontal pass.
    for y in 0..h {
        let row = y * w;
        prefix[0] = 0.0;
        for x in 0..w {
            prefix[x + 1] = prefix[x] + src[row + x] as f64;
        }
        for x in 0..w {
            let lo = x.saturating_sub(radius);
            let hi = (x + radius).min(w - 1);
            tmp[row + x] = ((prefix[hi + 1] - prefix[lo]) / (hi - lo + 1) as f64) as f32;
        }
    }
    // Vertical pass.
    let mut out = vec![0f32; w * h];
    for x in 0..w {
        prefix[0] = 0.0;
        for y in 0..h {
            prefix[y + 1] = prefix[y] + tmp[y * w + x] as f64;
        }
        for y in 0..h {
            let lo = y.saturating_sub(radius);
            let hi = (y + radius).min(h - 1);
            out[y * w + x] = ((prefix[hi + 1] - prefix[lo]) / (hi - lo + 1) as f64) as f32;
        }
    }
    out
}

/// Box-blurs the RGB channels of an RGBA buffer, preserving alpha. Three
/// iterations approximate a Gaussian.
pub fn blur_rgb(src: &[u8], w: usize, h: usize, radius: usize, iterations: usize) -> Vec<u8> {
    let n = w * h;
    let mut out = src.to_vec();
    for c in 0..3 {
        let mut buf: Vec<f32> = (0..n).map(|i| src[i * 4 + c] as f32).collect();
        for _ in 0..iterations {
            buf = box_blur_1d(&buf, w, h, radius);
        }
        for i in 0..n {
            out[i * 4 + c] = buf[i].clamp(0.0, 255.0) as u8;
        }
    }
    out
}

/// `out = src + (src - blur(src)) * amount` — the shared unsharp form. `amount`
/// > 0 adds local contrast; the luma is unaffected where the image is flat.
fn unsharp(src: &[u8], base: &[u8], amount: f32) -> Vec<u8> {
    let mut out = src.to_vec();
    for i in 0..src.len() / 4 {
        for c in 0..3 {
            let o = src[i * 4 + c] as f32;
            let b = base[i * 4 + c] as f32;
            out[i * 4 + c] = (o + (o - b) * amount).clamp(0.0, 255.0) as u8;
        }
    }
    out
}

/// Texture: fine-detail (high-frequency) boost — small blur radius.
pub fn apply_texture(rgba: &[u8], w: usize, h: usize, amount: f32) -> Vec<u8> {
    if amount == 0.0 {
        return rgba.to_vec();
    }
    unsharp(rgba, &blur_rgb(rgba, w, h, 2, 1), amount)
}

/// Guided filter for a single channel `src` using `guide` as the guidance image.
///
/// Implements He, Sun, Tang (ECCV 2010 / TPAMI 2013) with an O(1) separable box
/// blur backbone. Edge-preserving smoothing that eliminates halos around
/// high-contrast boundaries.
pub fn guided_filter_channel(
    guide: &[f32],
    src: &[f32],
    w: usize,
    h: usize,
    radius: usize,
    eps: f32,
) -> Vec<f32> {
    if radius == 0 || w == 0 || h == 0 {
        return src.to_vec();
    }
    let n = w * h;
    let mean_i = box_blur_1d(guide, w, h, radius);
    let mean_p = box_blur_1d(src, w, h, radius);

    let mut ip = vec![0.0f32; n];
    let mut ii = vec![0.0f32; n];
    for i in 0..n {
        ip[i] = guide[i] * src[i];
        ii[i] = guide[i] * guide[i];
    }
    let mean_ip = box_blur_1d(&ip, w, h, radius);
    let mean_ii = box_blur_1d(&ii, w, h, radius);

    let mut a = vec![0.0f32; n];
    let mut b = vec![0.0f32; n];
    for i in 0..n {
        let var_i = (mean_ii[i] - mean_i[i] * mean_i[i]).max(0.0);
        let cov_ip = mean_ip[i] - mean_i[i] * mean_p[i];
        let a_val = cov_ip / (var_i + eps);
        let b_val = mean_p[i] - a_val * mean_i[i];
        a[i] = a_val;
        b[i] = b_val;
    }

    let mean_a = box_blur_1d(&a, w, h, radius);
    let mean_b = box_blur_1d(&b, w, h, radius);

    let mut q = vec![0.0f32; n];
    for i in 0..n {
        q[i] = mean_a[i] * guide[i] + mean_b[i];
    }
    q
}

/// Joint guided filter for an RGBA image guided by its own luminance.
///
/// Shares the guide statistics (`mean_i`, `mean_ii`, `var_i`) across R, G, B
/// channels, guaranteeing consistent edge alignment without colour bleeding.
pub fn guided_filter_luma_rgb(rgba: &[u8], w: usize, h: usize, radius: usize, eps: f32) -> Vec<u8> {
    if radius == 0 || w == 0 || h == 0 {
        return rgba.to_vec();
    }
    let n = w * h;
    let mut luma = Vec::with_capacity(n);
    let mut r_ch = Vec::with_capacity(n);
    let mut g_ch = Vec::with_capacity(n);
    let mut b_ch = Vec::with_capacity(n);
    for i in 0..n {
        let r = rgba[i * 4] as f32;
        let g = rgba[i * 4 + 1] as f32;
        let b = rgba[i * 4 + 2] as f32;
        r_ch.push(r);
        g_ch.push(g);
        b_ch.push(b);
        luma.push(0.2126 * r + 0.7152 * g + 0.0722 * b);
    }

    let mean_i = box_blur_1d(&luma, w, h, radius);
    let ii: Vec<f32> = luma.iter().map(|&l| l * l).collect();
    let mean_ii = box_blur_1d(&ii, w, h, radius);

    let mut var_i = Vec::with_capacity(n);
    for i in 0..n {
        var_i.push((mean_ii[i] - mean_i[i] * mean_i[i]).max(0.0));
    }

    let mut out = rgba.to_vec();
    for (c, ch) in [r_ch, g_ch, b_ch].into_iter().enumerate() {
        let mean_p = box_blur_1d(&ch, w, h, radius);
        let mut ip = Vec::with_capacity(n);
        for i in 0..n {
            ip.push(luma[i] * ch[i]);
        }
        let mean_ip = box_blur_1d(&ip, w, h, radius);

        let mut a = Vec::with_capacity(n);
        let mut b = Vec::with_capacity(n);
        for i in 0..n {
            let cov_ip = mean_ip[i] - mean_i[i] * mean_p[i];
            let a_val = cov_ip / (var_i[i] + eps);
            let b_val = mean_p[i] - a_val * mean_i[i];
            a.push(a_val);
            b.push(b_val);
        }

        let mean_a = box_blur_1d(&a, w, h, radius);
        let mean_b = box_blur_1d(&b, w, h, radius);

        for i in 0..n {
            let q = mean_a[i] * luma[i] + mean_b[i];
            out[i * 4 + c] = q.clamp(0.0, 255.0) as u8;
        }
    }
    out
}

/// The clarity/shadows blur radius derived from the image size. Callers that
/// process a *band* of a larger image must derive the radius from the **full**
/// image (not the band) or the result would drift across tiles.
pub fn clarity_radius(w: usize, h: usize) -> usize {
    (w.min(h) / 16).clamp(4, 64)
}

/// Clarity: mid-frequency local contrast — large blur radius (a Gaussian
/// approximation of the spec's edge-preserving base/detail split).
pub fn apply_clarity(rgba: &[u8], w: usize, h: usize, amount: f32) -> Vec<u8> {
    apply_clarity_r(rgba, w, h, amount, clarity_radius(w, h))
}

/// [`apply_clarity`] with an explicit radius (for banded processing).
pub fn apply_clarity_r(rgba: &[u8], w: usize, h: usize, amount: f32, radius: usize) -> Vec<u8> {
    if amount == 0.0 || w == 0 || h == 0 {
        return rgba.to_vec();
    }
    let base = guided_filter_luma_rgb(rgba, w, h, radius, 250.0);
    unsharp(rgba, &base, amount)
}

/// Computes an edge mask (0..1 per pixel) from luminance gradients.
/// High values represent sharp edges; flat regions are suppressed to 0.
pub fn sharpen_edge_mask(rgba: &[u8], w: usize, h: usize, masking: f32) -> Vec<f32> {
    let n = w * h;
    if n == 0 {
        return Vec::new();
    }
    if masking <= 0.0 {
        return vec![1.0; n];
    }

    let mut luma = Vec::with_capacity(n);
    for i in 0..n {
        let r = rgba[i * 4] as f32;
        let g = rgba[i * 4 + 1] as f32;
        let b = rgba[i * 4 + 2] as f32;
        luma.push(0.2126 * r + 0.7152 * g + 0.0722 * b);
    }

    let mut mask = vec![0.0f32; n];
    let threshold = masking * 30.0;
    let window = 10.0;

    for y in 0..h {
        let y_prev = y.saturating_sub(1);
        let y_next = (y + 1).min(h - 1);
        for x in 0..w {
            let x_prev = x.saturating_sub(1);
            let x_next = (x + 1).min(w - 1);

            let dx = luma[y * w + x_next] - luma[y * w + x_prev];
            let dy = luma[y_next * w + x] - luma[y_prev * w + x];
            let grad = (dx * dx + dy * dy).sqrt();

            if grad <= threshold {
                mask[y * w + x] = 0.0;
            } else if grad >= threshold + window {
                mask[y * w + x] = 1.0;
            } else {
                mask[y * w + x] = (grad - threshold) / window;
            }
        }
    }

    mask
}

/// Unsharp sharpening with advanced radius, detail, and edge masking.
pub fn apply_sharpen_advanced(
    rgba: &[u8],
    w: usize,
    h: usize,
    amount: f32,
    radius: f32,
    detail: f32,
    masking: f32,
) -> Vec<u8> {
    if amount == 0.0 || w == 0 || h == 0 {
        return rgba.to_vec();
    }

    let r = (radius.round() as usize).clamp(1, 10);
    let base = blur_rgb(rgba, w, h, r, 1);
    let mask = if masking > 0.0 {
        sharpen_edge_mask(rgba, w, h, masking)
    } else {
        Vec::new()
    };

    let mut out = rgba.to_vec();
    let detail_factor = 0.5 + detail;

    for i in 0..w * h {
        let m = if masking > 0.0 { mask[i] } else { 1.0 };
        if m == 0.0 {
            continue;
        }
        let effective_amount = amount * m * detail_factor;
        for c in 0..3 {
            let o = rgba[i * 4 + c] as f32;
            let b = base[i * 4 + c] as f32;
            out[i * 4 + c] = (o + (o - b) * effective_amount).clamp(0.0, 255.0) as u8;
        }
    }
    out
}

/// Sharpening: unsharp mask with a caller-chosen radius/amount.
pub fn apply_sharpen(rgba: &[u8], w: usize, h: usize, amount: f32, radius: usize) -> Vec<u8> {
    apply_sharpen_advanced(rgba, w, h, amount, radius as f32, 0.5, 0.0)
}

/// Edge-aware shadows/highlights: split into a large-radius base and a detail
/// layer, adjust the base's luminance by tonal zone, then re-add the detail —
/// so shadows lift without halos.
pub fn apply_shadow_highlight(
    rgba: &[u8],
    w: usize,
    h: usize,
    shadows: f32,
    highlights: f32,
) -> Vec<u8> {
    apply_shadow_highlight_r(rgba, w, h, shadows, highlights, clarity_radius(w, h))
}

/// [`apply_shadow_highlight`] with an explicit radius (for banded processing).
pub fn apply_shadow_highlight_r(
    rgba: &[u8],
    w: usize,
    h: usize,
    shadows: f32,
    highlights: f32,
    radius: usize,
) -> Vec<u8> {
    if (shadows == 0.0 && highlights == 0.0) || w == 0 || h == 0 {
        return rgba.to_vec();
    }
    let base = guided_filter_luma_rgb(rgba, w, h, radius, 250.0);
    let mut out = rgba.to_vec();
    for i in 0..w * h {
        let br = base[i * 4] as f32 / 255.0;
        let bg = base[i * 4 + 1] as f32 / 255.0;
        let bb = base[i * 4 + 2] as f32 / 255.0;
        let l = 0.2126 * br + 0.7152 * bg + 0.0722 * bb;
        let lift = shadows * (1.0 - 2.0 * l).clamp(0.0, 1.0) * 0.5;
        let pull = highlights * (2.0 * l - 1.0).clamp(0.0, 1.0) * 0.5;
        let target = (l + lift - pull).clamp(0.0, 1.0);
        let scale = if l > 1e-3 { target / l } else { 1.0 };
        for c in 0..3 {
            let detail = rgba[i * 4 + c] as f32 - base[i * 4 + c] as f32;
            out[i * 4 + c] = (base[i * 4 + c] as f32 * scale + detail).clamp(0.0, 255.0) as u8;
        }
    }
    out
}

/// Blurs a single-channel plane (separable box, `iterations` passes).
fn blur_plane(src: &[f32], w: usize, h: usize, radius: usize, iterations: usize) -> Vec<f32> {
    let mut b = src.to_vec();
    for _ in 0..iterations {
        b = box_blur_1d(&b, w, h, radius);
    }
    b
}

/// Luma/chroma noise reduction. Chroma noise is smoothed heavily (it is
/// low-frequency perceptually); luma smoothing is edge-weighted so detail stays
/// crisp (the Lightroom-style split).
pub fn denoise(rgba: &[u8], w: usize, h: usize, luma: f32, chroma: f32) -> Vec<u8> {
    let n = w * h;
    if luma <= 0.0 && chroma <= 0.0 {
        return rgba.to_vec();
    }

    let mut y = vec![0f32; n];
    let mut cb = vec![0f32; n];
    let mut cr = vec![0f32; n];
    for i in 0..n {
        let r = rgba[i * 4] as f32;
        let g = rgba[i * 4 + 1] as f32;
        let b = rgba[i * 4 + 2] as f32;
        let l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        y[i] = l;
        cb[i] = b - l;
        cr[i] = r - l;
    }

    if chroma > 0.0 {
        let by = blur_plane(&cb, w, h, 4, 2);
        let br = blur_plane(&cr, w, h, 4, 2);
        for i in 0..n {
            cb[i] += (by[i] - cb[i]) * chroma;
            cr[i] += (br[i] - cr[i]) * chroma;
        }
    }
    if luma > 0.0 {
        let by = blur_plane(&y, w, h, 2, 1);
        for i in 0..n {
            let detail = (y[i] - by[i]).abs();
            let weight = (1.0 - detail / 40.0).clamp(0.0, 1.0); // protect edges
            y[i] += (by[i] - y[i]) * luma * weight;
        }
    }

    let mut out = rgba.to_vec();
    for i in 0..n {
        let l = y[i];
        let r = l + cr[i];
        let b = l + cb[i];
        let g = (l - 0.2126 * r - 0.0722 * b) / 0.7152;
        out[i * 4] = r.clamp(0.0, 255.0) as u8;
        out[i * 4 + 1] = g.clamp(0.0, 255.0) as u8;
        out[i * 4 + 2] = b.clamp(0.0, 255.0) as u8;
    }
    out
}

/// The spatial pass strengths (all neutral at 0).
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct SpatialParams {
    /// Edge-aware shadow lift.
    pub shadows: f32,
    /// Edge-aware highlight recovery.
    pub highlights: f32,
    /// Mid-frequency local contrast.
    pub clarity: f32,
    /// Fine-detail boost.
    pub texture: f32,
    /// Unsharp amount (`0..1`).
    pub sharpen: f32,
    /// Sharpen radius in pixels (0.5..3.0, default: 1.0).
    pub sharpen_radius: f32,
    /// Sharpen detail / halo suppression (0..1, default: 0.25).
    pub sharpen_detail: f32,
    /// Edge masking threshold (0..1, default: 0.0).
    pub sharpen_masking: f32,
    /// Luma noise reduction.
    pub denoise_luma: f32,
    /// Chroma noise reduction.
    pub denoise_chroma: f32,
    /// Dehaze (veil removal via a large-radius local-contrast estimate).
    pub dehaze: f32,
    /// Vignette: >0 darkens the edges, <0 lightens them.
    pub vignette: f32,
    /// Vignette midpoint (0..1, default: 0.5).
    pub vignette_midpoint: f32,
    /// Vignette feather (0..1, default: 0.5).
    pub vignette_feather: f32,
    /// Vignette roundness (-1..1, default: 0.0).
    pub vignette_roundness: f32,
    /// Vignette highlight preservation (0..1, default: 0.0).
    pub vignette_highlights: f32,
    /// Film grain amount (`0..1`).
    pub grain: f32,
    /// Film grain particle size (0..1, default: 0.25).
    pub grain_size: f32,
    /// Film grain roughness (0..1, default: 0.5).
    pub grain_roughness: f32,
    /// Film halation (red highlight bleeding across emulsion): 0..1.
    pub film_halation: f32,
    pub film_halation_radius: f32,
    pub film_halation_threshold: f32,
    /// Film optical bloom (diffusion / pro-mist): 0..1.
    pub film_bloom: f32,
    pub film_bloom_radius: f32,
    pub film_bloom_threshold: f32,
    /// Archival film dust flecks: 0..1.
    pub film_dust: f32,
    pub film_scratches: f32,
    /// Shader Lab preset: 0=none, 1=vhs, 2=prism, 3=crt, 4=pixelate, 5=custom.
    pub shader_lab_preset: u32,
    pub shader_param1: f32,
    pub shader_param2: f32,
    pub shader_param3: f32,
}

impl SpatialParams {
    /// True when the pass would be a no-op.
    pub fn is_neutral(&self) -> bool {
        self.shadows == 0.0
            && self.highlights == 0.0
            && self.clarity == 0.0
            && self.texture == 0.0
            && self.sharpen == 0.0
            && self.denoise_luma == 0.0
            && self.denoise_chroma == 0.0
            && self.dehaze == 0.0
            && self.vignette == 0.0
            && self.grain == 0.0
            && self.film_halation == 0.0
            && self.film_bloom == 0.0
            && self.film_dust == 0.0
            && self.film_scratches == 0.0
            && self.shader_lab_preset == 0
    }
}

/// Radial vignette with advanced midpoint, feather, roundness, and highlight protection.
#[allow(clippy::too_many_arguments)]
pub fn vignette_advanced(
    rgba: &[u8],
    w: usize,
    h: usize,
    amount: f32,
    midpoint: f32,
    feather: f32,
    roundness: f32,
    highlights: f32,
) -> Vec<u8> {
    let mut out = rgba.to_vec();
    vignette_tile_advanced(
        &mut out, w, h, w, 0, 0, amount, midpoint, feather, roundness, highlights,
    );
    out
}

/// Radial vignette: darkens (`amount > 0`) or lightens (`amount < 0`) toward the
/// corners with a smooth falloff.
pub fn vignette(rgba: &[u8], w: usize, h: usize, amount: f32) -> Vec<u8> {
    vignette_advanced(rgba, w, h, amount, 0.5, 0.5, 0.0, 0.0)
}

/// Deterministic film grain with particle size and roughness controls.
pub fn grain_advanced(
    rgba: &[u8],
    w: usize,
    _h: usize,
    amount: f32,
    size: f32,
    roughness: f32,
) -> Vec<u8> {
    let mut out = rgba.to_vec();
    grain_tile_advanced(&mut out, w, 0, 0, amount, size, roughness);
    out
}

/// Deterministic film grain (same seed per pixel → stable, no flicker).
pub fn grain(rgba: &[u8], w: usize, h: usize, amount: f32) -> Vec<u8> {
    grain_advanced(rgba, w, h, amount, 0.25, 0.5)
}

fn hash_noise(x: u32, y: u32) -> f32 {
    let mut h = x
        .wrapping_mul(374_761_393)
        .wrapping_add(y.wrapping_mul(668_265_263));
    h = (h ^ (h >> 13)).wrapping_mul(1_274_126_177);
    ((h ^ (h >> 16)) as f32 / u32::MAX as f32) * 2.0 - 1.0
}

/// Separable 2D min filter with O(r) sliding window, edge-clamped.
pub fn min_filter_2d(src: &[f32], w: usize, h: usize, radius: usize) -> Vec<f32> {
    if radius == 0 || w == 0 || h == 0 {
        return src.to_vec();
    }
    let mut tmp = vec![0.0f32; w * h];
    for y in 0..h {
        let row = y * w;
        for x in 0..w {
            let lo = x.saturating_sub(radius);
            let hi = (x + radius).min(w - 1);
            let mut m = src[row + lo];
            for k in (lo + 1)..=hi {
                let v = src[row + k];
                if v < m {
                    m = v;
                }
            }
            tmp[row + x] = m;
        }
    }
    let mut out = vec![0.0f32; w * h];
    for x in 0..w {
        for y in 0..h {
            let lo = y.saturating_sub(radius);
            let hi = (y + radius).min(h - 1);
            let mut m = tmp[lo * w + x];
            for k in (lo + 1)..=hi {
                let v = tmp[k * w + x];
                if v < m {
                    m = v;
                }
            }
            out[y * w + x] = m;
        }
    }
    out
}

/// Estimates the global atmospheric light vector [A_r, A_g, A_b]
/// using the dark channel prior (He et al. 2009).
///
/// Picks the top 0.1% brightest pixels in the dark channel (most haze-opaque),
/// and selects the pixel among them with highest luminance in the input image.
pub fn estimate_atmospheric_light(
    rgba: &[u8],
    dark_channel: &[f32],
    w: usize,
    h: usize,
) -> [f32; 3] {
    let n = w * h;
    if n == 0 {
        return [220.0, 220.0, 220.0];
    }
    let top_count = (n / 1000).max(1);

    // 256-bin histogram over quantized dark channel [0..255]
    let mut hist = [0usize; 256];
    for &v in dark_channel {
        let bin = (v.clamp(0.0, 255.0) as usize).min(255);
        hist[bin] += 1;
    }

    // Find threshold for top 0.1% brightest dark-channel pixels
    let mut accumulated = 0;
    let mut thresh_bin = 0;
    for bin in (0..256).rev() {
        accumulated += hist[bin];
        if accumulated >= top_count {
            thresh_bin = bin;
            break;
        }
    }

    let mut best_luma = -1.0f32;
    let mut best_rgb = [220.0f32; 3];
    let thresh = thresh_bin as f32;

    for i in 0..n {
        if dark_channel[i] >= thresh {
            let r = rgba[i * 4] as f32;
            let g = rgba[i * 4 + 1] as f32;
            let b = rgba[i * 4 + 2] as f32;
            let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
            if luma > best_luma {
                best_luma = luma;
                best_rgb = [r, g, b];
            }
        }
    }

    // Clamp to prevent division by zero or negative atmospheric light
    [
        best_rgb[0].clamp(10.0, 255.0),
        best_rgb[1].clamp(10.0, 255.0),
        best_rgb[2].clamp(10.0, 255.0),
    ]
}

/// Computes the refined transmission map using the dark channel prior and guided filter.
///
/// Returns values in `[0.1, 1.0]` representing the per-pixel medium transmission, along
/// with the estimated atmospheric light vector.
pub fn estimate_transmission(rgba: &[u8], w: usize, h: usize, amount: f32) -> (Vec<f32>, [f32; 3]) {
    let n = w * h;
    if n == 0 {
        return (Vec::new(), [220.0, 220.0, 220.0]);
    }
    let mut dc = Vec::with_capacity(n);
    let mut luma_guide = Vec::with_capacity(n);
    for i in 0..n {
        let r = rgba[i * 4] as f32;
        let g = rgba[i * 4 + 1] as f32;
        let b = rgba[i * 4 + 2] as f32;
        let min_c = r.min(g).min(b);
        dc.push(min_c);
        luma_guide.push((0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0);
    }

    let patch_radius = 4;
    let dc_patch = min_filter_2d(&dc, w, h, patch_radius);
    let a_rgb = estimate_atmospheric_light(rgba, &dc_patch, w, h);

    let omega = amount.clamp(0.0, 1.0) * 0.95;
    let mut norm_min = Vec::with_capacity(n);
    for i in 0..n {
        let nr = rgba[i * 4] as f32 / a_rgb[0];
        let ng = rgba[i * 4 + 1] as f32 / a_rgb[1];
        let nb = rgba[i * 4 + 2] as f32 / a_rgb[2];
        norm_min.push(nr.min(ng).min(nb));
    }
    let patch_norm_min = min_filter_2d(&norm_min, w, h, patch_radius);

    let raw_t: Vec<f32> = patch_norm_min
        .iter()
        .map(|&m| (1.0 - omega * m).clamp(0.0, 1.0))
        .collect();

    let gf_radius = 16;
    let gf_eps = 0.001f32;
    let refined_t = guided_filter_channel(&luma_guide, &raw_t, w, h, gf_radius, gf_eps);

    let t0 = 0.1f32;
    let final_t: Vec<f32> = refined_t.into_iter().map(|t| t.clamp(t0, 1.0)).collect();
    (final_t, a_rgb)
}

/// Dark-channel prior dehaze with atmospheric light estimation, guided-filter
/// transmission refinement, and linear radiance recovery (He et al. 2009 / 2011).
///
/// Positive `amount` (0..1) removes haze and restores contrast/saturation.
/// Negative `amount` (-1..0) adds realistic atmospheric haze/fog.
pub fn dehaze(rgba: &[u8], w: usize, h: usize, amount: f32) -> Vec<u8> {
    if amount == 0.0 || w == 0 || h == 0 {
        return rgba.to_vec();
    }
    let n = w * h;

    if amount < 0.0 {
        // Negative dehaze: inject atmospheric fog/haze
        let mut dc = Vec::with_capacity(n);
        for i in 0..n {
            let r = rgba[i * 4] as f32;
            let g = rgba[i * 4 + 1] as f32;
            let b = rgba[i * 4 + 2] as f32;
            dc.push(r.min(g).min(b));
        }
        let dc_patch = min_filter_2d(&dc, w, h, 4);
        let a_rgb = estimate_atmospheric_light(rgba, &dc_patch, w, h);
        let fog_factor = (-amount * 0.5).clamp(0.0, 0.9);
        let mut out = rgba.to_vec();
        for i in 0..n {
            for c in 0..3 {
                let orig = rgba[i * 4 + c] as f32;
                let fogged = orig * (1.0 - fog_factor) + a_rgb[c] * fog_factor;
                out[i * 4 + c] = fogged.clamp(0.0, 255.0) as u8;
            }
        }
        return out;
    }

    let (t_map, a_rgb) = estimate_transmission(rgba, w, h, amount);
    let mut out = rgba.to_vec();
    for i in 0..n {
        let t = t_map[i];
        for c in 0..3 {
            let orig = rgba[i * 4 + c] as f32;
            let j = (orig - a_rgb[c]) / t + a_rgb[c];
            out[i * 4 + c] = j.clamp(0.0, 255.0) as u8;
        }
    }
    out
}

/// Simulates photochemical film halation (red light bleeding from specular highlights into emulsion backing).
pub fn film_halation(
    rgba: &[u8],
    w: usize,
    h: usize,
    amount: f32,
    radius_norm: f32,
    threshold: f32,
) -> Vec<u8> {
    if amount <= 0.0 || w == 0 || h == 0 {
        return rgba.to_vec();
    }
    let n = w * h;
    let thresh = (threshold * 255.0).clamp(0.0, 254.0);
    let mut highlight = vec![0.0f32; n];

    for i in 0..n {
        let r = rgba[i * 4] as f32;
        let g = rgba[i * 4 + 1] as f32;
        let b = rgba[i * 4 + 2] as f32;
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        if luma > thresh {
            highlight[i] = ((luma - thresh) / (255.0 - thresh)).clamp(0.0, 1.0);
        }
    }

    let r_px = ((w.min(h) as f32 * 0.04 * radius_norm).round() as usize).max(1);
    let blurred = box_blur_1d(&highlight, w, h, r_px);

    let mut out = rgba.to_vec();
    for i in 0..n {
        let b_val = blurred[i];
        if b_val > 0.001 {
            let r = out[i * 4] as f32;
            let g = out[i * 4 + 1] as f32;
            let b = out[i * 4 + 2] as f32;
            // Warm red glow: R receives 1.2 * 255 * amount, G receives 0.25, B receives 0.05
            out[i * 4] = (r + b_val * 255.0 * amount * 1.2).clamp(0.0, 255.0) as u8;
            out[i * 4 + 1] = (g + b_val * 255.0 * amount * 0.25).clamp(0.0, 255.0) as u8;
            out[i * 4 + 2] = (b + b_val * 255.0 * amount * 0.05).clamp(0.0, 255.0) as u8;
        }
    }
    out
}

/// Simulates optical diffusion bloom (Pro-Mist filter highlight scattering).
pub fn film_bloom(
    rgba: &[u8],
    w: usize,
    h: usize,
    amount: f32,
    radius_norm: f32,
    threshold: f32,
) -> Vec<u8> {
    if amount <= 0.0 || w == 0 || h == 0 {
        return rgba.to_vec();
    }
    let n = w * h;
    let thresh = (threshold * 255.0).clamp(0.0, 254.0);
    let mut highlight = vec![0.0f32; n];

    for i in 0..n {
        let r = rgba[i * 4] as f32;
        let g = rgba[i * 4 + 1] as f32;
        let b = rgba[i * 4 + 2] as f32;
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        if luma > thresh {
            highlight[i] = ((luma - thresh) / (255.0 - thresh)).clamp(0.0, 1.0);
        }
    }

    let r_px = ((w.min(h) as f32 * 0.10 * radius_norm).round() as usize).max(2);
    let mut blurred = box_blur_1d(&highlight, w, h, r_px);
    blurred = box_blur_1d(&blurred, w, h, r_px);

    let mut out = rgba.to_vec();
    for i in 0..n {
        let b_val = blurred[i];
        if b_val > 0.001 {
            let add = b_val * 255.0 * amount * 0.8;
            out[i * 4] = (out[i * 4] as f32 + add).clamp(0.0, 255.0) as u8;
            out[i * 4 + 1] = (out[i * 4 + 1] as f32 + add).clamp(0.0, 255.0) as u8;
            out[i * 4 + 2] = (out[i * 4 + 2] as f32 + add).clamp(0.0, 255.0) as u8;
        }
    }
    out
}

/// Simulates physical archival film dust flecks and hairline scratches.
pub fn film_dust_and_scratches(
    rgba: &[u8],
    w: usize,
    h: usize,
    dust: f32,
    scratches: f32,
) -> Vec<u8> {
    if dust <= 0.0 && scratches <= 0.0 {
        return rgba.to_vec();
    }
    let mut out = rgba.to_vec();
    for y in 0..h {
        for x in 0..w {
            let idx = (y * w + x) * 4;
            let mut factor = 1.0f32;

            if dust > 0.0 {
                let n = hash_noise((x / 2) as u32, (y / 2) as u32);
                let thresh = 1.0 - dust * 0.025;
                if n > thresh {
                    factor *= 0.25; // dark dust speck
                }
            }

            if scratches > 0.0 {
                // Vertical scratch line with slight horizontal wobble
                let wobble = (hash_noise(y as u32 / 8, 42) * 1.5).round() as i32;
                let sx = (x as i32 + wobble).max(0) as u32;
                let sn = hash_noise(sx, 1337);
                let sthresh = 1.0 - scratches * 0.008;
                if sn > sthresh {
                    factor *= 0.4; // dark vertical scratch
                }
            }

            if factor < 1.0 {
                out[idx] = (out[idx] as f32 * factor) as u8;
                out[idx + 1] = (out[idx + 1] as f32 * factor) as u8;
                out[idx + 2] = (out[idx + 2] as f32 * factor) as u8;
            }
        }
    }
    out
}

/// Applies Shader Lab creative tools (VHS, Prism, CRT, Pixelate).
pub fn shader_lab_effect(
    rgba: &[u8],
    w: usize,
    h: usize,
    preset: u32,
    p1: f32,
    _p2: f32,
    _p3: f32,
) -> Vec<u8> {
    match preset {
        1 => {
            // VHS / Retro Tape: scanline displacement & chromatic fringing
            let offset = ((p1 * 6.0).round() as usize).max(1);
            let mut out = rgba.to_vec();
            for y in 0..h {
                let line_shift = if y % 4 == 0 { offset } else { 0 };
                for x in 0..w {
                    let idx = (y * w + x) * 4;
                    let rx = (x + line_shift + offset).min(w - 1);
                    let bx = x.saturating_sub(offset);
                    out[idx] = rgba[(y * w + rx) * 4]; // R shifted
                                                       // G stays original
                    out[idx + 2] = rgba[(y * w + bx) * 4 + 2]; // B shifted
                }
            }
            out
        }
        2 => {
            // Prism / Chromatic Dispersion
            let shift = ((p1 * 8.0).round() as usize).max(1);
            let mut out = rgba.to_vec();
            for y in 0..h {
                for x in 0..w {
                    let idx = (y * w + x) * 4;
                    let rx = (x + shift).min(w - 1);
                    let bx = x.saturating_sub(shift);
                    out[idx] = rgba[(y * w + rx) * 4];
                    out[idx + 2] = rgba[(y * w + bx) * 4 + 2];
                }
            }
            out
        }
        3 => {
            // CRT Scanlines
            let mut out = rgba.to_vec();
            let dark = 1.0 - p1 * 0.4;
            for y in 0..h {
                let factor = if y % 2 == 0 { 1.0 } else { dark };
                for x in 0..w {
                    let idx = (y * w + x) * 4;
                    out[idx] = (out[idx] as f32 * factor) as u8;
                    out[idx + 1] = (out[idx + 1] as f32 * factor) as u8;
                    out[idx + 2] = (out[idx + 2] as f32 * factor) as u8;
                }
            }
            out
        }
        4 => {
            // Pixelate / Mosaic
            let block = ((p1 * 16.0).round() as usize).max(2);
            let mut out = rgba.to_vec();
            for by in (0..h).step_by(block) {
                for bx in (0..w).step_by(block) {
                    let sample_idx = (by * w + bx) * 4;
                    let (r, g, b) = (rgba[sample_idx], rgba[sample_idx + 1], rgba[sample_idx + 2]);
                    for y in by..(by + block).min(h) {
                        for x in bx..(bx + block).min(w) {
                            let idx = (y * w + x) * 4;
                            out[idx] = r;
                            out[idx + 1] = g;
                            out[idx + 2] = b;
                        }
                    }
                }
            }
            out
        }
        _ => rgba.to_vec(),
    }
}

/// Applies the full spatial pass in a fixed order: denoise → shadows/highlights
/// → clarity → texture → sharpen → dehaze → vignette → grain → film → shader lab. A neutral set
/// returns the input unchanged.
pub fn apply_spatial(rgba: &[u8], w: usize, h: usize, p: SpatialParams) -> Vec<u8> {
    if p.is_neutral() {
        return rgba.to_vec();
    }
    let mut out = apply_spatial_local(rgba, w, h, p);
    if p.vignette != 0.0 {
        let mid = if p.vignette_midpoint == 0.0 && p.vignette_feather == 0.0 {
            0.5
        } else {
            p.vignette_midpoint
        };
        let fth = if p.vignette_midpoint == 0.0 && p.vignette_feather == 0.0 {
            0.5
        } else {
            p.vignette_feather
        };
        out = vignette_advanced(
            &out,
            w,
            h,
            p.vignette,
            mid,
            fth,
            p.vignette_roundness,
            p.vignette_highlights,
        );
    }
    if p.grain != 0.0 {
        let sz = if p.grain_size == 0.0 && p.grain_roughness == 0.0 {
            0.25
        } else {
            p.grain_size
        };
        let ro = if p.grain_size == 0.0 && p.grain_roughness == 0.0 {
            0.5
        } else {
            p.grain_roughness
        };
        out = grain_advanced(&out, w, h, p.grain, sz, ro);
    }
    if p.film_halation != 0.0 {
        let rad = if p.film_halation_radius == 0.0 {
            0.5
        } else {
            p.film_halation_radius
        };
        let thr = if p.film_halation_threshold == 0.0 {
            0.8
        } else {
            p.film_halation_threshold
        };
        out = film_halation(&out, w, h, p.film_halation, rad, thr);
    }
    if p.film_bloom != 0.0 {
        let rad = if p.film_bloom_radius == 0.0 {
            0.5
        } else {
            p.film_bloom_radius
        };
        let thr = if p.film_bloom_threshold == 0.0 {
            0.75
        } else {
            p.film_bloom_threshold
        };
        out = film_bloom(&out, w, h, p.film_bloom, rad, thr);
    }
    if p.film_dust != 0.0 || p.film_scratches != 0.0 {
        out = film_dust_and_scratches(&out, w, h, p.film_dust, p.film_scratches);
    }
    if p.shader_lab_preset != 0 {
        out = shader_lab_effect(
            &out,
            w,
            h,
            p.shader_lab_preset,
            p.shader_param1,
            p.shader_param2,
            p.shader_param3,
        );
    }
    out
}

/// The neighbour-aware portion of the spatial pass — the ops that read pixels
/// around the target. Split out so it can run padded over an export band. The
/// position-dependent ops (vignette, grain) are deliberately excluded: their
/// output depends on absolute coordinates, so they must see the full frame.
///
/// The radius is derived from the passed `(w, h)`; callers processing a band
/// must call [`apply_spatial_local_ctx`] with the **full** image radius.
pub fn apply_spatial_local(rgba: &[u8], w: usize, h: usize, p: SpatialParams) -> Vec<u8> {
    apply_spatial_local_ctx(rgba, w, h, p, clarity_radius(w, h))
}

/// [`apply_spatial_local`] with an explicit clarity/shadows radius.
pub fn apply_spatial_local_ctx(
    rgba: &[u8],
    w: usize,
    h: usize,
    p: SpatialParams,
    radius: usize,
) -> Vec<u8> {
    // Run only the ops that are actually engaged — each is a full-image pass, so
    // touching a single slider must not pay for the other four.
    let mut out = rgba.to_vec();
    if p.denoise_luma != 0.0 || p.denoise_chroma != 0.0 {
        out = denoise(&out, w, h, p.denoise_luma, p.denoise_chroma);
    }
    if p.shadows != 0.0 || p.highlights != 0.0 {
        out = apply_shadow_highlight_r(&out, w, h, p.shadows, p.highlights, radius);
    }
    if p.clarity != 0.0 {
        out = apply_clarity_r(&out, w, h, p.clarity, radius);
    }
    if p.texture != 0.0 {
        out = apply_texture(&out, w, h, p.texture);
    }
    if p.sharpen != 0.0 {
        let r = if p.sharpen_radius <= 0.0 {
            1.0
        } else {
            p.sharpen_radius
        };
        out = apply_sharpen_advanced(
            &out,
            w,
            h,
            p.sharpen,
            r,
            p.sharpen_detail,
            p.sharpen_masking,
        );
    }
    if p.dehaze != 0.0 {
        out = dehaze(&out, w, h, p.dehaze);
    }
    out
}

/// Vertical halo (in rows) needed for [`apply_spatial_local_ctx`] to be exact.
///
/// The ops run as a **chain**, so the support compounds: a pixel's output
/// depends on input rows within the *sum* of every engaged op's support (each
/// separable box pass of radius `r` contributes `iterations * r`).
pub fn spatial_local_margin(p: SpatialParams, w: usize, h: usize) -> usize {
    let mut margin = 0;
    if p.denoise_luma != 0.0 || p.denoise_chroma != 0.0 {
        // Denoise blurs luma (1×2) and chroma (2×4) in parallel → max, not sum.
        let mut d = 0;
        if p.denoise_chroma != 0.0 {
            d = d.max(2 * 4);
        }
        if p.denoise_luma != 0.0 {
            d = d.max(2);
        }
        margin += d;
    }
    if p.shadows != 0.0 || p.highlights != 0.0 {
        margin += 2 * clarity_radius(w, h);
    }
    if p.clarity != 0.0 {
        margin += 2 * clarity_radius(w, h);
    }
    if p.texture != 0.0 {
        margin += 2;
    }
    if p.sharpen != 0.0 {
        let r = if p.sharpen_radius <= 0.0 {
            1.0
        } else {
            p.sharpen_radius
        };
        margin += (r.ceil() as usize).max(2) + 1;
    }
    if p.dehaze != 0.0 {
        margin += 3 * 24;
    }
    margin
}

/// Processes rows `y0..y0+bh` of the full image `full` (`w x h`) and returns
/// just those `bh * w` RGBA rows of the full spatial pass.
///
/// The neighbour-aware ops run over a vertically padded band (exactly matching
/// the full-image result, since the support stays within the padding), then the
/// absolute-coordinate ops (vignette, grain) run with the full image size and
/// the band's true row offset. Stitching every band reproduces
/// [`apply_spatial`] byte-for-byte while only ever holding one band + halo.
pub fn apply_spatial_band(
    full: &[u8],
    w: usize,
    h: usize,
    y0: usize,
    bh: usize,
    p: SpatialParams,
) -> Vec<u8> {
    let radius = clarity_radius(w, h);
    let margin = spatial_local_margin(p, w, h);
    let mut band = process_tile_padded(full, w, h, (0, y0, w, bh), margin, |b, iw, ih| {
        apply_spatial_local_ctx(b, iw, ih, p, radius)
    });
    vignette_band(&mut band, w, h, y0, p.vignette);
    grain_band(&mut band, w, y0, p.grain);
    band
}

/// Spatial chain for a **decoded full-width band** of the original frame —
/// the high-zoom ROI overlay bake (#55/#16), where the full image never
/// exists in memory.
///
/// `band` holds rows `decode_top ..` of the `full` image (width `full.0`),
/// including at least [`spatial_local_margin`] halo rows above and below the
/// requested output `[out_top, out_top + out_rows)`. With the halo present the
/// local ops read **true** context from the band itself; where the band edge
/// *is* the image edge, [`process_tile_padded`]'s clamp reproduces the
/// full-image clamp. Vignette and grain use the band's absolute row offset,
/// and radius/margin derive from the **full** frame — so the output is
/// byte-for-byte [`apply_spatial_band`] on the complete image.
///
/// A short halo away from an image edge is an error, never a silent seam.
pub fn apply_spatial_roi(
    band: &[u8],
    full: (usize, usize),
    decode_top: usize,
    out_top: usize,
    out_rows: usize,
    p: SpatialParams,
) -> Result<Vec<u8>, String> {
    let (w, h) = full;
    if w == 0 || h == 0 {
        return Err("full frame must be non-empty".to_string());
    }
    if out_rows == 0 {
        return Err("out_rows must be at least 1".to_string());
    }
    if !band.len().is_multiple_of(w * 4) {
        return Err(format!(
            "band has {} bytes, not a whole number of {w}-wide rows",
            band.len()
        ));
    }
    let band_rows = band.len() / (w * 4);
    if out_top < decode_top || out_top + out_rows > decode_top + band_rows {
        return Err(format!(
            "output rows {out_top}..{} outside decoded band {decode_top}..{}",
            out_top + out_rows,
            decode_top + band_rows
        ));
    }
    if out_top + out_rows > h {
        return Err(format!(
            "output rows {out_top}..{} outside full height {h}",
            out_top + out_rows
        ));
    }

    let margin = spatial_local_margin(p, w, h);
    let y0_buf = out_top - decode_top;
    if decode_top > 0 && y0_buf < margin {
        return Err(format!(
            "missing top halo: {y0_buf} rows, margin {margin} (decode_top {decode_top})"
        ));
    }
    let below = band_rows - (y0_buf + out_rows);
    if decode_top + band_rows < h && below < margin {
        return Err(format!(
            "missing bottom halo: {below} rows, margin {margin}"
        ));
    }

    if p.is_neutral() {
        let start = y0_buf * w * 4;
        return Ok(band[start..start + out_rows * w * 4].to_vec());
    }

    let radius = clarity_radius(w, h);
    let mut out = process_tile_padded(
        band,
        w,
        band_rows,
        (0, y0_buf, w, out_rows),
        margin,
        |b, iw, ih| apply_spatial_local_ctx(b, iw, ih, p, radius),
    );
    vignette_band(&mut out, w, h, out_top, p.vignette);
    grain_band(&mut out, w, out_top, p.grain);
    Ok(out)
}

/// Spatial chain for a **decoded rect (tile)** of the original frame — the
/// tiled viewport bake (#16). The 2D sibling of [`apply_spatial_roi`]:
///
/// * `rect` holds the pixels `decode_x..decode_x+decode_w` ×
///   `decode_y..decode_y+decode_h` of the `full` image, including at least
///   [`spatial_local_margin`] context on **all four** sides around the
///   requested output `[out_x, out_x+out_w) × [out_y, out_y+out_h)` (except
///   where the rect touches the image edge, where the clamp reproduces the
///   full-image edge behaviour);
/// * vignette/grain use the rect's absolute origin, so tiles stitch onto the
///   whole-frame result byte-for-byte.
///
/// A short halo away from an image edge is an error, never a silent seam.
#[allow(clippy::too_many_arguments)]
pub fn apply_spatial_rect(
    rect: &[u8],
    full: (usize, usize),
    decode_x: usize,
    decode_y: usize,
    decode_w: usize,
    decode_h: usize,
    out_x: usize,
    out_y: usize,
    out_w: usize,
    out_h: usize,
    p: SpatialParams,
) -> Result<Vec<u8>, String> {
    let (fw, fh) = full;
    if fw == 0 || fh == 0 {
        return Err("full frame must be non-empty".to_string());
    }
    if out_w == 0 || out_h == 0 {
        return Err("out rect must be non-empty".to_string());
    }
    if decode_w == 0 || decode_h == 0 {
        return Err("decoded rect must be non-empty".to_string());
    }
    if rect.len() != decode_w * decode_h * 4 {
        return Err(format!(
            "rect has {} bytes, expected {} for {decode_w}x{decode_h}",
            rect.len(),
            decode_w * decode_h * 4
        ));
    }
    if out_x < decode_x
        || out_y < decode_y
        || out_x + out_w > decode_x + decode_w
        || out_y + out_h > decode_y + decode_h
    {
        return Err(format!(
            "output rect {out_x},{out_y} {out_w}x{out_h} outside decoded \
             rect {decode_x},{decode_y} {decode_w}x{decode_h}"
        ));
    }
    if out_x + out_w > fw || out_y + out_h > fh {
        return Err(format!(
            "output rect {out_x},{out_y} {out_w}x{out_h} outside full frame {fw}x{fh}"
        ));
    }

    let margin = spatial_local_margin(p, fw, fh);
    let x0_buf = out_x - decode_x;
    let y0_buf = out_y - decode_y;
    if decode_x > 0 && x0_buf < margin {
        return Err(format!(
            "missing left halo: {x0_buf} px, margin {margin} (decode_x {decode_x})"
        ));
    }
    if decode_y > 0 && y0_buf < margin {
        return Err(format!(
            "missing top halo: {y0_buf} px, margin {margin} (decode_y {decode_y})"
        ));
    }
    let right = decode_w - (x0_buf + out_w);
    if decode_x + decode_w < fw && right < margin {
        return Err(format!("missing right halo: {right} px, margin {margin}"));
    }
    let below = decode_h - (y0_buf + out_h);
    if decode_y + decode_h < fh && below < margin {
        return Err(format!("missing bottom halo: {below} px, margin {margin}"));
    }

    if p.is_neutral() {
        let mut out = Vec::with_capacity(out_w * out_h * 4);
        for y in 0..out_h {
            let start = ((y0_buf + y) * decode_w + x0_buf) * 4;
            out.extend_from_slice(&rect[start..start + out_w * 4]);
        }
        return Ok(out);
    }

    let radius = clarity_radius(fw, fh);
    let mut out = process_tile_padded(
        rect,
        decode_w,
        decode_h,
        (x0_buf, y0_buf, out_w, out_h),
        margin,
        |b, iw, ih| apply_spatial_local_ctx(b, iw, ih, p, radius),
    );
    if p.vignette != 0.0 {
        let mid = if p.vignette_midpoint == 0.0 && p.vignette_feather == 0.0 {
            0.5
        } else {
            p.vignette_midpoint
        };
        let fth = if p.vignette_midpoint == 0.0 && p.vignette_feather == 0.0 {
            0.5
        } else {
            p.vignette_feather
        };
        vignette_tile_advanced(
            &mut out,
            fw,
            fh,
            out_w,
            out_x,
            out_y,
            p.vignette,
            mid,
            fth,
            p.vignette_roundness,
            p.vignette_highlights,
        );
    }
    if p.grain != 0.0 {
        let sz = if p.grain_size == 0.0 && p.grain_roughness == 0.0 {
            0.25
        } else {
            p.grain_size
        };
        let ro = if p.grain_size == 0.0 && p.grain_roughness == 0.0 {
            0.5
        } else {
            p.grain_roughness
        };
        grain_tile_advanced(&mut out, out_w, out_x, out_y, p.grain, sz, ro);
    }
    Ok(out)
}

/// In-place radial vignette for a band of rows `y0..y0+band_rows` of a `w x h`
/// image. Uses the **full** image centre so bands stitch seamlessly.
pub fn vignette_band(band: &mut [u8], w: usize, h: usize, y0: usize, amount: f32) {
    vignette_tile(band, w, h, w, 0, y0, amount);
}

/// In-place radial vignette with advanced midpoint, feather, roundness, and highlights.
#[allow(clippy::too_many_arguments)]
pub fn vignette_tile_advanced(
    band: &mut [u8],
    fw: usize,
    fh: usize,
    tw: usize,
    x0: usize,
    y0: usize,
    amount: f32,
    midpoint: f32,
    feather: f32,
    roundness: f32,
    highlights: f32,
) {
    if amount == 0.0 || tw == 0 {
        return;
    }
    let (cx, cy) = ((fw as f32 - 1.0) / 2.0, (fh as f32 - 1.0) / 2.0);
    let maxd = (cx * cx + cy * cy).sqrt().max(1.0);
    let th = band.len() / (tw * 4);

    let inner_start = (midpoint * 0.8).clamp(0.0, 0.9);
    let span = (feather * 0.8 + 0.1).max(0.05);

    for y in 0..th {
        let py = (y0 + y) as f32;
        let dy = py - cy;
        let ny = dy / cy.max(1.0);
        for x in 0..tw {
            let px = (x0 + x) as f32;
            let dx = px - cx;
            let nx = dx / cx.max(1.0);

            let d_circ = (dx * dx + dy * dy).sqrt() / maxd;
            let d_rect = (nx * nx + ny * ny).sqrt() / std::f32::consts::SQRT_2;
            let d = if roundness < 0.0 {
                d_circ * (1.0 + roundness) - d_rect * roundness
            } else {
                d_circ * (1.0 - 0.25 * roundness)
            };

            let t = ((d - inner_start) / span).clamp(0.0, 1.0);
            let falloff = t * t * (3.0 - 2.0 * t);

            let i = (y * tw + x) * 4;
            let r = band[i] as f32;
            let g = band[i + 1] as f32;
            let b = band[i + 2] as f32;
            let luma = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;

            let protect = if amount > 0.0 && highlights > 0.0 {
                (luma * luma) * highlights
            } else {
                0.0
            };

            let f = (1.0 - amount * falloff * (1.0 - protect)).max(0.0);
            band[i] = (r * f).clamp(0.0, 255.0) as u8;
            band[i + 1] = (g * f).clamp(0.0, 255.0) as u8;
            band[i + 2] = (b * f).clamp(0.0, 255.0) as u8;
        }
    }
}

/// In-place radial vignette for a `tw x th` rect whose top-left pixel sits at
/// `(x0, y0)` of the `fw x fh` full image.
pub fn vignette_tile(
    band: &mut [u8],
    fw: usize,
    fh: usize,
    tw: usize,
    x0: usize,
    y0: usize,
    amount: f32,
) {
    vignette_tile_advanced(band, fw, fh, tw, x0, y0, amount, 0.5, 0.5, 0.0, 0.0);
}

/// In-place film grain for a band of rows `y0..` using the band's true row
/// offset, so the deterministic noise pattern matches the full-frame result.
pub fn grain_band(band: &mut [u8], w: usize, y0: usize, amount: f32) {
    grain_tile(band, w, 0, y0, amount);
}

/// In-place film grain with particle size and roughness controls.
pub fn grain_tile_advanced(
    band: &mut [u8],
    tw: usize,
    x0: usize,
    y0: usize,
    amount: f32,
    size: f32,
    roughness: f32,
) {
    if amount == 0.0 || tw == 0 {
        return;
    }
    let strength = amount * 40.0;
    let rows = band.len() / (tw * 4);
    let scale = 1.0 + size.clamp(0.0, 1.0) * 3.0;

    for y in 0..rows {
        let py = (y0 + y) as f32;
        let gy = py / scale;
        let gy0 = gy.floor() as u32;
        let gy1 = gy0.wrapping_add(1);
        let fy = gy - gy.floor();

        for x in 0..tw {
            let px = (x0 + x) as f32;
            let gx = px / scale;
            let gx0 = gx.floor() as u32;
            let gx1 = gx0.wrapping_add(1);
            let fx = gx - gx.floor();

            let n00 = hash_noise(gx0, gy0);
            let n10 = hash_noise(gx1, gy0);
            let n01 = hash_noise(gx0, gy1);
            let n11 = hash_noise(gx1, gy1);

            let nx0 = n00 * (1.0 - fx) + n10 * fx;
            let nx1 = n01 * (1.0 - fx) + n11 * fx;
            let coarse = nx0 * (1.0 - fy) + nx1 * fy;

            let fine = hash_noise((x0 + x) as u32, (y0 + y) as u32);
            let n = coarse * (1.0 - roughness * 0.4) + fine * (roughness * 0.5);

            let i = (y * tw + x) * 4;
            let r = band[i] as f32;
            let g = band[i + 1] as f32;
            let b = band[i + 2] as f32;
            let luma = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
            let tonal_weight = (1.0 - (2.0 * luma - 1.0) * (2.0 * luma - 1.0)).clamp(0.2, 1.0);

            let d = n * strength * tonal_weight;
            band[i] = (r + d).clamp(0.0, 255.0) as u8;
            band[i + 1] = (g + d).clamp(0.0, 255.0) as u8;
            band[i + 2] = (b + d).clamp(0.0, 255.0) as u8;
        }
    }
}

/// In-place film grain for a `tw`-wide rect whose top-left sits at `(x0, y0)`
/// of the full image, so the deterministic noise pattern matches the
/// full-frame result wherever the rect lies.
pub fn grain_tile(band: &mut [u8], tw: usize, x0: usize, y0: usize, amount: f32) {
    grain_tile_advanced(band, tw, x0, y0, amount, 0.25, 0.5);
}

/// Runs a neighbour-aware `op` over the `tile` rect `(x, y, tw, th)` of a full
/// image, fetching `margin` extra pixels around it and cropping the result back
/// to the tile — so ops are seamless across tiles. `margin` must be ≥ the op's
/// maximum blur radius.
pub fn process_tile_padded<F>(
    full: &[u8],
    w: usize,
    h: usize,
    tile: (usize, usize, usize, usize),
    margin: usize,
    op: F,
) -> Vec<u8>
where
    F: FnOnce(&[u8], usize, usize) -> Vec<u8>,
{
    let (tx, ty, tw, th) = tile;
    let x0 = tx.saturating_sub(margin);
    let y0 = ty.saturating_sub(margin);
    let x1 = (tx + tw + margin).min(w);
    let y1 = (ty + th + margin).min(h);
    let (iw, ih) = (x1 - x0, y1 - y0);

    let mut inner = Vec::with_capacity(iw * ih * 4);
    for y in y0..y1 {
        let start = (y * w + x0) * 4;
        inner.extend_from_slice(&full[start..start + iw * 4]);
    }

    let processed = op(&inner, iw, ih);

    let off_x = tx - x0;
    let off_y = ty - y0;
    let mut out = Vec::with_capacity(tw * th * 4);
    for y in 0..th {
        let start = ((off_y + y) * iw + off_x) * 4;
        out.extend_from_slice(&processed[start..start + tw * 4]);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A deterministic noisy gradient.
    fn noise(w: usize, h: usize) -> Vec<u8> {
        let mut v = Vec::with_capacity(w * h * 4);
        for y in 0..h {
            for x in 0..w {
                let r = ((x * 37 + y * 17) % 256) as u8;
                let g = ((x * 11 + y * 53) % 256) as u8;
                let b = ((x * 7 + y * 3) % 256) as u8;
                v.extend_from_slice(&[r, g, b, 255]);
            }
        }
        v
    }

    fn variance(buf: &[u8]) -> f64 {
        let n = (buf.len() / 4) as f64;
        let mean = buf.iter().step_by(4).map(|&b| b as f64).sum::<f64>() / n;
        buf.iter()
            .step_by(4)
            .map(|&b| (b as f64 - mean).powi(2))
            .sum::<f64>()
            / n
    }

    fn variance_f32(buf: &[f32]) -> f64 {
        let n = buf.len() as f64;
        let mean = buf.iter().map(|&b| b as f64).sum::<f64>() / n;
        buf.iter().map(|&b| (b as f64 - mean).powi(2)).sum::<f64>() / n
    }

    #[test]
    fn guided_filter_step_edge_shows_no_ringing_or_halos() {
        let (w, h) = (32, 32);
        let mut src = vec![0u8; w * h * 4];
        // High-contrast vertical step edge: left is 40, right is 210
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                let val = if x < w / 2 { 40 } else { 210 };
                src[idx] = val;
                src[idx + 1] = val;
                src[idx + 2] = val;
                src[idx + 3] = 255;
            }
        }

        // Apply maximum clarity
        let clarity_out = apply_clarity_r(&src, w, h, 1.0, 4);
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                let val = clarity_out[idx];
                // Guided filter eliminates overshoot/undershoot at the step edge.
                // An unsharp filter with Gaussian/box blur overshoots to > 240 and undershoots to < 10.
                if x < w / 2 {
                    assert!(
                        val >= 36,
                        "clarity undershoot halo on dark side at ({x},{y}): expected >= 36, got {val}"
                    );
                } else {
                    assert!(
                        val <= 214,
                        "clarity overshoot halo on bright side at ({x},{y}): expected <= 214, got {val}"
                    );
                }
            }
        }

        // Apply maximum shadow lift
        let shadow_out = apply_shadow_highlight_r(&src, w, h, 1.0, 0.0, 4);
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                let val = shadow_out[idx];
                if x >= w / 2 {
                    // Bright side of the edge should not suffer dark halos
                    assert!(
                        val >= 208,
                        "shadow lift caused dark halo on bright side of edge at ({x},{y}): {val}"
                    );
                }
            }
        }
    }

    #[test]
    fn guided_filter_radius_scaling_and_identity() {
        let (w, h) = (32, 32);
        let src = noise(w, h);
        let mut guide = vec![0.0f32; w * h];
        let mut ch = vec![0.0f32; w * h];
        for i in 0..w * h {
            ch[i] = src[i * 4] as f32;
            guide[i] = 0.2126 * src[i * 4] as f32
                + 0.7152 * src[i * 4 + 1] as f32
                + 0.0722 * src[i * 4 + 2] as f32;
        }

        // Radius 0 is identity
        let r0 = guided_filter_channel(&guide, &ch, w, h, 0, 100.0);
        assert_eq!(r0, ch);

        let rgb0 = guided_filter_luma_rgb(&src, w, h, 0, 100.0);
        assert_eq!(rgb0, src);

        // Larger radius results in greater smoothing (lower variance of the base layer)
        let r2 = guided_filter_channel(&guide, &ch, w, h, 2, 500.0);
        let r6 = guided_filter_channel(&guide, &ch, w, h, 6, 500.0);
        let var2 = variance_f32(&r2);
        let var6 = variance_f32(&r6);
        assert!(
            var6 < var2,
            "larger radius must smooth more: var6 {var6} vs var2 {var2}"
        );
    }

    #[test]
    fn blur_preserves_size_alpha_and_smooths() {
        let src = noise(32, 32);
        let out = blur_rgb(&src, 32, 32, 3, 2);
        assert_eq!(out.len(), src.len());
        assert!(out.iter().skip(3).step_by(4).all(|&a| a == 255));
        assert!(variance(&out) < variance(&src));
    }

    #[test]
    fn vignette_darkens_corners_not_centre() {
        let src = vec![200u8; 8 * 8 * 4];
        let out = vignette(&src, 8, 8, 1.0);
        let center = out[((4 * 8) + 4) * 4] as i32;
        let corner = out[0] as i32;
        assert!(corner < center, "corner {corner} centre {center}");
        assert_eq!(vignette(&src, 8, 8, 0.0), src);
    }

    #[test]
    fn grain_is_deterministic_and_bounded() {
        let src = vec![128u8; 8 * 8 * 4];
        assert_eq!(grain(&src, 8, 8, 0.5), grain(&src, 8, 8, 0.5));
        assert_eq!(grain(&src, 8, 8, 0.0), src);
    }

    #[test]
    fn vignette_advanced_highlights_preserves_bright_corners() {
        let (w, h) = (16, 16);
        let mut src = vec![255u8; w * h * 4];
        let corner_grey_idx = ((h - 1) * w + (w - 1)) * 4;
        src[corner_grey_idx] = 128;
        src[corner_grey_idx + 1] = 128;
        src[corner_grey_idx + 2] = 128;

        let out_protected = vignette_advanced(&src, w, h, 0.8, 0.5, 0.5, 0.0, 1.0);
        let out_unprotected = vignette_advanced(&src, w, h, 0.8, 0.5, 0.5, 0.0, 0.0);

        assert!(
            out_protected[0] > out_unprotected[0],
            "protected {} vs unprotected {}",
            out_protected[0],
            out_unprotected[0]
        );
    }

    #[test]
    fn grain_advanced_size_creates_spatial_correlation() {
        let (w, h) = (32, 32);
        let src = vec![128u8; w * h * 4];

        let grain_fine = grain_advanced(&src, w, h, 0.5, 0.0, 0.0);
        let grain_coarse = grain_advanced(&src, w, h, 0.5, 1.0, 0.0);

        let mut diff_fine = 0.0f32;
        let mut diff_coarse = 0.0f32;
        for y in 0..h {
            for x in 0..w - 1 {
                let idx1 = (y * w + x) * 4;
                let idx2 = (y * w + x + 1) * 4;
                diff_fine += (grain_fine[idx1] as f32 - grain_fine[idx2] as f32).abs();
                diff_coarse += (grain_coarse[idx1] as f32 - grain_coarse[idx2] as f32).abs();
            }
        }
        assert!(
            diff_coarse < diff_fine,
            "coarse grain must have smaller pixel-to-pixel differences: {diff_coarse} vs {diff_fine}"
        );
    }

    #[test]
    fn neutral_spatial_params_are_a_noop() {
        let src = noise(16, 16);
        let out = apply_spatial(
            &src,
            16,
            16,
            SpatialParams {
                shadows: 0.0,
                highlights: 0.0,
                clarity: 0.0,
                texture: 0.0,
                sharpen: 0.0,
                sharpen_radius: 1.0,
                sharpen_detail: 0.25,
                sharpen_masking: 0.0,
                denoise_luma: 0.0,
                denoise_chroma: 0.0,
                dehaze: 0.0,
                vignette: 0.0,
                vignette_midpoint: 0.5,
                vignette_feather: 0.5,
                vignette_roundness: 0.0,
                vignette_highlights: 0.0,
                grain: 0.0,
                grain_size: 0.25,
                grain_roughness: 0.5,
                ..Default::default()
            },
        );
        assert_eq!(out, src);
    }

    #[test]
    fn dehaze_increases_local_contrast_and_size() {
        let src = noise(32, 32);
        let out = dehaze(&src, 32, 32, 1.0);
        assert_eq!(out.len(), src.len());
        assert!(variance(&out) > variance(&src));
        // neutral amount is a no-op
        assert_eq!(dehaze(&src, 32, 32, 0.0), src);
    }

    #[test]
    fn dehaze_synthetic_fog_recovers_transmission() {
        let (w, h) = (48, 48);
        let a_val = 220.0f32;
        let true_t = 0.6f32;
        let mut clear = vec![0u8; w * h * 4];
        let mut hazy = vec![0u8; w * h * 4];
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                if y < 4 {
                    // Sky / distant thick fog patch where radiance equals atmospheric light
                    clear[idx] = a_val as u8;
                    clear[idx + 1] = a_val as u8;
                    clear[idx + 2] = a_val as u8;
                    clear[idx + 3] = 255;
                    hazy[idx] = a_val as u8;
                    hazy[idx + 1] = a_val as u8;
                    hazy[idx + 2] = a_val as u8;
                    hazy[idx + 3] = 255;
                } else {
                    let r = if x < w / 2 { 20 } else { 180 };
                    let g = if y < h / 2 { 30 } else { 150 };
                    let b = if (x + y) % 4 == 0 { 15 } else { 40 };
                    clear[idx] = r;
                    clear[idx + 1] = g;
                    clear[idx + 2] = b;
                    clear[idx + 3] = 255;
                    for c in 0..3 {
                        let j = clear[idx + c] as f32;
                        let val = j * true_t + a_val * (1.0 - true_t);
                        hazy[idx + c] = val.round().clamp(0.0, 255.0) as u8;
                    }
                    hazy[idx + 3] = 255;
                }
            }
        }

        // Recover transmission map
        let (recovered_t, est_a) = estimate_transmission(&hazy, w, h, 1.0);

        // Verify estimated atmospheric light is close to 220
        for (c, &val) in est_a.iter().enumerate() {
            assert!(
                (val - a_val).abs() < 25.0,
                "atmospheric light ch {c} expected ~{a_val}, got {val}"
            );
        }

        // Verify recovered transmission map matches known true_t in interior
        let mut mean_t = 0.0f32;
        let mut count = 0;
        for y in 8..h - 8 {
            for x in 8..w - 8 {
                mean_t += recovered_t[y * w + x];
                count += 1;
            }
        }
        mean_t /= count as f32;
        assert!(
            (mean_t - true_t).abs() < 0.18,
            "recovered transmission {mean_t} must match true transmission {true_t} within tolerance"
        );

        // Radiance recovery: dehazed image should be closer to clear image than hazy image was
        let dehazed = dehaze(&hazy, w, h, 1.0);
        let mse_hazy: f64 = clear
            .as_chunks::<4>()
            .0
            .iter()
            .zip(hazy.as_chunks::<4>().0.iter())
            .map(|(c, h)| {
                (c[0] as f64 - h[0] as f64).powi(2)
                    + (c[1] as f64 - h[1] as f64).powi(2)
                    + (c[2] as f64 - h[2] as f64).powi(2)
            })
            .sum();
        let mse_dehazed: f64 = clear
            .as_chunks::<4>()
            .0
            .iter()
            .zip(dehazed.as_chunks::<4>().0.iter())
            .map(|(c, d)| {
                (c[0] as f64 - d[0] as f64).powi(2)
                    + (c[1] as f64 - d[1] as f64).powi(2)
                    + (c[2] as f64 - d[2] as f64).powi(2)
            })
            .sum();

        assert!(
            mse_dehazed < mse_hazy * 0.5,
            "dehazing must significantly reduce error towards clear image: {mse_dehazed} vs {mse_hazy}"
        );
    }

    #[test]
    fn dehaze_monotonicity_and_bounds() {
        let (w, h) = (32, 32);
        let src = noise(w, h);

        let d0 = dehaze(&src, w, h, 0.0);
        assert_eq!(d0, src);

        let d25 = dehaze(&src, w, h, 0.25);
        let d50 = dehaze(&src, w, h, 0.5);
        let d100 = dehaze(&src, w, h, 1.0);

        // Monotonic contrast expansion
        let v0 = variance(&d0);
        let v25 = variance(&d25);
        let v50 = variance(&d50);
        let v100 = variance(&d100);

        assert!(v25 >= v0, "v25 {v25} >= v0 {v0}");
        assert!(v50 >= v25, "v50 {v50} >= v25 {v25}");
        assert!(v100 >= v50, "v100 {v100} >= v50 {v50}");

        // Negative dehaze adds fog (reduces variance towards atmospheric veil)
        let dfog = dehaze(&src, w, h, -0.6);
        assert!(
            variance(&dfog) < v0,
            "negative dehaze must add fog and reduce contrast"
        );
    }

    #[test]
    fn texture_increases_local_contrast() {
        let src = noise(32, 32);
        let out = apply_texture(&src, 32, 32, 1.0);
        assert!(variance(&out) > variance(&src));
    }

    #[test]
    fn zero_amount_is_identity() {
        let src = noise(16, 16);
        assert_eq!(apply_texture(&src, 16, 16, 0.0), src);
        assert_eq!(apply_clarity(&src, 16, 16, 0.0), src);
        assert_eq!(apply_sharpen(&src, 16, 16, 0.0, 2), src);
        assert_eq!(apply_shadow_highlight(&src, 16, 16, 0.0, 0.0), src);
    }

    #[test]
    fn sharpen_advanced_masking_protects_flat_regions_and_sharpens_edges() {
        let (w, h) = (32, 32);
        let mut src = vec![255u8; w * h * 4];
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                let val = if x < w / 2 {
                    if (x + y) % 2 == 0 {
                        82
                    } else {
                        80
                    }
                } else {
                    180
                };
                src[idx] = val;
                src[idx + 1] = val;
                src[idx + 2] = val;
            }
        }

        let unmasked = apply_sharpen_advanced(&src, w, h, 1.0, 1.0, 0.5, 0.0);
        let masked = apply_sharpen_advanced(&src, w, h, 1.0, 1.0, 0.5, 0.8);

        let flat_idx = (4 * w + 4) * 4;
        let diff_unmasked = (unmasked[flat_idx] as i32 - src[flat_idx] as i32).abs();
        let diff_masked = (masked[flat_idx] as i32 - src[flat_idx] as i32).abs();
        assert!(
            diff_masked < diff_unmasked,
            "masking must protect flat region: masked diff {diff_masked} vs unmasked {diff_unmasked}"
        );

        let edge_idx = (4 * w + 15) * 4;
        let edge_diff = (masked[edge_idx] as i32 - src[edge_idx] as i32).abs();
        assert!(edge_diff > 0, "masking must still sharpen edges");
    }

    #[test]
    fn shadow_lift_brightens_a_dark_image() {
        // Uniform dark grey.
        let src: Vec<u8> = std::iter::repeat_n([60u8, 60, 60, 255], 16 * 16)
            .flatten()
            .collect();
        let out = apply_shadow_highlight(&src, 16, 16, 1.0, 0.0);
        let mean =
            |b: &[u8]| b.iter().step_by(4).map(|&v| v as u64).sum::<u64>() / (b.len() / 4) as u64;
        assert!(mean(&out) > mean(&src), "shadows should lift");
    }

    #[test]
    fn padded_tile_matches_full_image_processing() {
        let (w, h) = (64, 48);
        let src = noise(w, h);
        let radius = 3;
        let full = blur_rgb(&src, w, h, radius, 1);

        // An interior tile, with margin >= radius.
        let tile = (16usize, 12usize, 16usize, 16usize);
        let processed = process_tile_padded(&src, w, h, tile, radius, |b, iw, ih| {
            blur_rgb(b, iw, ih, radius, 1)
        });

        // Compare against the full-image result cropped to the tile.
        let (tx, ty, tw, th) = tile;
        for y in 0..th {
            for x in 0..tw {
                let ti = (y * tw + x) * 4;
                let fi = ((ty + y) * w + (tx + x)) * 4;
                for c in 0..3 {
                    assert_eq!(
                        processed[ti + c],
                        full[fi + c],
                        "seam at ({x},{y}) channel {c}"
                    );
                }
            }
        }
    }

    #[test]
    fn apply_spatial_is_neutral_at_zero_and_composes() {
        let src = noise(32, 32);
        assert_eq!(apply_spatial(&src, 32, 32, SpatialParams::default()), src);
        let p = SpatialParams {
            texture: 0.8,
            sharpen: 0.5,
            ..Default::default()
        };
        assert!(variance(&apply_spatial(&src, 32, 32, p)) > variance(&src));
    }

    #[test]
    fn padded_tile_handles_the_image_border() {
        let (w, h) = (20, 20);
        let src = noise(w, h);
        // A corner tile; padding clamps at the border (must not panic).
        let out = process_tile_padded(&src, w, h, (0, 0, 8, 8), 4, |b, iw, ih| {
            blur_rgb(b, iw, ih, 4, 1)
        });
        assert_eq!(out.len(), 8 * 8 * 4);
    }

    /// Stitches `apply_spatial_band` over `band_rows`-tall bands.
    fn stitch_bands(src: &[u8], w: usize, h: usize, band_rows: usize, p: SpatialParams) -> Vec<u8> {
        let mut out = Vec::with_capacity(src.len());
        let mut y = 0;
        while y < h {
            let bh = band_rows.min(h - y);
            out.extend_from_slice(&apply_spatial_band(src, w, h, y, bh, p));
            y += bh;
        }
        out
    }

    #[test]
    fn banded_spatial_matches_full_frame() {
        let (w, h) = (96, 80);
        let src = noise(w, h);
        // Engage every op, including the position-dependent vignette/grain,
        // plus the large-radius dehaze and the size-dependent clarity.
        let p = SpatialParams {
            shadows: 0.4,
            highlights: -0.3,
            clarity: 0.5,
            texture: 0.4,
            sharpen: 0.3,
            sharpen_radius: 1.0,
            sharpen_detail: 0.25,
            sharpen_masking: 0.0,
            denoise_luma: 0.2,
            denoise_chroma: 0.5,
            dehaze: 0.3,
            vignette: 0.6,
            vignette_midpoint: 0.5,
            vignette_feather: 0.5,
            vignette_roundness: 0.0,
            vignette_highlights: 0.0,
            grain: 0.2,
            grain_size: 0.25,
            grain_roughness: 0.5,
            ..Default::default()
        };
        let full = apply_spatial(&src, w, h, p);
        for band_rows in [1, 7, 16, 31, 80] {
            let stitched = stitch_bands(&src, w, h, band_rows, p);
            if let Some(i) = stitched.iter().zip(&full).position(|(a, b)| a != b) {
                let px = i / 4;
                panic!(
                    "band_rows={band_rows} diverged at byte {i} (px {},{} c{}): {} vs {}",
                    px % w,
                    px / w,
                    i % 4,
                    stitched[i],
                    full[i]
                );
            }
        }
    }

    #[test]
    fn banded_spatial_matches_for_each_op_alone() {
        let (w, h) = (64, 64);
        let src = noise(w, h);
        let cases = [
            SpatialParams {
                dehaze: 0.8,
                ..Default::default()
            },
            SpatialParams {
                clarity: 0.7,
                ..Default::default()
            },
            SpatialParams {
                shadows: 0.9,
                ..Default::default()
            },
            SpatialParams {
                vignette: 0.9,
                ..Default::default()
            },
            SpatialParams {
                grain: 0.9,
                ..Default::default()
            },
            SpatialParams {
                denoise_chroma: 0.9,
                ..Default::default()
            },
        ];
        for p in cases {
            let full = apply_spatial(&src, w, h, p);
            let stitched = stitch_bands(&src, w, h, 13, p);
            assert_eq!(stitched, full, "diverged for {p:?}");
        }
    }

    #[test]
    fn spatial_local_margin_sums_the_chained_supports() {
        // Chain support compounds: dehaze (3×24=72) + clarity (2×clarity_radius).
        let p = SpatialParams {
            dehaze: 1.0,
            clarity: 1.0,
            ..Default::default()
        };
        assert_eq!(spatial_local_margin(p, 64, 64), 72 + 2 * 4);
        let big = SpatialParams {
            clarity: 1.0,
            ..Default::default()
        };
        // min(4096,4096)/16 = 256, clamped to 64 → 2*64 = 128.
        assert_eq!(spatial_local_margin(big, 4096, 4096), 128);
    }

    #[test]
    fn denoise_is_identity_at_zero() {
        let src = noise(24, 24);
        assert_eq!(denoise(&src, 24, 24, 0.0, 0.0), src);
    }

    #[test]
    fn chroma_denoise_reduces_colour_noise() {
        // Mid grey with per-pixel colour jitter (luma ~constant).
        let (w, h) = (32, 32);
        let mut src = Vec::with_capacity(w * h * 4);
        for i in 0..w * h {
            let j = (i % 17) as u8;
            src.extend_from_slice(&[128 + j, 128, 128 - j, 255]);
        }
        let chroma_spread = |b: &[u8]| {
            b.as_chunks::<4>()
                .0
                .iter()
                .map(|p| (p[0] as i32 - p[2] as i32).unsigned_abs() as u64)
                .sum::<u64>()
        };
        let out = denoise(&src, w, h, 0.0, 1.0);
        assert!(chroma_spread(&out) < chroma_spread(&src));
    }

    #[test]
    fn luma_denoise_preserves_a_hard_edge() {
        let (w, h) = (32, 32);
        let mut src = Vec::with_capacity(w * h * 4);
        for _y in 0..h {
            for x in 0..w {
                let v = if x < w / 2 { 50u8 } else { 200u8 };
                src.extend_from_slice(&[v, v, v, 255]);
            }
        }
        let out = denoise(&src, w, h, 1.0, 0.0);
        let left = out[(10 * w + 3) * 4];
        let right = out[(10 * w + (w - 3)) * 4];
        assert!(
            (right as i32 - left as i32).abs() > 120,
            "edge blurred: {left} vs {right}"
        );
    }

    // --- ROI band bake (#55/#16) ------------------------------------------

    /// Every spatial op engaged — including the absolute-coordinate ops — so
    /// halo and row-offset mistakes surface in the byte comparison.
    fn engaged_spatial() -> SpatialParams {
        SpatialParams {
            shadows: 0.3,
            highlights: -0.2,
            clarity: 0.4,
            texture: 0.2,
            sharpen: 0.3,
            sharpen_radius: 1.0,
            sharpen_detail: 0.25,
            sharpen_masking: 0.0,
            denoise_luma: 0.2,
            denoise_chroma: 0.3,
            dehaze: 0.1,
            vignette: 0.2,
            vignette_midpoint: 0.5,
            vignette_feather: 0.5,
            vignette_roundness: 0.0,
            vignette_highlights: 0.0,
            grain: 0.1,
            grain_size: 0.25,
            grain_roughness: 0.5,
            ..Default::default()
        }
    }

    fn rows(full: &[u8], w: usize, top: usize, count: usize) -> Vec<u8> {
        full[top * w * 4..(top + count) * w * 4].to_vec()
    }

    #[test]
    fn roi_band_matches_the_full_band_in_the_interior() {
        let (w, h) = (64, 320);
        let full = noise(w, h);
        let p = engaged_spatial();
        let margin = spatial_local_margin(p, w, h);
        let out_top = margin + 50;
        let out_rows = 40;
        let decode_top = out_top - margin;
        let band = rows(&full, w, decode_top, out_rows + 2 * margin);
        let out = apply_spatial_roi(&band, (w, h), decode_top, out_top, out_rows, p)
            .expect("roi band bake");
        assert_eq!(out, apply_spatial_band(&full, w, h, out_top, out_rows, p));
    }

    #[test]
    fn roi_band_clamps_context_at_the_image_edges() {
        let (w, h) = (64, 320);
        let full = noise(w, h);
        let p = engaged_spatial();
        let margin = spatial_local_margin(p, w, h);
        let out_rows = 30;

        // Top edge: the decode starts at row 0, so the clamp must match the
        // full-image clamp exactly.
        let band = rows(&full, w, 0, out_rows + margin);
        let top = apply_spatial_roi(&band, (w, h), 0, 0, out_rows, p).expect("top edge");
        assert_eq!(top, apply_spatial_band(&full, w, h, 0, out_rows, p));

        // Bottom edge: the decode ends at row h.
        let out_top = h - out_rows;
        let band = rows(&full, w, out_top - margin, margin + out_rows);
        let bottom = apply_spatial_roi(&band, (w, h), out_top - margin, out_top, out_rows, p)
            .expect("bottom edge");
        assert_eq!(
            bottom,
            apply_spatial_band(&full, w, h, out_top, out_rows, p)
        );
    }

    #[test]
    fn roi_band_errors_when_the_halo_is_insufficient() {
        let (w, h) = (64, 320);
        let full = noise(w, h);
        let p = engaged_spatial();
        let margin = spatial_local_margin(p, w, h);
        assert!(margin > 1, "test assumes an engaged margin");
        let out_top = margin + 10;
        // decode_top > 0 but one row short of the required halo -> seam risk.
        let decode_top = out_top - (margin - 1);
        let band = rows(&full, w, decode_top, (margin - 1) + 20);
        assert!(
            apply_spatial_roi(&band, (w, h), decode_top, out_top, 20, p).is_err(),
            "short halo must be rejected, not clamped into a seam"
        );
    }

    #[test]
    fn neutral_roi_band_returns_the_source_rows() {
        let (w, h) = (32, 64);
        let full = noise(w, h);
        let band = rows(&full, w, 8, 16);
        let out = apply_spatial_roi(&band, (w, h), 8, 10, 12, SpatialParams::default())
            .expect("neutral band");
        assert_eq!(out, rows(&full, w, 10, 12));
    }

    #[test]
    fn roi_band_rejects_malformed_arguments() {
        let (w, h) = (32, 64);
        let full = noise(w, h);
        let p = SpatialParams::default();
        let band = rows(&full, w, 0, 16);
        // Not a whole number of full-width rows.
        assert!(apply_spatial_roi(&band[..8], (w, h), 0, 0, 4, p).is_err());
        // Output outside the decoded band.
        assert!(apply_spatial_roi(&band, (w, h), 0, 12, 8, p).is_err());
        // Output outside the full frame.
        assert!(apply_spatial_roi(&band, (w, h), 0, 60, 8, p).is_err());
        // Empty output.
        assert!(apply_spatial_roi(&band, (w, h), 0, 0, 0, p).is_err());
    }

    #[test]
    fn film_halation_brightens_high_contrast_edges_with_red_bias() {
        let (w, h) = (32, 32);
        let mut img = vec![10u8; w * h * 4];
        for i in 0..w * h {
            img[i * 4 + 3] = 255;
        }
        // Center 4x4 specular highlight: full white
        for y in 14..18 {
            for x in 14..18 {
                let idx = (y * w + x) * 4;
                img[idx] = 255;
                img[idx + 1] = 255;
                img[idx + 2] = 255;
            }
        }

        let p = SpatialParams {
            film_halation: 1.0,
            film_halation_radius: 0.5,
            film_halation_threshold: 0.7,
            ..Default::default()
        };
        let out = apply_spatial(&img, w, h, p);

        // Spot-check adjacent neighbor (14, 13) which was dark (10, 10, 10)
        let n_idx = (14 * w + 13) * 4;
        let r = out[n_idx];
        let g = out[n_idx + 1];
        let b = out[n_idx + 2];
        // Halation should cause red channel to brighten more than green or blue
        assert!(r > 10, "halation must brighten surrounding red channel");
        assert!(
            r > g && r > b,
            "halation must exhibit red emulsion bias: r={}, g={}, b={}",
            r,
            g,
            b
        );
    }

    #[test]
    fn film_bloom_diffuses_specular_highlights() {
        let (w, h) = (32, 32);
        let mut img = vec![0u8; w * h * 4];
        for i in 0..w * h {
            img[i * 4 + 3] = 255;
        }
        // Center bright highlight
        for y in 14..18 {
            for x in 14..18 {
                let idx = (y * w + x) * 4;
                img[idx] = 255;
                img[idx + 1] = 255;
                img[idx + 2] = 255;
            }
        }

        let p = SpatialParams {
            film_bloom: 1.0,
            film_bloom_radius: 0.5,
            film_bloom_threshold: 0.6,
            ..Default::default()
        };
        let out = apply_spatial(&img, w, h, p);

        // Adjacent dark pixel should receive optical diffusion bloom
        let n_idx = (14 * w + 12) * 4;
        assert!(out[n_idx] > 0, "bloom must diffuse light to surround");
        assert_eq!(
            out[n_idx],
            out[n_idx + 1],
            "bloom is neutral optical diffusion"
        );
    }

    #[test]
    fn film_dust_and_scratches_adds_deterministic_emulsion_flecks() {
        let (w, h) = (64, 64);
        let mut img = vec![180u8; w * h * 4];
        for i in 0..w * h {
            img[i * 4 + 3] = 255;
        }

        let p = SpatialParams {
            film_dust: 0.8,
            film_scratches: 0.8,
            ..Default::default()
        };
        let out1 = apply_spatial(&img, w, h, p);
        let out2 = apply_spatial(&img, w, h, p);

        // Deterministic: multiple runs give identical results
        assert_eq!(out1, out2);
        // And flecks / scratches alter pixel values from pure 180
        assert_ne!(out1, img);
    }

    #[test]
    fn shader_lab_preset_vhs_applies_chromatic_jitter() {
        let (w, h) = (32, 32);
        let img = noise(w, h);

        let p = SpatialParams {
            shader_lab_preset: 1, // VHS
            shader_param1: 0.8,
            ..Default::default()
        };
        let out = apply_spatial(&img, w, h, p);
        assert_ne!(out, img, "VHS shader must apply analog effect");
    }
}
