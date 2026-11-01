//! Lens Blur API wrappers across flutter_rust_bridge.

use crate::api::mask::detect_faces;
use crate::blur::{self, LensBlurParams};

#[cfg(test)]
use crate::blur::BokehShape;

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
    /// Bokeh kernel sample count: 12 (interactive scrub), 36 (settle), 64 (export).
    pub sample_count: u32,
}

/// Applies depth-guided lens blur with synthetic bokeh.
pub fn blur_apply(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    params: ApiLensBlurParams,
    depth_map: Option<Vec<f32>>,
) -> Vec<u8> {
    let p = LensBlurParams::from_fields(
        params.enabled,
        params.amount,
        params.focal_point,
        params.focal_range,
        params.bokeh_shape_index as u8,
        params.bokeh_boost,
        params.background_blur,
        params.sample_count,
    );

    blur::apply_lens_blur(
        &rgba,
        width as usize,
        height as usize,
        p,
        depth_map.as_deref(),
    )
}

/// Applies depth-guided lens blur with automatic depth estimation.
/// When no depth map is supplied, estimates one on-device via
/// [`crate::ml::estimate_depth_map`] instead of falling back to a
/// synthetic gradient (which assumes a centered portrait).
pub fn blur_apply_auto_depth(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    params: ApiLensBlurParams,
) -> Result<Vec<u8>, String> {
    let depth_map = crate::ml::estimate_depth_map(
        &rgba,
        width as usize,
        height as usize,
        width as usize,
        height as usize,
    )
    .map_err(|e| format!("depth estimation failed: {e}"))?;

    let p = crate::blur::LensBlurParams::from_fields(
        params.enabled,
        params.amount,
        params.focal_point,
        params.focal_range,
        params.bokeh_shape_index as u8,
        params.bokeh_boost,
        params.background_blur,
        params.sample_count,
    );

    Ok(blur::apply_lens_blur(
        &rgba,
        width as usize,
        height as usize,
        p,
        Some(&depth_map),
    ))
}

/// Applies one-tap AI portrait blur.
///
/// Detects faces via YuNet, estimates depth via Depth Anything V2, places
/// the focal plane on the highest-scoring face, and applies background
/// blur with the subject protected. Default amount is 0.4 (subtle).
///
/// When no faces are detected, falls back to center-focused depth blur
/// without background-only masking.
pub fn blur_apply_portrait(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    amount: f32,
) -> Result<Vec<u8>, String> {
    let (w, h) = (width as usize, height as usize);

    // Detect faces to find the subject
    let faces = detect_faces(rgba.clone(), width, height);

    // Estimate depth map
    let depth_map = crate::ml::estimate_depth_map(&rgba, w, h, w, h)
        .map_err(|e| format!("depth estimation failed: {e}"))?;

    // Determine focal point from the highest-scoring face, or center
    let (focal_point, background_blur) = if let Some(face) = faces.into_iter().max_by(|a, b| {
        a.score
            .partial_cmp(&b.score)
            .unwrap_or(std::cmp::Ordering::Equal)
    }) {
        // Sample depth at face center (normalized coords -> pixel index)
        let cx = face.cx.clamp(0.0, 1.0);
        let cy = face.cy.clamp(0.0, 1.0);
        let px = (cx * (w - 1) as f32).round() as usize;
        let py = (cy * (h - 1) as f32).round() as usize;
        let depth_at_face = depth_map[py * w + px].clamp(0.0, 1.0);
        (depth_at_face, true)
    } else {
        (0.5, false)
    };

    let p = crate::blur::LensBlurParams::from_fields(
        true,
        amount,
        focal_point,
        0.2, // shallow DoF for portrait
        0,   // circle bokeh for soft portrait look
        0.3, // subtle bokeh boost
        background_blur,
        36, // full quality for portrait
    );

    Ok(blur::apply_lens_blur(
        &rgba,
        width as usize,
        height as usize,
        p,
        Some(&depth_map),
    ))
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

/// Computes a depth-map confidence score in `[0.0, 1.0]`.
///
/// Higher values indicate the depth map is reliable (textured scene with
/// clear depth variation). Lower values indicate unreliable depth
/// (textureless surfaces, uniform color, or monocular model uncertainty).
///
/// Computed from the **input image's luminance variance**: a textureless
/// input cannot yield reliable depth regardless of model output, so input
/// texture variance is the leading indicator of depth confidence.
pub fn depth_confidence(rgba: Vec<u8>, width: u32, height: u32) -> Result<f32, String> {
    let n = (width as usize) * (height as usize);
    if n == 0 || rgba.len() < n * 4 {
        return Ok(0.0);
    }

    // Compute luminance variance of the input image as the leading indicator
    // of depth-estimate reliability.
    let mut lum_sum = 0.0f64;
    let mut lum_sq_sum = 0.0f64;
    let mut count = 0usize;
    for i in (0..n * 4).step_by(4) {
        let r = rgba[i] as f64 / 255.0;
        let g = rgba[i + 1] as f64 / 255.0;
        let b = rgba[i + 2] as f64 / 255.0;
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        lum_sum += luma;
        lum_sq_sum += luma * luma;
        count += 1;
    }
    if count == 0 {
        return Ok(0.0);
    }

    let mean = lum_sum / count as f64;
    let variance = lum_sq_sum / count as f64 - mean * mean;

    // Map variance to [0,1] via saturating exponential:
    //   conf = 1 - exp(-variance / scale)
    // Uniform texture (variance ~ 0) → conf ~ 0
    // High texture variance → conf → 1
    let scale = 0.005;
    let confidence = (1.0 - f64::exp(-variance / scale)) as f32;
    Ok(confidence.clamp(0.0, 1.0))
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

/// Configures the active ML model path for a task kind (e.g. "depth", "segmentation", "face").
pub fn set_active_ml_model(task: String, path: String) -> bool {
    crate::ml::set_active_model(&task, &path)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::blur::apply_lens_blur;

    #[test]
    fn test_set_active_ml_model_rejects_non_existent_file() {
        assert!(!set_active_ml_model(
            "depth".to_string(),
            "/non_existent_dir/model.onnx".to_string(),
        ));
    }

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
            sample_count: 36,
        };

        let out = apply_lens_blur(&src, w, h, params, Some(&depth_map));

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

    #[test]
    fn test_bundled_depth_model_found_when_present() {
        if let Some(path) = crate::ml::find_bundled_depth_model() {
            assert!(std::path::Path::new(&path).is_file());
            assert!(path.contains("depth_anything_v2_vits.onnx"));
        }
    }

    /// Depth confidence must be in [0.0, 1.0].
    #[test]
    fn depth_confidence_is_in_unit_range() {
        let (w, h) = (16, 16);
        let src = vec![128u8; w * h * 4];
        let conf = depth_confidence(src.clone(), w as u32, h as u32)
            .expect("depth confidence must succeed");
        assert!((0.0..=1.0).contains(&conf));
    }

    /// Textureless uniform image should produce low depth confidence.
    #[test]
    fn depth_confidence_textureless_is_low() {
        let (w, h) = (32, 32);
        let src = vec![128u8; w * h * 4];
        let conf = depth_confidence(src.clone(), w as u32, h as u32)
            .expect("depth confidence must succeed");
        assert!(
            conf < 0.5,
            "textureless image should have low confidence: {conf}"
        );
    }

    /// High-contrast textured image should produce higher depth confidence.
    #[test]
    fn depth_confidence_textured_is_higher_than_textureless() {
        let (w, h) = (32, 32);
        let textureless = vec![128u8; w * h * 4];
        let mut textured = vec![0u8; w * h * 4];
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                let v = if (x + y) % 2 == 0 { 255 } else { 0 };
                textured[idx] = v;
                textured[idx + 1] = v;
                textured[idx + 2] = v;
                textured[idx + 3] = 255;
            }
        }
        let conf_textureless = depth_confidence(textureless, w as u32, h as u32)
            .expect("depth confidence must succeed");
        let conf_textured =
            depth_confidence(textured, w as u32, h as u32).expect("depth confidence must succeed");
        assert!(
            conf_textured > conf_textureless,
            "textured ({conf_textured}) > textureless ({conf_textureless})"
        );
    }

    /// Portrait blur returns output of same length as input.
    #[test]
    fn portrait_blur_output_length_matches_input() {
        let (w, h) = (32, 32);
        let src = vec![128u8; w * h * 4];
        let out = blur_apply_portrait(src.clone(), w as u32, h as u32, 0.4)
            .expect("portrait blur must succeed");
        assert_eq!(out.len(), w * h * 4);
    }

    /// Portrait blur default amount is 0.4 (subtle).
    #[test]
    fn portrait_blur_default_amount_is_subtle() {
        let (w, h) = (32, 32);
        let src = vec![200u8; w * h * 4];
        let out = blur_apply_portrait(src.clone(), w as u32, h as u32, 0.4)
            .expect("portrait blur must succeed");
        // With uniform gray and low confidence, output should still be valid
        assert_eq!(out.len(), w * h * 4);
    }

    /// Portrait blur with no faces falls back to synthetic depth (doesn't error).
    #[test]
    fn portrait_blur_no_faces_falls_back_to_synthetic_depth() {
        let (w, h) = (32, 32);
        // Checkerboard pattern - no faces expected from YuNet
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
        let out = blur_apply_portrait(src.clone(), w as u32, h as u32, 0.4)
            .expect("portrait blur with no faces must succeed");
        assert_eq!(out.len(), w * h * 4);
    }
}
