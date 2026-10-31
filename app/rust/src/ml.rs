//! Machine Learning (ML) inference and segmentation architecture (ADR 0010, #87).
//!
//! Provides the `Segmenter` trait and preprocessing/postprocessing pipelines
//! for on-device intelligent masking (Select Subject / Sky / Depth).
//!
//! Complies with F-Droid offline guidelines: zero runtime downloads, zero telemetry,
//! pure on-device execution.

/// Common trait for on-device segmentation backends (e.g. U²-NetP, MobileSAM,
/// Saliency, or ncnn/ORT engines).
pub trait Segmenter: Send + Sync {
    /// Segments salient subject from [rgba] buffer (`src_w * src_h * 4`).
    /// Returns 2D alpha plane [0.0, 1.0] of length (`target_w * target_h`).
    fn segment(
        &self,
        rgba: &[u8],
        src_w: usize,
        src_h: usize,
        target_w: usize,
        target_h: usize,
    ) -> Result<Vec<f32>, String>;
}

/// Segments the dominant subject, preferring the bundled U²-NetP model when
/// the optional `ai` feature is enabled and falling back to the deterministic
/// saliency segmenter if inference is unavailable.
pub fn segment_subject_mask(
    rgba: &[u8],
    src_w: usize,
    src_h: usize,
    target_w: usize,
    target_h: usize,
) -> Result<Vec<f32>, String> {
    #[cfg(feature = "ai")]
    {
        match crate::u2netp::U2NetpSegmenter.segment(rgba, src_w, src_h, target_w, target_h) {
            Ok(mask) => return Ok(mask),
            Err(err) => crate::api::logging::record_engine_error(
                "U²-NetP inference failed; using saliency",
                &err,
            ),
        }
    }
    SaliencySegmenter {}.segment(rgba, src_w, src_h, target_w, target_h)
}

/// Bilinearly samples RGBA pixel at continuous normalized coordinates `(u, v)`.
#[inline]
fn sample_bilinear_rgba(rgba: &[u8], w: usize, h: usize, u: f32, v: f32) -> [f32; 3] {
    let x = (u * (w as f32 - 1.0)).clamp(0.0, w as f32 - 1.0);
    let y = (v * (h as f32 - 1.0)).clamp(0.0, h as f32 - 1.0);

    let x0 = x.floor() as usize;
    let y0 = y.floor() as usize;
    let x1 = (x0 + 1).min(w - 1);
    let y1 = (y0 + 1).min(h - 1);

    let fx = x - x0 as f32;
    let fy = y - y0 as f32;

    let p00 = (y0 * w + x0) * 4;
    let p10 = (y0 * w + x1) * 4;
    let p01 = (y1 * w + x0) * 4;
    let p11 = (y1 * w + x1) * 4;

    let mut out = [0.0f32; 3];
    for c in 0..3 {
        let c00 = rgba[p00 + c] as f32 / 255.0;
        let c10 = rgba[p10 + c] as f32 / 255.0;
        let c01 = rgba[p01 + c] as f32 / 255.0;
        let c11 = rgba[p11 + c] as f32 / 255.0;

        let top = c00 + fx * (c10 - c00);
        let bot = c01 + fx * (c11 - c01);
        out[c] = top + fy * (bot - top);
    }
    out
}

/// Preprocesses proxy RGBA image into a normalized planar CHW tensor (e.g. 3 x 320 x 320).
///
/// Steps:
/// 1. Bilinear resize from `(src_w, src_h)` to `(target_w, target_h)`.
/// 2. Normalization: `(channel_value - mean) / std`.
/// 3. Planar output layout: `[Channel 0 (R), Channel 1 (G), Channel 2 (B)]`.
pub fn preprocess_image_chw(
    rgba: &[u8],
    src_w: usize,
    src_h: usize,
    target_w: usize,
    target_h: usize,
    mean: &[f32; 3],
    std: &[f32; 3],
) -> Vec<f32> {
    if src_w == 0
        || src_h == 0
        || target_w == 0
        || target_h == 0
        || target_w > 2048
        || target_h > 2048
    {
        return Vec::new();
    }
    if crate::validate::validate_rgba(rgba, src_w as u32, src_h as u32).is_err() {
        return Vec::new();
    }

    let plane_size = match target_w.checked_mul(target_h) {
        Some(s) => s,
        None => return Vec::new(),
    };
    let tensor_size = match plane_size.checked_mul(3) {
        Some(s) => s,
        None => return Vec::new(),
    };
    let mut tensor = vec![0.0f32; tensor_size];

    let inv_w = if target_w > 1 {
        1.0 / (target_w - 1) as f32
    } else {
        0.0
    };
    let inv_h = if target_h > 1 {
        1.0 / (target_h - 1) as f32
    } else {
        0.0
    };

    for y in 0..target_h {
        let v = y as f32 * inv_h;
        let row_offset = y * target_w;
        for x in 0..target_w {
            let u = x as f32 * inv_w;
            let rgb = sample_bilinear_rgba(rgba, src_w, src_h, u, v);
            let idx = row_offset + x;

            tensor[idx] = (rgb[0] - mean[0]) / std[0];
            tensor[plane_size + idx] = (rgb[1] - mean[1]) / std[1];
            tensor[2 * plane_size + idx] = (rgb[2] - mean[2]) / std[2];
        }
    }

    tensor
}

/// Resizes a single-channel 2D float mask `[0.0, 1.0]` using bilinear interpolation.
pub fn resize_mask(
    mask: &[f32],
    src_w: usize,
    src_h: usize,
    target_w: usize,
    target_h: usize,
) -> Vec<f32> {
    if src_w == 0 || src_h == 0 || target_w == 0 || target_h == 0 || mask.len() < src_w * src_h {
        return Vec::new();
    }
    if src_w == target_w && src_h == target_h {
        return mask[..src_w * src_h].to_vec();
    }

    let mut out = vec![0.0f32; target_w * target_h];
    let inv_w = if target_w > 1 {
        1.0 / (target_w - 1) as f32
    } else {
        0.0
    };
    let inv_h = if target_h > 1 {
        1.0 / (target_h - 1) as f32
    } else {
        0.0
    };

    for y in 0..target_h {
        let v = (y as f32 * inv_h) * (src_h as f32 - 1.0);
        let y0 = (v.floor() as usize).min(src_h - 1);
        let y1 = (y0 + 1).min(src_h - 1);
        let fy = v - y0 as f32;

        let row_idx = y * target_w;
        for x in 0..target_w {
            let u = (x as f32 * inv_w) * (src_w as f32 - 1.0);
            let x0 = (u.floor() as usize).min(src_w - 1);
            let x1 = (x0 + 1).min(src_w - 1);
            let fx = u - x0 as f32;

            let c00 = mask[y0 * src_w + x0];
            let c10 = mask[y0 * src_w + x1];
            let c01 = mask[y1 * src_w + x0];
            let c11 = mask[y1 * src_w + x1];

            let top = c00 + fx * (c10 - c00);
            let bot = c01 + fx * (c11 - c01);
            out[row_idx + x] = (top + fy * (bot - top)).clamp(0.0, 1.0);
        }
    }

    out
}

/// Saliency-based subject segmenter.
///
/// An in-tree, 100% offline-clean, deterministic salient object segmenter.
/// Uses boundary background color estimation, color contrast, and center-weighted priors
/// to produce high-quality subject alpha masks.
#[derive(Debug, Clone, Copy, Default)]
pub struct SaliencySegmenter {}

impl Segmenter for SaliencySegmenter {
    fn segment(
        &self,
        rgba: &[u8],
        src_w: usize,
        src_h: usize,
        target_w: usize,
        target_h: usize,
    ) -> Result<Vec<f32>, String> {
        if src_w < 4
            || src_h < 4
            || target_w == 0
            || target_h == 0
            || target_w > 2048
            || target_h > 2048
        {
            return Err(
                "Invalid segmentation dimensions (min src 4x4, max target 2048x2048)".into(),
            );
        }
        crate::validate::validate_rgba(rgba, src_w as u32, src_h as u32)?;

        // 1. Compute background prior from frame boundaries
        let mut bg_r = 0.0f32;
        let mut bg_g = 0.0f32;
        let mut bg_b = 0.0f32;
        let mut border_count = 0usize;

        for x in 0..src_w {
            let top_idx = x * 4;
            bg_r += rgba[top_idx] as f32 / 255.0;
            bg_g += rgba[top_idx + 1] as f32 / 255.0;
            bg_b += rgba[top_idx + 2] as f32 / 255.0;

            let bot_idx = ((src_h - 1) * src_w + x) * 4;
            bg_r += rgba[bot_idx] as f32 / 255.0;
            bg_g += rgba[bot_idx + 1] as f32 / 255.0;
            bg_b += rgba[bot_idx + 2] as f32 / 255.0;
            border_count += 2;
        }

        for y in 1..src_h - 1 {
            let left_idx = y * src_w * 4;
            bg_r += rgba[left_idx] as f32 / 255.0;
            bg_g += rgba[left_idx + 1] as f32 / 255.0;
            bg_b += rgba[left_idx + 2] as f32 / 255.0;

            let right_idx = (y * src_w + (src_w - 1)) * 4;
            bg_r += rgba[right_idx] as f32 / 255.0;
            bg_g += rgba[right_idx + 1] as f32 / 255.0;
            bg_b += rgba[right_idx + 2] as f32 / 255.0;
            border_count += 2;
        }

        if border_count > 0 {
            bg_r /= border_count as f32;
            bg_g /= border_count as f32;
            bg_b /= border_count as f32;
        }

        // 2. Generate target_w x target_h saliency mask
        let mut mask = vec![0.0f32; target_w * target_h];
        let inv_w = if target_w > 1 {
            1.0 / (target_w - 1) as f32
        } else {
            0.5
        };
        let inv_h = if target_h > 1 {
            1.0 / (target_h - 1) as f32
        } else {
            0.5
        };

        for y in 0..target_h {
            let v = y as f32 * inv_h;
            let dv = v - 0.5;
            let row_offset = y * target_w;
            for x in 0..target_w {
                let u = x as f32 * inv_w;
                let du = u - 0.5;

                let rgb = sample_bilinear_rgba(rgba, src_w, src_h, u, v);
                let dr = rgb[0] - bg_r;
                let dg = rgb[1] - bg_g;
                let db = rgb[2] - bg_b;
                let color_diff = (dr * dr + dg * dg + db * db).sqrt();

                // Center prior
                let center_falloff = (-2.5 * (du * du + dv * dv)).exp();

                // Saliency score mapped via sigmoid-like soft threshold
                let score = color_diff * center_falloff;
                let alpha = (1.0 / (1.0 + (-12.0 * (score - 0.25)).exp())).clamp(0.0, 1.0);
                mask[row_offset + x] = alpha;
            }
        }

        Ok(mask)
    }
}

/// Computes Intersection-over-Union (IoU) between two masks thresholded at `threshold`.
pub fn compute_iou(mask_a: &[f32], mask_b: &[f32], threshold: f32) -> f32 {
    if mask_a.is_empty() || mask_a.len() != mask_b.len() {
        return 0.0;
    }

    let mut intersection = 0usize;
    let mut union = 0usize;

    for i in 0..mask_a.len() {
        let a = mask_a[i] >= threshold;
        let b = mask_b[i] >= threshold;
        if a && b {
            intersection += 1;
        }
        if a || b {
            union += 1;
        }
    }

    if union == 0 {
        1.0
    } else {
        intersection as f32 / union as f32
    }
}

use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

static ACTIVE_MODELS: LazyLock<Mutex<HashMap<String, String>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

/// Sets the active model path for a task kind (e.g. "depth", "segmentation", "face").
pub fn set_active_model(task: &str, path: &str) -> bool {
    let p = std::path::Path::new(path);
    if !p.is_file() {
        return false;
    }
    if let Ok(mut map) = ACTIVE_MODELS.lock() {
        map.insert(task.to_lowercase(), path.to_string());
        true
    } else {
        false
    }
}

/// Retrieves the active model path for a task kind if configured.
pub fn get_active_model(task: &str) -> Option<String> {
    if let Ok(map) = ACTIVE_MODELS.lock() {
        map.get(&task.to_lowercase()).cloned()
    } else {
        None
    }
}

/// Searches standard paths for a bundled monocular depth model.
pub fn find_bundled_depth_model() -> Option<String> {
    if let Ok(env_path) = std::env::var("APERTUREX_DEPTH_MODEL") {
        if std::path::Path::new(&env_path).is_file() {
            return Some(env_path);
        }
    }
    let candidates = [
        "assets/models/depth_anything_v2_vits.onnx",
        "../assets/models/depth_anything_v2_vits.onnx",
        "app/rust/assets/models/depth_anything_v2_vits.onnx",
        "assets/models/depth_model.onnx",
    ];
    for candidate in &candidates {
        if std::path::Path::new(candidate).is_file() {
            return Some((*candidate).to_string());
        }
    }
    None
}

#[cfg(feature = "ai")]
fn try_neural_depth_inference(
    rgba: &[u8],
    src_w: usize,
    src_h: usize,
    target_w: usize,
    target_h: usize,
    plugin_model_path: Option<&str>,
) -> Result<Vec<f32>, String> {
    let model_path = if let Some(p) = plugin_model_path {
        if std::path::Path::new(p).is_file() {
            Some(p.to_string())
        } else {
            return Err(format!("Plugin depth model file not found at '{p}'"));
        }
    } else if let Some(active) = get_active_model("depth") {
        Some(active)
    } else {
        find_bundled_depth_model()
    };

    let path =
        model_path.ok_or_else(|| "No bundled or plugin depth model available".to_string())?;
    let model_bytes =
        std::fs::read(&path).map_err(|e| format!("Failed to read depth model '{path}': {e}"))?;

    const DEPTH_IN_W: usize = 518;
    const DEPTH_IN_H: usize = 518;
    const MEAN: [f32; 3] = [0.485, 0.456, 0.406];
    const STD: [f32; 3] = [0.229, 0.224, 0.225];

    let input_tensor =
        preprocess_image_chw(rgba, src_w, src_h, DEPTH_IN_W, DEPTH_IN_H, &MEAN, &STD);
    if input_tensor.len() != 3 * DEPTH_IN_W * DEPTH_IN_H {
        return Err("Depth model tensor preprocessing failed".into());
    }

    let mut session = crate::ort_runtime::create_session(&model_bytes)?;
    let raw_output = crate::ort_runtime::run_session(
        &mut session,
        &input_tensor,
        &[1, 3, DEPTH_IN_W, DEPTH_IN_H],
    )?;

    if raw_output.len() != DEPTH_IN_W * DEPTH_IN_H {
        return Err(format!(
            "Depth model output shape mismatch: got {} values, expected {}",
            raw_output.len(),
            DEPTH_IN_W * DEPTH_IN_H
        ));
    }

    // Normalize raw depth / disparity to [0.0, 1.0] (lower = closer)
    let mut min_val = f32::INFINITY;
    let mut max_val = f32::NEG_INFINITY;
    for &v in &raw_output {
        if v.is_finite() {
            if v < min_val {
                min_val = v;
            }
            if v > max_val {
                max_val = v;
            }
        }
    }

    let span = (max_val - min_val).max(1e-5);
    // Depth Anything V2 outputs inverse relative depth / disparity (higher = closer).
    // ApertureX depth convention: lower = closer (0.0 near, 1.0 far).
    let normalized_depth: Vec<f32> = raw_output
        .iter()
        .map(|&d| (1.0 - (d - min_val) / span).clamp(0.0, 1.0))
        .collect();

    let resized = resize_mask(
        &normalized_depth,
        DEPTH_IN_W,
        DEPTH_IN_H,
        target_w,
        target_h,
    );
    Ok(resized)
}

/// Computes a high-order continuous optical depth gradient with C2 smoothness,
/// subject focal plane estimation, and radial lens curvature.
fn estimate_high_order_depth_gradient(
    rgba: &[u8],
    src_w: usize,
    src_h: usize,
    target_w: usize,
    target_h: usize,
) -> Result<Vec<f32>, String> {
    let subject_mask = segment_subject_mask(rgba, src_w, src_h, target_w, target_h)?;

    // Compute subject centroid to identify subject's focal depth
    let mut sum_v = 0.0f32;
    let mut sum_alpha = 0.0f32;
    let inv_w = if target_w > 1 {
        1.0 / (target_w - 1) as f32
    } else {
        0.5
    };
    let inv_h = if target_h > 1 {
        1.0 / (target_h - 1) as f32
    } else {
        0.5
    };

    for y in 0..target_h {
        let v = y as f32 * inv_h;
        let row_offset = y * target_w;
        for x in 0..target_w {
            let alpha = subject_mask[row_offset + x];
            if alpha > 0.1 {
                sum_v += v * alpha;
                sum_alpha += alpha;
            }
        }
    }

    let centroid_v = if sum_alpha > 1e-3 {
        (sum_v / sum_alpha).clamp(0.0, 1.0)
    } else {
        0.5
    };

    // Cubic smoothstep optical perspective curve P(v):
    // Distant background / horizon near top (0.85), closer foreground near bottom (0.20)
    let p_curve = |v: f32| -> f32 {
        let t = 1.0 - v.clamp(0.0, 1.0);
        let s = t * t * (3.0 - 2.0 * t);
        0.20 + 0.65 * s
    };

    let subject_depth = (p_curve(centroid_v) * 0.70).clamp(0.20, 0.45);

    let mut depth = vec![0.0f32; target_w * target_h];

    for y in 0..target_h {
        let v = y as f32 * inv_h;
        let pv = p_curve(v);
        let dv = v - 0.5;
        let row_offset = y * target_w;
        for x in 0..target_w {
            let u = x as f32 * inv_w;
            let du = u - 0.5;

            // Optical radial field curvature
            let radial_curvature = 0.25 * (du * du + dv * dv);
            let background_depth = (pv + radial_curvature).clamp(0.20, 1.0);

            let subject_alpha = subject_mask[row_offset + x];
            let pixel_depth =
                subject_alpha * subject_depth + (1.0 - subject_alpha) * background_depth;
            depth[row_offset + x] = pixel_depth.clamp(0.0, 1.0);
        }
    }

    Ok(depth)
}

/// Estimates an on-device monocular depth map from RGBA pixels.
///
/// Uses the active monocular neural depth model (e.g. Depth Anything V2) via ONNX Runtime
/// if available, or seamlessly falls back to the high-order optical depth gradient.
pub fn estimate_depth_map(
    rgba: &[u8],
    src_w: usize,
    src_h: usize,
    target_w: usize,
    target_h: usize,
) -> Result<Vec<f32>, String> {
    estimate_depth_map_with_plugin(rgba, src_w, src_h, target_w, target_h, None)
}

/// Estimates depth map with optional external plugin model path.
pub fn estimate_depth_map_with_plugin(
    rgba: &[u8],
    src_w: usize,
    src_h: usize,
    target_w: usize,
    target_h: usize,
    plugin_model_path: Option<&str>,
) -> Result<Vec<f32>, String> {
    if src_w < 4
        || src_h < 4
        || target_w == 0
        || target_h == 0
        || target_w > 2048
        || target_h > 2048
    {
        return Err(
            "Invalid depth estimation dimensions (min src 4x4, max target 2048x2048)".into(),
        );
    }
    crate::validate::validate_rgba(rgba, src_w as u32, src_h as u32)?;

    #[cfg(feature = "ai")]
    {
        match try_neural_depth_inference(rgba, src_w, src_h, target_w, target_h, plugin_model_path)
        {
            Ok(depth) => return Ok(depth),
            Err(err) => {
                crate::api::logging::record_engine_error(
                    "Neural depth inference unavailable; falling back to optical depth gradient",
                    &err,
                );
            }
        }
    }

    #[cfg(not(feature = "ai"))]
    let _ = plugin_model_path;

    estimate_high_order_depth_gradient(rgba, src_w, src_h, target_w, target_h)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_preprocess_image_tiny_tensor() {
        // 2x2 image:
        // (0,0): red (255, 0, 0)
        // (1,0): green (0, 255, 0)
        // (0,1): blue (0, 0, 255)
        // (1,1): white (255, 255, 255)
        let rgba = vec![
            255, 0, 0, 255, // (0,0)
            0, 255, 0, 255, // (1,0)
            0, 0, 255, 255, // (0,1)
            255, 255, 255, 255, // (1,1)
        ];

        let mean = [0.0, 0.0, 0.0];
        let std = [1.0, 1.0, 1.0];

        let tensor = preprocess_image_chw(&rgba, 2, 2, 2, 2, &mean, &std);
        assert_eq!(tensor.len(), 3 * 4);

        // Plane 0 (Red channel):
        // (0,0)=1.0, (1,0)=0.0, (0,1)=0.0, (1,1)=1.0
        assert!((tensor[0] - 1.0).abs() < 1e-4);
        assert!(tensor[1].abs() < 1e-4);
        assert!(tensor[2].abs() < 1e-4);
        assert!((tensor[3] - 1.0).abs() < 1e-4);

        // Plane 1 (Green channel):
        // (0,0)=0.0, (1,0)=1.0, (0,1)=0.0, (1,1)=1.0
        assert!(tensor[4].abs() < 1e-4);
        assert!((tensor[5] - 1.0).abs() < 1e-4);
        assert!(tensor[6].abs() < 1e-4);
        assert!((tensor[7] - 1.0).abs() < 1e-4);

        // Plane 2 (Blue channel):
        // (0,0)=0.0, (1,0)=0.0, (0,1)=1.0, (1,1)=1.0
        assert!(tensor[8].abs() < 1e-4);
        assert!(tensor[9].abs() < 1e-4);
        assert!((tensor[10] - 1.0).abs() < 1e-4);
        assert!((tensor[11] - 1.0).abs() < 1e-4);
    }

    #[test]
    fn test_resize_mask_bilinear() {
        let mask = vec![0.0, 1.0, 0.0, 1.0]; // 2x2
        let resized = resize_mask(&mask, 2, 2, 3, 3);
        assert_eq!(resized.len(), 9);

        // (0,0) is 0.0, (2,0) is 1.0, middle (1,0) should be 0.5
        assert!((resized[0] - 0.0).abs() < 1e-4);
        assert!((resized[1] - 0.5).abs() < 1e-4);
        assert!((resized[2] - 1.0).abs() < 1e-4);
    }

    #[test]
    fn test_saliency_segmenter_iou_golden() {
        let w = 40;
        let h = 40;
        let mut rgba = vec![30u8; w * h * 4]; // Dark background (30)

        // Draw bright salient subject in center (x: 12..28, y: 12..28)
        let mut ground_truth = vec![0.0f32; 32 * 32];
        for y in 0..h {
            for x in 0..w {
                if (12..28).contains(&x) && (12..28).contains(&y) {
                    let idx = (y * w + x) * 4;
                    rgba[idx] = 230;
                    rgba[idx + 1] = 220;
                    rgba[idx + 2] = 210;
                    rgba[idx + 3] = 255;
                }
            }
        }

        for y in 0..32 {
            let vy = (y as f32 + 0.5) / 32.0;
            for x in 0..32 {
                let ux = (x as f32 + 0.5) / 32.0;
                if (0.3..=0.7).contains(&ux) && (0.3..=0.7).contains(&vy) {
                    ground_truth[y * 32 + x] = 1.0;
                }
            }
        }

        let segmenter = SaliencySegmenter {};
        let mask = segmenter
            .segment(&rgba, w, h, 32, 32)
            .expect("segmentation succeeded");
        assert_eq!(mask.len(), 32 * 32);

        let iou = compute_iou(&mask, &ground_truth, 0.5);
        assert!(
            iou >= 0.70,
            "Golden IoU must exceed 0.70 threshold, got: {iou}"
        );
    }

    #[test]
    fn test_saliency_segmenter_background_inverted_iou_golden() {
        let w = 40;
        let h = 40;
        let mut rgba = vec![30u8; w * h * 4];

        for y in 12..28 {
            for x in 12..28 {
                let idx = (y * w + x) * 4;
                rgba[idx] = 230;
                rgba[idx + 1] = 220;
                rgba[idx + 2] = 210;
                rgba[idx + 3] = 255;
            }
        }

        let mut bg_ground_truth = vec![1.0f32; 32 * 32];
        for y in 0..32 {
            let vy = (y as f32 + 0.5) / 32.0;
            for x in 0..32 {
                let ux = (x as f32 + 0.5) / 32.0;
                if (0.3..=0.7).contains(&ux) && (0.3..=0.7).contains(&vy) {
                    bg_ground_truth[y * 32 + x] = 0.0;
                }
            }
        }

        let segmenter = SaliencySegmenter {};
        let mask = segmenter
            .segment(&rgba, w, h, 32, 32)
            .expect("segmentation succeeded");

        let inverted_mask: Vec<f32> = mask.iter().map(|&a| 1.0 - a).collect();
        let bg_iou = compute_iou(&inverted_mask, &bg_ground_truth, 0.5);
        assert!(
            bg_iou >= 0.70,
            "Background inverted IoU must exceed 0.70 threshold, got: {bg_iou}"
        );
    }

    #[test]
    fn test_segmenter_trait_object_dispatch() {
        let segmenter: Box<dyn Segmenter> = Box::new(SaliencySegmenter {});
        let rgba = vec![50u8; 16 * 16 * 4];
        let res = segmenter.segment(&rgba, 16, 16, 8, 8);
        assert!(res.is_ok());
        assert_eq!(res.unwrap().len(), 64);
    }

    #[test]
    fn test_estimate_depth_map_produces_calibrated_plane() {
        let w = 32;
        let h = 32;
        let mut rgba = vec![20u8; w * h * 4];

        // Central bright subject
        for y in 10..22 {
            for x in 10..22 {
                let idx = (y * w + x) * 4;
                rgba[idx] = 220;
                rgba[idx + 1] = 200;
                rgba[idx + 2] = 190;
                rgba[idx + 3] = 255;
            }
        }

        let depth = estimate_depth_map(&rgba, w, h, 16, 16).expect("depth estimation succeeded");
        assert_eq!(depth.len(), 16 * 16);

        // All depths in [0.0, 1.0]
        for &d in &depth {
            assert!((0.0..=1.0).contains(&d));
        }

        // Center subject depth should be closer (lower depth) than corner background
        let center_depth = depth[8 * 16 + 8];
        let corner_depth = depth[0];
        assert!(
            center_depth < corner_depth,
            "Center subject ({center_depth}) should be closer than distant corner ({corner_depth})"
        );
    }
}
