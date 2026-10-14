//! Geometry API across the `flutter_rust_bridge` boundary.
//!
//! Wrappers over [`crate::geometry`]. Each returns pixels; the caller keeps the
//! returned dimensions.

use crate::geometry;

/// Rotated/cropped result: pixels plus the new dimensions.
pub struct GeometryResult {
    pub width: u32,
    pub height: u32,
    pub rgba: Vec<u8>,
}

/// Flips horizontally/vertically.
pub fn geometry_flip(rgba: Vec<u8>, width: u32, height: u32, horizontal: bool) -> GeometryResult {
    let (w, h) = (width as usize, height as usize);
    let out = if horizontal {
        geometry::flip_h(&rgba, w, h)
    } else {
        geometry::flip_v(&rgba, w, h)
    };
    GeometryResult {
        width,
        height,
        rgba: out,
    }
}

/// Rotates by `turns` × 90° clockwise.
pub fn geometry_rotate(rgba: Vec<u8>, width: u32, height: u32, turns: u32) -> GeometryResult {
    let (out, w, h) = geometry::rotate_quarter(&rgba, width as usize, height as usize, turns);
    GeometryResult {
        width: w as u32,
        height: h as u32,
        rgba: out,
    }
}

/// Crops to `(x, y, cw, ch)`.
pub fn geometry_crop(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    x: u32,
    y: u32,
    cw: u32,
    ch: u32,
) -> GeometryResult {
    let out = geometry::crop(
        &rgba,
        width as usize,
        height as usize,
        x as usize,
        y as usize,
        cw as usize,
        ch as usize,
    );
    GeometryResult {
        width: cw,
        height: ch,
        rgba: out,
    }
}

/// Straightens by `angle_deg`, then crops to the largest safe inscribed rect.
pub fn geometry_straighten(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    angle_deg: f32,
) -> GeometryResult {
    let (w, h) = (width as usize, height as usize);
    let rotated = geometry::straighten(&rgba, w, h, angle_deg);
    let [x, y, cw, ch] = geometry::inscribed_rect(w, h, angle_deg);
    let cropped = geometry::crop(&rotated, w, h, x, y, cw, ch);
    GeometryResult {
        width: cw as u32,
        height: ch as u32,
        rgba: cropped,
    }
}

/// Applies the whole geometry chain: flip → rotate (90° × turns) → straighten →
/// crop (normalized `[0,1]`, applied in the transformed frame) → perspective/skew.
#[allow(clippy::too_many_arguments)]
pub fn geometry_apply(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    flip_h: bool,
    flip_v: bool,
    turns: u32,
    angle: f32,
    crop_l: f32,
    crop_t: f32,
    crop_r: f32,
    crop_b: f32,
    perspective_x: f32,
    perspective_y: f32,
    skew_x: f32,
    skew_y: f32,
) -> GeometryResult {
    let mut w = width as usize;
    let mut h = height as usize;
    let mut buf = rgba;

    if flip_h {
        buf = geometry::flip_h(&buf, w, h);
    }
    if flip_v {
        buf = geometry::flip_v(&buf, w, h);
    }
    if !turns.is_multiple_of(4) {
        let (b, nw, nh) = geometry::rotate_quarter(&buf, w, h, turns);
        buf = b;
        w = nw;
        h = nh;
    }
    if angle != 0.0 {
        let rotated = geometry::straighten(&buf, w, h, angle);
        let [x, y, cw, ch] = geometry::inscribed_rect(w, h, angle);
        buf = geometry::crop(&rotated, w, h, x, y, cw, ch);
        w = cw;
        h = ch;
    }

    // Crop: normalized [0,1] rect in the (now transformed) frame.
    let (cl, ct, cr, cb) = (
        crop_l.clamp(0.0, 1.0),
        crop_t.clamp(0.0, 1.0),
        crop_r.clamp(0.0, 1.0),
        crop_b.clamp(0.0, 1.0),
    );
        if !(cl == 0.0 && ct == 0.0 && cr == 1.0 && cb == 1.0) && cr > cl && cb > ct {
            let x = (cl * w as f32).round() as usize;
            let y = (ct * h as f32).round() as usize;
            let cw = (((cr - cl) * w as f32).round() as usize).clamp(1, w - x);
            let ch = (((cb - ct) * h as f32).round() as usize).clamp(1, h - y);
            buf = geometry::crop(&buf, w, h, x, y, cw, ch);
            w = cw;
            h = ch;
        }

    // Perspective/skew: bilinear remap on same dimensions.
    let warped = crate::geometry::perspective_warp(&buf, w, h, perspective_x, perspective_y, skew_x, skew_y);

    GeometryResult {
        width: w as u32,
        height: h as u32,
        rgba: warped,
    }
}

/// Bilinear downscale so the longest side is at most `max_dim`.
pub fn geometry_downscale(rgba: Vec<u8>, width: u32, height: u32, max_dim: u32) -> GeometryResult {
    let (out, w, h) = geometry::downscale(&rgba, width as usize, height as usize, max_dim as usize);
    GeometryResult {
        width: w as u32,
        height: h as u32,
        rgba: out,
    }
}

/// Applies trapezoidal perspective + skew. Same output dimensions as input.
pub fn geometry_perspective_rgba(rgba: Vec<u8>, width: u32, height: u32, perspective_x: f32, perspective_y: f32, skew_x: f32, skew_y: f32) -> GeometryResult {
    let (w, h) = (width as usize, height as usize);
    let out = crate::geometry::perspective_warp(&rgba, w, h, perspective_x, perspective_y, skew_x, skew_y);
    GeometryResult {
        width,
        height,
        rgba: out,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

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
    fn normalized_crop_selects_the_right_region() {
        let src = grid(4, 4);
        let r = geometry_apply(src, 4, 4, false, false, 0, 0.0, 0.5, 0.5, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0);
        assert_eq!((r.width, r.height), (2, 2));
        // top-left of the crop is the original (2,2): R=2, G=2.
        assert_eq!(&r.rgba[0..4], &[2, 2, 0, 255]);
    }

    #[test]
    fn identity_crop_leaves_dimensions() {
        let r = geometry_apply(grid(4, 3), 4, 3, false, false, 0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0);
        assert_eq!((r.width, r.height), (4, 3));
    }
}
