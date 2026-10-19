//! Lens Blur API wrappers across flutter_rust_bridge.

use crate::blur::{self, BokehShape, LensBlurParams};

/// Lens Blur parameters across the FFI boundary.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ApiLensBlurParams {
    pub enabled: bool,
    pub amount: f32,
    pub focal_point: f32,
    pub focal_range: f32,
    pub bokeh_shape_index: u32,
    pub bokeh_boost: f32,
    pub background_blur: bool,
}

/// Applies depth-guided lens blur with synthetic bokeh.
pub fn blur_apply(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    params: ApiLensBlurParams,
    depth_map: Option<Vec<f32>>,
) -> Vec<u8> {
    let shape = match params.bokeh_shape_index {
        1 => BokehShape::Pentagon,
        2 => BokehShape::Hexagon,
        3 => BokehShape::Septagon,
        4 => BokehShape::Swirl,
        _ => BokehShape::Circle,
    };

    let p = LensBlurParams {
        enabled: params.enabled,
        amount: params.amount,
        focal_point: params.focal_point,
        focal_range: params.focal_range,
        bokeh_shape: shape,
        bokeh_boost: params.bokeh_boost,
        background_blur: params.background_blur,
    };

    blur::apply_lens_blur(
        &rgba,
        width as usize,
        height as usize,
        p,
        depth_map.as_deref(),
        36,
    )
}

/// Computes an on-device monocular depth map from RGBA pixels using saliency
/// and perspective priors. Returns a `width * height` plane of `f32` values
/// in `[0.0, 1.0]` where lower = closer (more in focus).
pub fn estimate_depth_map(rgba: Vec<u8>, width: u32, height: u32) -> Result<Vec<f32>, String> {
    let subject_mask = crate::ml::segment_subject_mask(
        &rgba,
        width as usize,
        height as usize,
        width as usize,
        height as usize,
    )
    .map_err(|e| format!("segmentation failed: {e}"))?;

    let mut depth = vec![0.0f32; (width * height) as usize];
    for y in 0..height as usize {
        let v = y as f32 / (height as f32 - 1.0).max(1.0);
        let perspective = 0.25 + 0.55 * v;
        let row_offset = y * width as usize;
        for x in 0..width as usize {
            let u = x as f32 / (width as f32 - 1.0).max(1.0);
            let du = u - 0.5;
            let dv = v - 0.5;
            let radial_dist = (du * du + dv * dv).sqrt();

            let subject_alpha = subject_mask[row_offset + x];
            let subject_depth = 0.35;
            let background_depth = (perspective + 0.35 * radial_dist).clamp(0.2, 1.0);

            let pixel_depth =
                subject_alpha * subject_depth + (1.0 - subject_alpha) * background_depth;
            depth[row_offset + x] = pixel_depth.clamp(0.0, 1.0);
        }
    }

    Ok(depth)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::blur::apply_lens_blur;

    #[test]
    fn depth_map_protects_subject_from_blur() {
        let (w, h) = (16, 16);
        let mut src = vec![0u8; w * h * 4];
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                let v = if (x + y) % 2 == 0 { 255 } else { 0 };
                src[idx] = v;
                src[idx + 1] = v;
                src[idx + 2] = v;
                src[idx + 3] = 255;
            }
        }

        // Subject in center (x: 6..10, y: 6..10) at depth 0.35, background at 1.0
        let mut depth_map = vec![1.0f32; w * h];
        for y in 6..10 {
            for x in 6..10 {
                depth_map[y * w + x] = 0.35;
            }
        }

        let params = LensBlurParams {
            enabled: true,
            amount: 0.8,
            focal_point: 0.35,
            focal_range: 0.1,
            bokeh_shape: BokehShape::Circle,
            bokeh_boost: 0.0,
            background_blur: false,
        };

        let out = apply_lens_blur(&src, w, h, params, Some(&depth_map), 36);

        // Subject center should stay sharp (unchanged)
        let subject_idx = (8 * w + 8) * 4;
        assert_eq!(
            out[subject_idx], src[subject_idx],
            "Subject must stay sharp"
        );

        // Background corner should be blurred
        let bg_idx = 0;
        assert!(
            out[bg_idx] != src[bg_idx],
            "Background should be blurred differently from original"
        );
    }
}
