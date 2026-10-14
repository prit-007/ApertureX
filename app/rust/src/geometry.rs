//! Geometry: non-destructive crop, rotate (90° steps), flip, and straighten.
//! Applied to the pixel buffer as the first stage of the render/export pipeline.

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
}
