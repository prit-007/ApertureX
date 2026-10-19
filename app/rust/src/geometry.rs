//! Geometry: non-destructive crop, rotate (90° steps), flip, and straighten.
//! Applied to the pixel buffer as the first stage of the render/export pipeline.

use std::borrow::Cow;

/// Flips horizontally (mirror left↔right).
pub fn flip_h(rgba: &[u8], w: usize, h: usize) -> Vec<u8> {
    let mut out = vec![0u8; w * h * 4];
    for y in 0..h {
        for x in 0..w {
            let src = (y * w + x) * 4;
            let dst = (y * w + (w - 1 - x)) * 4;
            out[dst..dst + 4].copy_from_slice(&rgba[src..src + 4]);
        }
    }
    out
}

/// Flips vertically (mirror top↔bottom).
pub fn flip_v(rgba: &[u8], w: usize, h: usize) -> Vec<u8> {
    let mut out = vec![0u8; w * h * 4];
    for y in 0..h {
        let src = y * w * 4;
        let dst = (h - 1 - y) * w * 4;
        out[dst..dst + w * 4].copy_from_slice(&rgba[src..src + w * 4]);
    }
    out
}

/// Rotates 90° clockwise. Returns `(buffer, new_w, new_h)`.
pub fn rotate_90_cw(rgba: &[u8], w: usize, h: usize) -> (Vec<u8>, usize, usize) {
    let (nw, nh) = (h, w);
    let mut out = vec![0u8; nw * nh * 4];
    for y in 0..h {
        for x in 0..w {
            // (x,y) -> (h-1-y, x) in the new frame.
            let nx = h - 1 - y;
            let ny = x;
            let src = (y * w + x) * 4;
            let dst = (ny * nw + nx) * 4;
            out[dst..dst + 4].copy_from_slice(&rgba[src..src + 4]);
        }
    }
    (out, nw, nh)
}

/// Rotates by a multiple of 90° clockwise (`turns` ∈ {0,1,2,3}).
pub fn rotate_quarter(rgba: &[u8], w: usize, h: usize, turns: u32) -> (Vec<u8>, usize, usize) {
    match turns % 4 {
        0 => (rgba.to_vec(), w, h),
        1 => rotate_90_cw(rgba, w, h),
        2 => (rotate_90_cw(&rotate_90_cw(rgba, w, h).0, h, w).0, w, h),
        _ => rotate_90_cw(&rotate_90_cw(&rotate_90_cw(rgba, w, h).0, h, w).0, w, h),
    }
}

/// Crops to `(x, y, cw, ch)` (clamped to the image). Returns `cw*ch*4` bytes.
pub fn crop(rgba: &[u8], w: usize, h: usize, x: usize, y: usize, cw: usize, ch: usize) -> Vec<u8> {
    let x = x.min(w.saturating_sub(1));
    let y = y.min(h.saturating_sub(1));
    let cw = cw.min(w - x);
    let ch = ch.min(h - y);
    let mut out = Vec::with_capacity(cw * ch * 4);
    for row in 0..ch {
        let start = ((y + row) * w + x) * 4;
        out.extend_from_slice(&rgba[start..start + cw * 4]);
    }
    out
}

/// Bilinear sample of `rgba` (clamped edge).
fn sample(rgba: &[u8], w: usize, h: usize, fx: f32, fy: f32) -> [u8; 4] {
    let x = fx.clamp(0.0, (w - 1) as f32);
    let y = fy.clamp(0.0, (h - 1) as f32);
    let x0 = x.floor() as usize;
    let y0 = y.floor() as usize;
    let x1 = (x0 + 1).min(w - 1);
    let y1 = (y0 + 1).min(h - 1);
    let tx = x - x0 as f32;
    let ty = y - y0 as f32;
    let idx = |xx: usize, yy: usize| (yy * w + xx) * 4;
    let mut out = [0u8; 4];
    for c in 0..3 {
        let a = rgba[idx(x0, y0) + c] as f32;
        let b = rgba[idx(x1, y0) + c] as f32;
        let cc = rgba[idx(x0, y1) + c] as f32;
        let d = rgba[idx(x1, y1) + c] as f32;
        out[c] = (a + (b - a) * tx + (cc - a) * ty + (a - b - cc + d) * tx * ty)
            .round()
            .clamp(0.0, 255.0) as u8;
    }
    out[3] = 255;
    out
}

/// Rotates by `angle_deg` around the centre (bilinear), same output size
/// (corners may be transparent-black — use [`inscribed_rect`] to crop them).
pub fn straighten(rgba: &[u8], w: usize, h: usize, angle_deg: f32) -> Vec<u8> {
    if angle_deg == 0.0 {
        return rgba.to_vec();
    }
    let a = angle_deg.to_radians();
    let (ca, sa) = (a.cos(), a.sin());
    let (cx, cy) = ((w - 1) as f32 / 2.0, (h - 1) as f32 / 2.0);
    let mut out = vec![0u8; w * h * 4];
    for y in 0..h {
        for x in 0..w {
            let dx = x as f32 - cx;
            let dy = y as f32 - cy;
            let sx = cx + dx * ca + dy * sa;
            let sy = cy - dx * sa + dy * ca;
            let px = sample(rgba, w, h, sx, sy);
            let dst = (y * w + x) * 4;
            out[dst..dst + 4].copy_from_slice(&px);
        }
    }
    out
}

/// The largest centred axis-aligned rect that stays inside a `w×h` image
/// rotated by `angle_deg` — the safe straighten crop, `[x, y, cw, ch]`.
pub fn inscribed_rect(w: usize, h: usize, angle_deg: f32) -> [usize; 4] {
    if angle_deg == 0.0 {
        return [0, 0, w, h];
    }
    let a = angle_deg.abs().to_radians();
    let (wf, hf) = (w as f32, h as f32);
    let (sin, cos) = (a.sin().abs(), a.cos().abs());
    // Largest rect of the original aspect that fits inside the rotated frame.
    let scale = 1.0 / (cos + sin * hf / wf).max(cos + sin * wf / hf);
    let cw = (wf * scale).floor().max(1.0) as usize;
    let ch = (hf * scale).floor().max(1.0) as usize;
    [(w - cw) / 2, (h - ch) / 2, cw, ch]
}

/// Bilinear downscale so the longest side is at most `max_dim`. A `max_dim` of
/// 0 (or an already-small image) returns a copy at the original size.
pub fn downscale(rgba: &[u8], w: usize, h: usize, max_dim: usize) -> (Vec<u8>, usize, usize) {
    let longest = w.max(h);
    if max_dim == 0 || longest <= max_dim {
        return (rgba.to_vec(), w, h);
    }
    let scale = max_dim as f32 / longest as f32;
    let nw = ((w as f32 * scale).round() as usize).max(1);
    let nh = ((h as f32 * scale).round() as usize).max(1);
    let mut out = vec![0u8; nw * nh * 4];
    for y in 0..nh {
        for x in 0..nw {
            let sx = (x as f32 + 0.5) / scale - 0.5;
            let sy = (y as f32 + 0.5) / scale - 0.5;
            let px = sample(rgba, w, h, sx, sy);
            let i = (y * nw + x) * 4;
            out[i..i + 4].copy_from_slice(&px);
        }
    }
    (out, nw, nh)
}

/// Applies trapezoidal perspective + skew as a bilinear remap. Output stays
/// `w × h`; empty areas become black with alpha=255.  All params are neutral
/// at zero; typical range is [-1, 1].
pub fn perspective_warp(
    rgba: &[u8],
    w: usize,
    h: usize,
    perspective_x: f32,
    perspective_y: f32,
    skew_x: f32,
    skew_y: f32,
) -> Vec<u8> {
    if perspective_x == 0.0 && perspective_y == 0.0 && skew_x == 0.0 && skew_y == 0.0 {
        return rgba.to_vec();
    }

    let mut out = vec![0u8; w * h * 4];

    // Corner control points (normalized). Positive perspectiveX widens the bottom (taller look),
    // positive skewX shifts the top right relative to the bottom.
    let tl = [
        0.5 - 0.5 * (1.0 - perspective_x) * (1.0 - skew_x),
        0.5 - 0.5 * (1.0 - perspective_y) * (1.0 - skew_y),
    ];
    let tr = [
        0.5 + 0.5 * (1.0 - perspective_x) * (1.0 + skew_x),
        0.5 - 0.5 * (1.0 - perspective_y) * (1.0 + skew_y),
    ];
    let bl = [
        0.5 - 0.5 * (1.0 + perspective_x) * (1.0 - skew_x),
        0.5 + 0.5 * (1.0 + perspective_y) * (1.0 - skew_y),
    ];
    let br = [
        0.5 + 0.5 * (1.0 + perspective_x) * (1.0 + skew_x),
        0.5 + 0.5 * (1.0 + perspective_y) * (1.0 + skew_y),
    ];

    for y in 0..h {
        for x in 0..w {
            let u = x as f32 / (w.max(1) - 1) as f32;
            let v = y as f32 / (h.max(1) - 1) as f32;

            // Bilinear interpolation onto the quad.
            let sx = tl[0] * (1.0 - u) * (1.0 - v)
                + tr[0] * u * (1.0 - v)
                + bl[0] * (1.0 - u) * v
                + br[0] * u * v;
            let sy = tl[1] * (1.0 - u) * (1.0 - v)
                + tr[1] * u * (1.0 - v)
                + bl[1] * (1.0 - u) * v
                + br[1] * u * v;

            let px = sample(
                rgba,
                w,
                h,
                sx * (w.max(1) - 1) as f32,
                sy * (h.max(1) - 1) as f32,
            );
            let dst = (y * w + x) * 4;
            out[dst..dst + 4].copy_from_slice(&px);
        }
    }

    out
}

/// The full geometry chain (export + FFI): flip → rotate → straighten →
/// normalized crop → perspective/skew. All fields are neutral by default.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct GeometrySpec {
    pub flip_h: bool,
    pub flip_v: bool,
    /// Quarter-turns clockwise (any multiple of 4 is identity).
    pub turns: u32,
    /// Straighten angle in degrees (0 = off).
    pub angle: f32,
    /// Normalized `[0,1]` crop in the transformed frame.
    pub crop_l: f32,
    pub crop_t: f32,
    pub crop_r: f32,
    pub crop_b: f32,
    pub perspective_x: f32,
    pub perspective_y: f32,
    pub skew_x: f32,
    pub skew_y: f32,
}

impl Default for GeometrySpec {
    fn default() -> Self {
        Self {
            flip_h: false,
            flip_v: false,
            turns: 0,
            angle: 0.0,
            crop_l: 0.0,
            crop_t: 0.0,
            crop_r: 1.0,
            crop_b: 1.0,
            perspective_x: 0.0,
            perspective_y: 0.0,
            skew_x: 0.0,
            skew_y: 0.0,
        }
    }
}

impl GeometrySpec {
    /// True when the chain leaves the buffer byte-identical.
    pub fn is_identity(&self) -> bool {
        *self == Self::default()
    }
}

/// Normalized `[0,1]` crop, returning `None` when the rect is the identity or
/// degenerate so callers keep their buffer instead of paying a full-frame copy.
pub fn crop_rect(
    w: usize,
    h: usize,
    crop_l: f32,
    crop_t: f32,
    crop_r: f32,
    crop_b: f32,
) -> Option<(usize, usize, usize, usize)> {
    let (cl, ct, cr, cb) = (
        crop_l.clamp(0.0, 1.0),
        crop_t.clamp(0.0, 1.0),
        crop_r.clamp(0.0, 1.0),
        crop_b.clamp(0.0, 1.0),
    );
    if cl == 0.0 && ct == 0.0 && cr == 1.0 && cb == 1.0 {
        return None;
    }
    if cr <= cl || cb <= ct || w == 0 || h == 0 {
        return None;
    }
    let x = ((cl * w as f32).round() as usize).min(w.saturating_sub(1));
    let y = ((ct * h as f32).round() as usize).min(h.saturating_sub(1));
    let max_w = (w - x).max(1);
    let max_h = (h - y).max(1);
    let cw = (((cr - cl) * w as f32).round() as usize).clamp(1, max_w);
    let ch = (((cb - ct) * h as f32).round() as usize).clamp(1, max_h);
    Some((x, y, cw, ch))
}

pub fn crop_normalized(
    buf: &[u8],
    w: usize,
    h: usize,
    crop_l: f32,
    crop_t: f32,
    crop_r: f32,
    crop_b: f32,
) -> Option<(Vec<u8>, usize, usize)> {
    let (x, y, cw, ch) = crop_rect(w, h, crop_l, crop_t, crop_r, crop_b)?;
    Some((crop(buf, w, h, x, y, cw, ch), cw, ch))
}

/// Applies the whole geometry chain: flip → rotate (90° × turns) → straighten
/// (crop to the inscribed rect) → normalized crop → perspective/skew.
/// Returns `(buffer, width, height)`.
///
/// Uses `Cow` so an identity spec never copies the source — the FFI wrapper
/// passes a borrowed slice and only engaged ops allocate.
pub fn apply_spec(rgba: &[u8], w: usize, h: usize, spec: &GeometrySpec) -> (Vec<u8>, usize, usize) {
    let mut buf = Cow::Borrowed(rgba);
    let (mut w, mut h) = (w, h);

    if spec.flip_h {
        buf = Cow::Owned(flip_h(&buf, w, h));
    }
    if spec.flip_v {
        buf = Cow::Owned(flip_v(&buf, w, h));
    }
    if !spec.turns.is_multiple_of(4) {
        let (b, nw, nh) = rotate_quarter(&buf, w, h, spec.turns);
        buf = Cow::Owned(b);
        w = nw;
        h = nh;
    }
    if spec.angle != 0.0 {
        let rotated = straighten(&buf, w, h, spec.angle);
        let [x, y, cw, ch] = inscribed_rect(w, h, spec.angle);
        buf = Cow::Owned(crop(&rotated, w, h, x, y, cw, ch));
        w = cw;
        h = ch;
    }
    if let Some((cropped, cw, ch)) = crop_normalized(
        &buf,
        w,
        h,
        spec.crop_l,
        spec.crop_t,
        spec.crop_r,
        spec.crop_b,
    ) {
        buf = Cow::Owned(cropped);
        w = cw;
        h = ch;
    }
    buf = Cow::Owned(perspective_warp(
        &buf,
        w,
        h,
        spec.perspective_x,
        spec.perspective_y,
        spec.skew_x,
        spec.skew_y,
    ));

    (buf.into_owned(), w, h)
}

/// Automatically detects the corrective horizon/straighten angle in degrees.
/// Uses gradient orientation voting on edge pixels within +/- 20 degrees.
/// Returns the correction angle in degrees to straighten the photo (e.g., -4.0 to correct +4.0 tilt).
pub fn detect_straighten_angle(rgba: &[u8], w: usize, h: usize) -> f32 {
    if w < 16 || h < 16 || rgba.len() < w * h * 4 {
        return 0.0;
    }

    // Downscale proxy if large (target long edge around 256 for fast sub-millisecond scan)
    let scale = (w.max(h) as f32 / 256.0).max(1.0);
    let sw = (w as f32 / scale).round() as usize;
    let sh = (h as f32 / scale).round() as usize;
    if sw < 8 || sh < 8 {
        return 0.0;
    }

    // Extract grayscale luma
    let mut luma = Vec::with_capacity(sw * sh);
    for y in 0..sh {
        let src_y = ((y as f32 + 0.5) * scale) as usize;
        let sy = src_y.min(h - 1);
        for x in 0..sw {
            let src_x = ((x as f32 + 0.5) * scale) as usize;
            let sx = src_x.min(w - 1);
            let idx = (sy * w + sx) * 4;
            let y_val = 0.2126 * rgba[idx] as f32
                + 0.7152 * rgba[idx + 1] as f32
                + 0.0722 * rgba[idx + 2] as f32;
            luma.push(y_val);
        }
    }

    // Histogram bins covering [-20.0, +20.0] degrees in 0.25-degree increments (161 bins)
    const MAX_ANGLE: f32 = 20.0;
    const BIN_STEP: f32 = 0.25;
    let num_bins = (MAX_ANGLE * 2.0 / BIN_STEP).round() as usize + 1;
    let mut accumulator = vec![0.0f32; num_bins];

    // Compute Sobel gradients in interior, avoiding image borders
    let margin_x = (sw / 8).max(1);
    let margin_y = (sh / 8).max(1);

    for y in margin_y..(sh - margin_y) {
        for x in margin_x..(sw - margin_x) {
            let p00 = luma[(y - 1) * sw + (x - 1)];
            let p01 = luma[(y - 1) * sw + x];
            let p02 = luma[(y - 1) * sw + (x + 1)];

            let p10 = luma[y * sw + (x - 1)];
            let p12 = luma[y * sw + (x + 1)];

            let p20 = luma[(y + 1) * sw + (x - 1)];
            let p21 = luma[(y + 1) * sw + x];
            let p22 = luma[(y + 1) * sw + (x + 1)];

            let gx = (p02 + 2.0 * p12 + p22) - (p00 + 2.0 * p10 + p20);
            let gy = (p20 + 2.0 * p21 + p22) - (p00 + 2.0 * p01 + p02);

            let mag_sq = gx * gx + gy * gy;
            if mag_sq < 20.0 * 20.0 {
                continue;
            }

            // Normal angle to the gradient is the edge line direction
            let edge_angle_rad = (-gx).atan2(gy);
            let mut angle_deg = edge_angle_rad.to_degrees();

            // Fold into [-90, 90] range (lines have 180-degree symmetry)
            while angle_deg > 90.0 {
                angle_deg -= 180.0;
            }
            while angle_deg < -90.0 {
                angle_deg += 180.0;
            }

            if angle_deg.abs() <= MAX_ANGLE {
                let bin = ((angle_deg + MAX_ANGLE) / BIN_STEP).round() as usize;
                if bin < num_bins {
                    accumulator[bin] += mag_sq.sqrt();
                }
            }
        }
    }

    // Find the peak in the accumulator
    let mut best_bin = 0;
    let mut max_votes = 0.0f32;
    for (i, &votes) in accumulator.iter().enumerate() {
        if votes > max_votes {
            max_votes = votes;
            best_bin = i;
        }
    }

    if max_votes < 100.0 {
        return 0.0;
    }

    let detected_tilt = best_bin as f32 * BIN_STEP - MAX_ANGLE;
    -detected_tilt
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn perspective_warp_identity_is_no_op() {
        let src = grid(16, 16);
        assert_eq!(perspective_warp(&src, 16, 16, 0.0, 0.0, 0.0, 0.0), src);
    }

    #[test]
    fn perspective_warp_stays_same_dimensions() {
        let src = grid(32, 24);
        let out = perspective_warp(&src, 32, 24, 0.5, 0.3, 0.2, 0.1);
        assert_eq!(out.len(), 32 * 24 * 4);
        assert_ne!(out, src);
    }

    fn pixel(w: usize, x: usize, y: usize, rgba: &[u8]) -> [u8; 4] {
        let i = (y * w + x) * 4;
        [rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]]
    }

    /// Encodes x in R and y in G so positions are checkable.
    fn grid(w: usize, h: usize) -> Vec<u8> {
        let mut v = Vec::with_capacity(w * h * 4);
        for y in 0..h {
            for x in 0..w {
                v.extend_from_slice(&[x as u8, y as u8, 0, 255]);
            }
        }
        v
    }

    #[test]
    fn downscale_caps_the_long_side() {
        let src = grid(40, 20);
        let (out, w, h) = downscale(&src, 40, 20, 10);
        assert_eq!(w.max(h), 10);
        assert_eq!(out.len(), w * h * 4);
        // max_dim 0 means no resize
        let (_, w2, h2) = downscale(&src, 40, 20, 0);
        assert_eq!((w2, h2), (40, 20));
    }

    #[test]
    fn flip_h_mirrors() {
        let src = grid(4, 2);
        let out = flip_h(&src, 4, 2);
        assert_eq!(pixel(4, 0, 0, &out), [3, 0, 0, 255]);
        assert_eq!(pixel(4, 3, 0, &out), [0, 0, 0, 255]);
    }

    #[test]
    fn flip_v_mirrors() {
        let out = flip_v(&grid(4, 2), 4, 2);
        assert_eq!(pixel(4, 0, 0, &out), [0, 1, 0, 255]);
    }

    #[test]
    fn rotate_90_swaps_dimensions_and_maps_corners() {
        let (out, nw, nh) = rotate_90_cw(&grid(4, 2), 4, 2);
        assert_eq!((nw, nh), (2, 4));
        // top-left (x=0,y=0) -> top-right in the new frame.
        assert_eq!(pixel(nw, nw - 1, 0, &out), [0, 0, 0, 255]);
        assert_eq!(pixel(nw, 0, 0, &out), [0, 1, 0, 255]);
    }

    #[test]
    fn rotate_identity_and_180() {
        let src = grid(4, 2);
        let (id, w, h) = rotate_quarter(&src, 4, 2, 0);
        assert_eq!((w, h), (4, 2));
        assert_eq!(id, src);

        let (r180, _, _) = rotate_quarter(&src, 4, 2, 2);
        assert_eq!(pixel(4, 0, 0, &r180), [3, 1, 0, 255]);
    }

    #[test]
    fn crop_extracts_a_sub_rect() {
        let out = crop(&grid(4, 4), 4, 4, 1, 1, 2, 2);
        assert_eq!(out.len(), 2 * 2 * 4);
        assert_eq!(pixel(2, 0, 0, &out), [1, 1, 0, 255]);
    }

    #[test]
    fn straighten_zero_is_identity_and_nonzero_rotates() {
        let src = grid(9, 9);
        assert_eq!(straighten(&src, 9, 9, 0.0), src);
        let out = straighten(&src, 9, 9, 20.0);
        assert_eq!(out.len(), src.len());
        assert_ne!(out, src);
    }

    #[test]
    fn inscribed_rect_at_zero_is_the_whole_image() {
        assert_eq!(inscribed_rect(100, 50, 0.0), [0, 0, 100, 50]);
        let [_, _, cw, ch] = inscribed_rect(100, 50, 10.0);
        assert!(cw < 100 && ch < 50);
    }

    #[test]
    fn default_geometry_spec_is_identity() {
        assert!(GeometrySpec::default().is_identity());
        let src = grid(6, 4);
        let (out, w, h) = apply_spec(&src, 6, 4, &GeometrySpec::default());
        assert_eq!((w, h), (6, 4));
        assert_eq!(out, src);
    }

    #[test]
    fn apply_spec_chain_matches_manual_order() {
        // flip_h → rotate 90 cw → crop, applied in that order.
        let src = grid(4, 2);
        let spec = GeometrySpec {
            flip_h: true,
            turns: 1,
            crop_l: 0.0,
            crop_t: 0.0,
            crop_r: 1.0,
            crop_b: 0.5,
            ..Default::default()
        };
        let (out, w, h) = apply_spec(&src, 4, 2, &spec);

        let flipped = flip_h(&src, 4, 2);
        let (rotated, rw, rh) = rotate_quarter(&flipped, 4, 2, 1);
        let (cropped, cw, ch) = crop_normalized(&rotated, rw, rh, 0.0, 0.0, 1.0, 0.5).unwrap();
        assert_eq!((w, h), (cw, ch));
        assert_eq!(out, cropped);
    }

    #[test]
    fn crop_normalized_none_on_identity_and_degenerate() {
        let src = grid(4, 4);
        assert!(crop_normalized(&src, 4, 4, 0.0, 0.0, 1.0, 1.0).is_none());
        assert!(crop_normalized(&src, 4, 4, 0.5, 0.5, 0.5, 1.0).is_none());
    }

    #[test]
    fn detect_straighten_angle_on_blank_returns_zero() {
        let blank = vec![128u8; 64 * 64 * 4];
        let angle = detect_straighten_angle(&blank, 64, 64);
        assert_eq!(angle, 0.0);
    }

    #[test]
    fn detect_straighten_angle_on_horizontal_horizon() {
        let w = 120;
        let h = 80;
        let mut img = vec![255u8; w * h * 4];
        for y in (h / 2)..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                img[idx] = 20;
                img[idx + 1] = 20;
                img[idx + 2] = 20;
            }
        }
        let angle = detect_straighten_angle(&img, w, h);
        assert!(angle.abs() <= 0.5, "Expected close to 0.0, got {}", angle);
    }

    #[test]
    fn detect_straighten_angle_on_tilted_horizon() {
        let w = 160;
        let h = 120;
        let target_tilt_deg: f32 = 4.0;
        let slope = (target_tilt_deg.to_radians()).tan();
        let mid_y = (h / 2) as f32;
        let mid_x = (w / 2) as f32;

        let mut img = vec![0u8; w * h * 4];
        for y in 0..h {
            for x in 0..w {
                let horizon_y = mid_y + (x as f32 - mid_x) * slope;
                let dist = (y as f32 - horizon_y).clamp(-4.0, 4.0);
                let val = (120.0 - dist * 20.0).round() as u8;
                let idx = (y * w + x) * 4;
                img[idx] = val;
                img[idx + 1] = val;
                img[idx + 2] = val;
                img[idx + 3] = 255;
            }
        }
        let correction = detect_straighten_angle(&img, w, h);
        // Tilt is +4 deg, so correction should be approx -4 deg
        assert!(
            (correction - (-target_tilt_deg)).abs() <= 1.0,
            "Expected correction ~ -{}, got {}",
            target_tilt_deg,
            correction
        );
    }

    #[test]
    fn crop_normalized_does_not_panic_on_boundary_rounding() {
        let buf = vec![0u8; 100 * 100 * 4];
        // Test near right/bottom edges where round() could hit w or h
        let res = crop_normalized(&buf, 100, 100, 0.999, 0.999, 1.0, 1.0);
        assert!(res.is_some());
        let (cropped, cw, ch) = res.unwrap();
        assert_eq!(cropped.len(), cw * ch * 4);

        // Zero dimensions
        assert!(crop_normalized(&buf, 0, 0, 0.1, 0.1, 0.9, 0.9).is_none());
    }
}
