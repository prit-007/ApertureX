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

/// Applies the whole geometry chain: flip → rotate (90° × turns) → straighten.
pub fn geometry_apply(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    flip_h: bool,
    flip_v: bool,
    turns: u32,
    angle: f32,
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
    if turns % 4 != 0 {
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

    GeometryResult {
        width: w as u32,
        height: h as u32,
        rgba: buf,
    }
}
