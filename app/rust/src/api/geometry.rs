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
    if crate::validate::validate_rgba(&rgba, width, height).is_err() {
        return GeometryResult {
            width: 0,
            height: 0,
            rgba: Vec::new(),
        };
    }
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
    if crate::validate::validate_rgba(&rgba, width, height).is_err() {
        return GeometryResult {
            width: 0,
            height: 0,
            rgba: Vec::new(),
        };
    }
    let (out, w, h) = geometry::rotate_quarter(&rgba, width as usize, height as usize, turns);
    GeometryResult {
        width: w as u32,
        height: h as u32,
        rgba: out,
    }
}

/// Crops to `(x, y, cw, ch)`. Returns clamped output and true post-clamp dimensions.
pub fn geometry_crop(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    x: u32,
    y: u32,
    cw: u32,
    ch: u32,
) -> GeometryResult {
    if crate::validate::validate_rgba(&rgba, width, height).is_err() || width == 0 || height == 0 {
        return GeometryResult {
            width: 0,
            height: 0,
            rgba: Vec::new(),
        };
    }
    let (w, h) = (width as usize, height as usize);
    let clamped_x = (x as usize).min(w.saturating_sub(1));
    let clamped_y = (y as usize).min(h.saturating_sub(1));
    let clamped_cw = (cw as usize).min(w.saturating_sub(clamped_x));
    let clamped_ch = (ch as usize).min(h.saturating_sub(clamped_y));
    let out = geometry::crop(&rgba, w, h, clamped_x, clamped_y, clamped_cw, clamped_ch);
    GeometryResult {
        width: clamped_cw as u32,
        height: clamped_ch as u32,
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
    if crate::validate::validate_rgba(&rgba, width, height).is_err() {
        return GeometryResult {
            width: 0,
            height: 0,
            rgba: Vec::new(),
        };
    }
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
    if crate::validate::validate_rgba(&rgba, width, height).is_err() {
        return GeometryResult {
            width: 0,
            height: 0,
            rgba: Vec::new(),
        };
    }
    let spec = geometry::GeometrySpec {
        flip_h,
        flip_v,
        turns,
        angle,
        crop_l,
        crop_t,
        crop_r,
        crop_b,
        perspective_x,
        perspective_y,
        skew_x,
        skew_y,
    };
    let (buf, w, h) = geometry::apply_spec(&rgba, width as usize, height as usize, &spec);
    GeometryResult {
        width: w as u32,
        height: h as u32,
        rgba: buf,
    }
}

/// Bilinear downscale so the longest side is at most `max_dim`.
pub fn geometry_downscale(rgba: Vec<u8>, width: u32, height: u32, max_dim: u32) -> GeometryResult {
    if crate::validate::validate_rgba(&rgba, width, height).is_err() {
        return GeometryResult {
            width: 0,
            height: 0,
            rgba: Vec::new(),
        };
    }
    let (out, w, h) = geometry::downscale(&rgba, width as usize, height as usize, max_dim as usize);
    GeometryResult {
        width: w as u32,
        height: h as u32,
        rgba: out,
    }
}

/// Applies trapezoidal perspective + skew. Same output dimensions as input.
pub fn geometry_perspective_rgba(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    perspective_x: f32,
    perspective_y: f32,
    skew_x: f32,
    skew_y: f32,
) -> GeometryResult {
    if crate::validate::validate_rgba(&rgba, width, height).is_err() {
        return GeometryResult {
            width: 0,
            height: 0,
            rgba: Vec::new(),
        };
    }
    let (w, h) = (width as usize, height as usize);
    let out = crate::geometry::perspective_warp(
        &rgba,
        w,
        h,
        perspective_x,
        perspective_y,
        skew_x,
        skew_y,
    );
    GeometryResult {
        width,
        height,
        rgba: out,
    }
}

/// Detects horizon tilt and returns corrective straighten angle in degrees.
pub fn geometry_detect_straighten_angle(rgba: Vec<u8>, width: u32, height: u32) -> f32 {
    if crate::validate::validate_rgba(&rgba, width, height).is_err() {
        return 0.0;
    }
    crate::geometry::detect_straighten_angle(&rgba, width as usize, height as usize)
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
        let r = geometry_apply(
            src, 4, 4, false, false, 0, 0.0, 0.5, 0.5, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0,
        );
        assert_eq!((r.width, r.height), (2, 2));
        // top-left of the crop is the original (2,2): R=2, G=2.
        assert_eq!(&r.rgba[0..4], &[2, 2, 0, 255]);
    }

    #[test]
    fn identity_crop_leaves_dimensions() {
        let r = geometry_apply(
            grid(4, 3),
            4,
            3,
            false,
            false,
            0,
            0.0,
            0.0,
            0.0,
            1.0,
            1.0,
            0.0,
            0.0,
            0.0,
            0.0,
        );
        assert_eq!((r.width, r.height), (4, 3));
    }
}
