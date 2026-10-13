//! Image histogram core (P2).
//!
//! The spec's live-histogram trick is *compute on a small image*. We do it
//! entirely on the CPU (no GPU readback needed): downsample the source by a
//! stride to ~[`sample_dim`], run the same colour pipeline the LUT bakes, and
//! bin the result. That makes the histogram reflect the current *grade* and
//! stay unit-testable.

use crate::color::{grade_pixel_c, CurveSet, GradeParams};

/// Number of bins per channel.
pub const BINS: usize = 256;

/// 256-bin counts for R, G, B, and luminance (of the graded image).
pub struct Histogram {
    pub r: Vec<u32>,
    pub g: Vec<u32>,
    pub b: Vec<u32>,
    pub luma: Vec<u32>,
}

impl Histogram {
    fn empty() -> Self {
        Self {
            r: vec![0; BINS],
            g: vec![0; BINS],
            b: vec![0; BINS],
            luma: vec![0; BINS],
        }
    }
}

fn bin(v: f32) -> usize {
    (v.clamp(0.0, 1.0) * 255.0 + 0.5) as usize
}

/// Histogram of [rgba] after grading with [params], sampled by striding so at
/// most ~`sample_dim` samples are taken per axis.
pub fn histogram_graded(
    rgba: &[u8],
    width: u32,
    height: u32,
    params: GradeParams,
    sample_dim: u32,
    curves: Option<&CurveSet>,
) -> Histogram {
    let mut h = Histogram::empty();
    if width == 0 || height == 0 || rgba.len() < (width as usize * height as usize * 4) {
        return h;
    }
    let dim = sample_dim.max(1);
    let step = (width.max(height) / dim).max(1) as usize;

    for y in (0..height as usize).step_by(step) {
        for x in (0..width as usize).step_by(step) {
            let idx = (y * width as usize + x) * 4;
            let c = grade_pixel_c(
                rgba[idx] as f32 / 255.0,
                rgba[idx + 1] as f32 / 255.0,
                rgba[idx + 2] as f32 / 255.0,
                params,
                curves,
            );
            h.r[bin(c[0])] += 1;
            h.g[bin(c[1])] += 1;
            h.b[bin(c[2])] += 1;
            h.luma[bin(0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2])] += 1;
        }
    }
    h
}

#[cfg(test)]
mod tests {
    use super::*;

    fn solid(w: u32, h: u32, v: u8) -> Vec<u8> {
        let mut buf = Vec::with_capacity((w * h * 4) as usize);
        for _ in 0..w * h {
            buf.extend_from_slice(&[v, v, v, 255]);
        }
        buf
    }

    #[test]
    fn empty_for_degenerate_input() {
        let h = histogram_graded(&[], 0, 0, GradeParams::default(), 64, None);
        assert_eq!(h.r.iter().sum::<u32>(), 0u32);
    }

    #[test]
    fn solid_image_lands_in_one_bin() {
        let h = histogram_graded(
            &solid(64, 64, 128),
            64,
            64,
            GradeParams::default(),
            64,
            None,
        );
        // Neutral grade on mid-grey: one populated bin near 128.
        assert_eq!(h.r.iter().sum::<u32>(), 64u32 * 64);
        let peak = h.r.iter().enumerate().max_by_key(|(_, c)| **c).unwrap().0;
        assert!((peak as i32 - 128).abs() <= 2, "peak bin {peak}");
    }

    #[test]
    fn exposure_shifts_the_histogram_bright() {
        let src = solid(32, 32, 96);
        let neutral = histogram_graded(&src, 32, 32, GradeParams::default(), 32, None);
        let brighter = histogram_graded(
            &src,
            32,
            32,
            GradeParams {
                exposure: 1.0,
                ..Default::default()
            },
            32,
            None,
        );
        let mean = |h: &Histogram| {
            h.luma
                .iter()
                .enumerate()
                .map(|(i, c)| i as u64 * *c as u64)
                .sum::<u64>() as f64
                / h.luma.iter().map(|c| *c as u64).sum::<u64>() as f64
        };
        assert!(mean(&brighter) > mean(&neutral));
    }
}
