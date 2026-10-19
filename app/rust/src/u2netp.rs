//! U²-NetP salient-subject segmentation (ADR 0010, #87).
//!
//! The Apache-2.0 weights are bundled into the optional `ai` build and run
//! entirely on device. The default build stays free of ORT and model weights.

use std::sync::{Mutex, OnceLock};

use ort::session::Session;

use crate::ml::{preprocess_image_chw, resize_mask, Segmenter};
use crate::ort_runtime::{create_session, run_session};

const INPUT_SIZE: usize = 320;
const MEAN: [f32; 3] = [0.485, 0.456, 0.406];
const STD: [f32; 3] = [0.229, 0.224, 0.225];

const U2NETP_MODEL: &[u8] = include_bytes!("../assets/models/u2netp.onnx");

static SESSION: OnceLock<Result<Mutex<Session>, String>> = OnceLock::new();

fn session() -> Result<&'static Mutex<Session>, String> {
    SESSION
        .get_or_init(|| create_session(U2NETP_MODEL).map(Mutex::new))
        .as_ref()
        .map_err(Clone::clone)
}

/// U²-NetP (portable) salient-object segmenter.
#[derive(Debug, Clone, Copy, Default)]
pub struct U2NetpSegmenter;

impl Segmenter for U2NetpSegmenter {
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

        let input = preprocess_image_chw(rgba, src_w, src_h, INPUT_SIZE, INPUT_SIZE, &MEAN, &STD);
        if input.len() != 3 * INPUT_SIZE * INPUT_SIZE {
            return Err("U²-NetP preprocessing produced an invalid tensor".into());
        }

        let mut session = session()?
            .lock()
            .map_err(|_| "U²-NetP session lock poisoned".to_string())?;
        let raw = run_session(&mut session, &input, &[1, 3, INPUT_SIZE, INPUT_SIZE])?;
        if raw.len() != INPUT_SIZE * INPUT_SIZE {
            return Err(format!(
                "U²-NetP returned {} values, expected {}",
                raw.len(),
                INPUT_SIZE * INPUT_SIZE
            ));
        }

        let min = raw.iter().copied().fold(f32::INFINITY, f32::min);
        let max = raw.iter().copied().fold(f32::NEG_INFINITY, f32::max);
        let range = max - min;
        let normalized: Vec<f32> = if range > 1e-6 {
            raw.iter()
                .map(|v| ((v - min) / range).clamp(0.0, 1.0))
                .collect()
        } else {
            raw.iter().map(|v| v.clamp(0.0, 1.0)).collect()
        };

        Ok(resize_mask(
            &normalized,
            INPUT_SIZE,
            INPUT_SIZE,
            target_w,
            target_h,
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn centered_subject(size: usize) -> Vec<u8> {
        let mut rgba = vec![0u8; size * size * 4];
        for y in 0..size {
            for x in 0..size {
                let idx = (y * size + x) * 4;
                let (r, g, b) = if (size / 5..size * 4 / 5).contains(&x)
                    && (size / 5..size * 4 / 5).contains(&y)
                {
                    (235, 215, 160)
                } else {
                    (28, 32, 38)
                };
                rgba[idx] = r;
                rgba[idx + 1] = g;
                rgba[idx + 2] = b;
                rgba[idx + 3] = 255;
            }
        }
        rgba
    }

    #[test]
    fn segments_a_centered_subject() {
        let size = 128;
        let rgba = centered_subject(size);
        let mask = U2NetpSegmenter
            .segment(&rgba, size, size, 64, 64)
            .expect("U²-NetP inference");

        assert_eq!(mask.len(), 64 * 64);
        assert!(mask
            .iter()
            .all(|v| v.is_finite() && (0.0..=1.0).contains(v)));

        let mut center = 0.0f32;
        let mut center_count = 0usize;
        let mut border = 0.0f32;
        let mut border_count = 0usize;
        for y in 0..64 {
            for x in 0..64 {
                let value = mask[y * 64 + x];
                if (16..48).contains(&x) && (16..48).contains(&y) {
                    center += value;
                    center_count += 1;
                }
                if !(8..56).contains(&x) || !(8..56).contains(&y) {
                    border += value;
                    border_count += 1;
                }
            }
        }
        let center_mean = center / center_count as f32;
        let border_mean = border / border_count as f32;
        assert!(
            center_mean > border_mean + 0.20,
            "subject should dominate the center (center {center_mean:.3}, border {border_mean:.3})"
        );
    }

    #[test]
    fn rejects_an_undersized_buffer() {
        let err = U2NetpSegmenter.segment(&[0u8; 4], 2, 2, 8, 8).unwrap_err();
        assert!(err.contains("min src 4x4"), "unexpected error: {err}");
    }
}
