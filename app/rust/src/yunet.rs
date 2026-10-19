//! YuNet face detection (ADR 0010, #87).
//!
//! The MIT-licensed 2023mar YuNet ONNX model is bundled into the optional
//! `ai` build. It runs through the shared ONNX Runtime backend and is used to
//! place the subject ellipse on portraits before falling back to saliency.

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use ort::session::Session;

use crate::ml::preprocess_image_chw;
use crate::ort_runtime::{create_session, run_session_all};

const INPUT_SIZE: usize = 640;
const SCORE_THRESHOLD: f32 = 0.6;
const NMS_THRESHOLD: f32 = 0.3;
const TOP_K: usize = 5000;
const STRIDES: [usize; 3] = [8, 16, 32];

const YUNET_MODEL: &[u8] = include_bytes!("../assets/models/face_detection_yunet_2023mar.onnx");

static SESSION: OnceLock<Result<Mutex<Session>, String>> = OnceLock::new();

fn session() -> Result<&'static Mutex<Session>, String> {
    SESSION
        .get_or_init(|| create_session(YUNET_MODEL).map(Mutex::new))
        .as_ref()
        .map_err(Clone::clone)
}

/// One face detection in source-image pixel coordinates.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct FaceDetection {
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
    pub score: f32,
    /// Right eye, left eye, nose tip, right mouth corner, left mouth corner.
    pub landmarks: [[f32; 2]; 5],
}

/// Detects all faces at or above the default confidence threshold.
pub fn detect(rgba: &[u8], src_w: usize, src_h: usize) -> Result<Vec<FaceDetection>, String> {
    if src_w < 8 || src_h < 8 {
        return Err("Invalid face-detection dimensions (min 8x8)".into());
    }
    crate::validate::validate_rgba(rgba, src_w as u32, src_h as u32)?;

    let input = preprocess_yunet(rgba, src_w, src_h);
    if input.len() != 3 * INPUT_SIZE * INPUT_SIZE {
        return Err("YuNet preprocessing produced an invalid tensor".into());
    }

    let mut session = session()?
        .lock()
        .map_err(|_| "YuNet session lock poisoned".to_string())?;
    let raw_outputs = run_session_all(&mut session, &input, &[1, 3, INPUT_SIZE, INPUT_SIZE])?;
    let outputs: HashMap<String, Vec<f32>> = raw_outputs.into_iter().collect();

    let mut faces = decode(
        &outputs,
        INPUT_SIZE,
        INPUT_SIZE,
        SCORE_THRESHOLD,
        NMS_THRESHOLD,
    )?;

    let scale_x = src_w as f32 / INPUT_SIZE as f32;
    let scale_y = src_h as f32 / INPUT_SIZE as f32;
    for face in &mut faces {
        face.x *= scale_x;
        face.y *= scale_y;
        face.w *= scale_x;
        face.h *= scale_y;
        for landmark in &mut face.landmarks {
            landmark[0] *= scale_x;
            landmark[1] *= scale_y;
        }
    }
    Ok(faces)
}

/// Returns the largest detected face, if any. Used by auto-subject placement.
pub fn detect_largest_face(
    rgba: &[u8],
    src_w: usize,
    src_h: usize,
) -> Result<Option<FaceDetection>, String> {
    let faces = detect(rgba, src_w, src_h)?;
    Ok(faces.into_iter().max_by(|a, b| {
        let area_a = a.w * a.h;
        let area_b = b.w * b.h;
        area_a
            .partial_cmp(&area_b)
            .unwrap_or(std::cmp::Ordering::Equal)
    }))
}

fn preprocess_yunet(rgba: &[u8], src_w: usize, src_h: usize) -> Vec<f32> {
    // U²-NetP and YuNet share the bilinear CHW resizer. YuNet expects BGR in
    // 0..255 (OpenCV `blobFromImage` defaults), while the helper emits RGB in
    // 0..1, so scale and swap the red/blue planes.
    let mut tensor = preprocess_image_chw(
        rgba, src_w, src_h, INPUT_SIZE, INPUT_SIZE, &[0.0; 3], &[1.0; 3],
    );
    for value in &mut tensor {
        *value *= 255.0;
    }
    let plane = INPUT_SIZE * INPUT_SIZE;
    for i in 0..plane {
        tensor.swap(i, 2 * plane + i);
    }
    tensor
}

fn output<'a>(outputs: &'a HashMap<String, Vec<f32>>, name: &str) -> Result<&'a [f32], String> {
    outputs
        .get(name)
        .map(Vec::as_slice)
        .ok_or_else(|| format!("YuNet output '{name}' missing"))
}

/// Decodes YuNet's 12 heads into pixel-space boxes and applies greedy NMS.
///
/// Kept pure so the grid/box math can be tested without running the model.
pub(crate) fn decode(
    outputs: &HashMap<String, Vec<f32>>,
    input_w: usize,
    input_h: usize,
    score_threshold: f32,
    nms_threshold: f32,
) -> Result<Vec<FaceDetection>, String> {
    if input_w == 0
        || input_h == 0
        || !input_w.is_multiple_of(STRIDES[STRIDES.len() - 1])
        || !input_h.is_multiple_of(STRIDES[STRIDES.len() - 1])
    {
        return Err("YuNet input dimensions must be divisible by 32".into());
    }

    let mut faces = Vec::new();
    for stride in STRIDES {
        let cols = input_w / stride;
        let rows = input_h / stride;
        let cells = cols
            .checked_mul(rows)
            .ok_or_else(|| "YuNet grid overflows usize".to_string())?;
        let cls = output(outputs, &format!("cls_{stride}"))?;
        let obj = output(outputs, &format!("obj_{stride}"))?;
        let bbox = output(outputs, &format!("bbox_{stride}"))?;
        let kps = output(outputs, &format!("kps_{stride}"))?;

        if cls.len() < cells
            || obj.len() < cells
            || bbox.len() < cells * 4
            || kps.len() < cells * 10
        {
            return Err(format!(
                "YuNet stride {stride} heads have unexpected lengths"
            ));
        }

        for r in 0..rows {
            for c in 0..cols {
                let idx = r * cols + c;
                let cls_score = cls[idx].clamp(0.0, 1.0);
                let obj_score = obj[idx].clamp(0.0, 1.0);
                let score = (cls_score * obj_score).sqrt();
                if score < score_threshold {
                    continue;
                }

                let cx = (c as f32 + bbox[idx * 4]) * stride as f32;
                let cy = (r as f32 + bbox[idx * 4 + 1]) * stride as f32;
                let w = bbox[idx * 4 + 2].exp() * stride as f32;
                let h = bbox[idx * 4 + 3].exp() * stride as f32;
                if !cx.is_finite()
                    || !cy.is_finite()
                    || !w.is_finite()
                    || !h.is_finite()
                    || w <= 0.0
                    || h <= 0.0
                {
                    continue;
                }

                let mut landmarks = [[0.0f32; 2]; 5];
                for (n, landmark) in landmarks.iter_mut().enumerate() {
                    landmark[0] = (kps[idx * 10 + 2 * n] + c as f32) * stride as f32;
                    landmark[1] = (kps[idx * 10 + 2 * n + 1] + r as f32) * stride as f32;
                }

                faces.push(FaceDetection {
                    x: cx - w * 0.5,
                    y: cy - h * 0.5,
                    w,
                    h,
                    score,
                    landmarks,
                });
            }
        }
    }

    faces.sort_by(|a, b| {
        b.score
            .partial_cmp(&a.score)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    let mut keep = Vec::new();
    let mut suppressed = vec![false; faces.len()];
    for i in 0..faces.len() {
        if suppressed[i] {
            continue;
        }
        keep.push(faces[i]);
        if keep.len() >= TOP_K {
            break;
        }
        for j in (i + 1)..faces.len() {
            if !suppressed[j] && iou(&faces[i], &faces[j]) > nms_threshold {
                suppressed[j] = true;
            }
        }
    }
    Ok(keep)
}

fn iou(a: &FaceDetection, b: &FaceDetection) -> f32 {
    let x1 = a.x.max(b.x);
    let y1 = a.y.max(b.y);
    let x2 = (a.x + a.w).min(b.x + b.w);
    let y2 = (a.y + a.h).min(b.y + b.h);
    let inter = (x2 - x1).max(0.0) * (y2 - y1).max(0.0);
    let union = a.w * a.h + b.w * b.h - inter;
    if union <= 1e-6 {
        0.0
    } else {
        inter / union
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn blank_outputs(input_w: usize, input_h: usize) -> HashMap<String, Vec<f32>> {
        let mut outputs = HashMap::new();
        for stride in STRIDES {
            let cells = (input_w / stride) * (input_h / stride);
            outputs.insert(format!("cls_{stride}"), vec![0.0; cells]);
            outputs.insert(format!("obj_{stride}"), vec![0.0; cells]);
            outputs.insert(format!("bbox_{stride}"), vec![0.0; cells * 4]);
            outputs.insert(format!("kps_{stride}"), vec![0.0; cells * 10]);
        }
        outputs
    }

    fn set_detection(
        outputs: &mut HashMap<String, Vec<f32>>,
        stride: usize,
        r: usize,
        c: usize,
        cols: usize,
        bbox: [f32; 4],
        score: f32,
    ) {
        let idx = r * cols + c;
        outputs.get_mut(&format!("cls_{stride}")).unwrap()[idx] = score;
        outputs.get_mut(&format!("obj_{stride}")).unwrap()[idx] = score;
        let bbox_out = outputs.get_mut(&format!("bbox_{stride}")).unwrap();
        bbox_out[idx * 4..idx * 4 + 4].copy_from_slice(&bbox);
    }

    #[test]
    fn decodes_a_known_grid_cell() {
        let mut outputs = blank_outputs(640, 640);
        let stride = 8;
        let cols = 640 / stride;
        let ln2 = (2.0f32).ln();
        let ln4 = (4.0f32).ln();
        set_detection(
            &mut outputs,
            stride,
            10,
            20,
            cols,
            [0.5, 0.5, ln2, ln4],
            0.81,
        );

        let faces = decode(&outputs, 640, 640, 0.6, 0.3).expect("decode");
        assert_eq!(faces.len(), 1);
        let face = faces[0];
        assert!((face.x - 156.0).abs() < 1e-4, "x = {}", face.x);
        assert!((face.y - 68.0).abs() < 1e-4, "y = {}", face.y);
        assert!((face.w - 16.0).abs() < 1e-4, "w = {}", face.w);
        assert!((face.h - 32.0).abs() < 1e-4, "h = {}", face.h);
        assert!((face.score - 0.81).abs() < 1e-4, "score = {}", face.score);
    }

    #[test]
    fn suppresses_overlapping_faces() {
        let mut outputs = blank_outputs(640, 640);
        let stride = 8;
        let cols = 640 / stride;
        let bbox = [0.5, 0.5, (2.0f32).ln(), (4.0f32).ln()];
        set_detection(&mut outputs, stride, 10, 20, cols, bbox, 0.9);
        set_detection(&mut outputs, stride, 10, 21, cols, bbox, 0.8);

        let faces = decode(&outputs, 640, 640, 0.6, 0.3).expect("decode");
        assert_eq!(faces.len(), 1);
        assert!((faces[0].score - 0.9).abs() < 1e-4);
    }

    #[test]
    fn ignores_low_confidence_cells() {
        let mut outputs = blank_outputs(640, 640);
        let stride = 8;
        let cols = 640 / stride;
        set_detection(
            &mut outputs,
            stride,
            10,
            20,
            cols,
            [0.5, 0.5, 0.0, 0.0],
            0.25,
        );

        let faces = decode(&outputs, 640, 640, 0.6, 0.3).expect("decode");
        assert!(faces.is_empty());
    }

    #[test]
    fn blank_image_has_no_faces() {
        let size = 64;
        let mut rgba = vec![0u8; size * size * 4];
        for pixel in rgba.chunks_mut(4) {
            pixel[3] = 255;
        }
        let faces = detect(&rgba, size, size).expect("YuNet inference");
        assert!(faces.is_empty(), "unexpected faces: {faces:?}");
    }

    #[test]
    fn rejects_an_undersized_input() {
        let err = detect(&[0u8; 4], 2, 2).unwrap_err();
        assert!(err.contains("min 8x8"), "unexpected error: {err}");
    }
}
