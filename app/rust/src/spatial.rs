//! Spatial (neighbour-aware) operations (P2). These cannot live in the
//! per-pixel LUT, so they run as their own pass.
//!
//! Every op is a function over a full RGBA buffer. The preview/export tile
//! engine must call them through [`process_tile_padded`], which fetches a
//! margin of neighbour pixels and crops it off afterwards — otherwise blur-based
//! ops leave visible seams at tile boundaries (ADR 0011).

/// Separable box blur of one channel (horizontal then vertical), edge-clamped.
fn box_blur_1d(src: &[f32], w: usize, h: usize, radius: usize) -> Vec<f32> {
    if radius == 0 {
        return src.to_vec();
    }
    let mut tmp = vec![0f32; w * h];
    for y in 0..h {
        let row = y * w;
        for x in 0..w {
            let lo = x.saturating_sub(radius);
            let hi = (x + radius).min(w - 1);
            let mut sum = 0.0;
            for k in lo..=hi {
                sum += src[row + k];
            }
            tmp[row + x] = sum / (hi - lo + 1) as f32;
        }
    }
    let mut out = vec![0f32; w * h];
    for x in 0..w {
        for y in 0..h {
            let lo = y.saturating_sub(radius);
            let hi = (y + radius).min(h - 1);
            let mut sum = 0.0;
            for k in lo..=hi {
                sum += tmp[k * w + x];
            }
            out[y * w + x] = sum / (hi - lo + 1) as f32;
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

/// Clarity: mid-frequency local contrast — large blur radius (a Gaussian
/// approximation of the spec's edge-preserving base/detail split).
pub fn apply_clarity(rgba: &[u8], w: usize, h: usize, amount: f32) -> Vec<u8> {
    if amount == 0.0 {
        return rgba.to_vec();
    }
    let radius = (w.min(h) / 16).clamp(4, 64);
    unsharp(rgba, &blur_rgb(rgba, w, h, radius, 2), amount)
}

/// Sharpening: unsharp mask with a caller-chosen radius/amount.
pub fn apply_sharpen(rgba: &[u8], w: usize, h: usize, amount: f32, radius: usize) -> Vec<u8> {
    if amount == 0.0 {
        return rgba.to_vec();
    }
    unsharp(rgba, &blur_rgb(rgba, w, h, radius.max(1), 1), amount)
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
    if shadows == 0.0 && highlights == 0.0 {
        return rgba.to_vec();
    }
    let radius = (w.min(h) / 16).clamp(4, 64);
    let base = blur_rgb(rgba, w, h, radius, 2);
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

    #[test]
    fn blur_preserves_size_alpha_and_smooths() {
        let src = noise(32, 32);
        let out = blur_rgb(&src, 32, 32, 3, 2);
        assert_eq!(out.len(), src.len());
        assert!(out.iter().skip(3).step_by(4).all(|&a| a == 255));
        assert!(variance(&out) < variance(&src));
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
    fn padded_tile_handles_the_image_border() {
        let (w, h) = (20, 20);
        let src = noise(w, h);
        // A corner tile; padding clamps at the border (must not panic).
        let out = process_tile_padded(&src, w, h, (0, 0, 8, 8), 4, |b, iw, ih| {
            blur_rgb(b, iw, ih, 4, 1)
        });
        assert_eq!(out.len(), 8 * 8 * 4);
    }
}
