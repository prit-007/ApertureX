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
        4 => BokehShape::CatsEye,
        5 => BokehShape::SoapBubble,
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

/// Computes an on-device monocular depth map from RGBA pixels.
/// Returns a `width * height` plane of `f32` values in `[0.0, 1.0]`
/// where lower = closer (more in focus).
pub fn estimate_depth_map(rgba: Vec<u8>, width: u32, height: u32) -> Result<Vec<f32>, String> {
    crate::ml::estimate_depth_map(
        &rgba,
        width as usize,
        height as usize,
        width as usize,
        height as usize,
    )
}

/// Computes an on-device monocular depth map, optionally using an external plugin ONNX model path.
pub fn estimate_depth_map_with_model(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    model_path: Option<String>,
) -> Result<Vec<f32>, String> {
    crate::ml::estimate_depth_map_with_plugin(
        &rgba,
        width as usize,
        height as usize,
        width as usize,
        height as usize,
        model_path.as_deref(),
    )
}

/// Generates a false-color RGBA heatmap visualizing a relative depth map:
/// - Warm Amber (RGB 255, 179, 0) for near foreground
/// - Neutral Gray (RGB 180, 180, 180) for in-focus focal plane
/// - Cool Teal (RGB 0, 180, 200) for far background
pub fn generate_depth_visualizer_rgba(
    depth: Vec<f32>,
    width: u32,
    height: u32,
    focal_point: f32,
    focal_range: f32,
) -> Vec<u8> {
    blur::generate_depth_visualizer_rgba(
        &depth,
        width as usize,
        height as usize,
        focal_point,
        focal_range,
    )
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

    #[test]
    fn api_estimate_depth_map_produces_valid_depth_plane() {
        let (w, h) = (16, 16);
        let src = vec![128u8; w * h * 4];
        let depth = estimate_depth_map(src.clone(), w as u32, h as u32)
            .expect("depth estimation must succeed");
        assert_eq!(depth.len(), w * h);
        for &d in &depth {
            assert!((0.0..=1.0).contains(&d));
        }

        let depth_with_model =
            estimate_depth_map_with_model(src, w as u32, h as u32, Some("nonexistent.onnx".into()))
                .expect("depth estimation fallback must succeed");
        assert_eq!(depth_with_model.len(), w * h);
    }

    #[test]
    fn api_generate_depth_visualizer_heatmap() {
        let depth = vec![0.0, 0.5, 1.0];
        let heatmap = generate_depth_visualizer_rgba(depth, 3, 1, 0.5, 0.1);
        assert_eq!(heatmap.len(), 12);
        // Near (Warm Amber: 255, 179, 0)
        assert_eq!(heatmap[0], 255);
        assert_eq!(heatmap[1], 179);
        assert_eq!(heatmap[2], 0);
        // Focus (Neutral: 180, 180, 180)
        assert_eq!(heatmap[4], 180);
        assert_eq!(heatmap[5], 180);
        assert_eq!(heatmap[6], 180);
        // Far (Cool Teal: 0, 180, 200)
        assert_eq!(heatmap[8], 0);
        assert_eq!(heatmap[9], 180);
        assert_eq!(heatmap[10], 200);
    }
}
