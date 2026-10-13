//! Histogram API exposed across the `flutter_rust_bridge` boundary.
//!
//! Thin wrapper over [`crate::histogram`]: downsample + grade + bin on the CPU.

use crate::api::color::{to_hsl24, ColorParams, CurveParams};
use crate::histogram;

/// 256-bin counts for R, G, B and luminance of the graded image.
pub struct Histogram {
    pub r: Vec<u32>,
    pub g: Vec<u32>,
    pub b: Vec<u32>,
    pub luma: Vec<u32>,
}

/// Downsamples [rgba] by stride, applies the colour pipeline (and tone curves),
/// and bins the result. `sample_dim` caps the samples per axis (e.g. 256).
pub fn histogram_graded(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    params: ColorParams,
    sample_dim: u32,
    curves: CurveParams,
    hsl: Vec<f32>,
) -> Histogram {
    let set = curves.to_set();
    let h = histogram::histogram_graded(
        &rgba,
        width,
        height,
        params.to_core(),
        sample_dim,
        Some(&set),
        &to_hsl24(&hsl),
    );
    Histogram {
        r: h.r,
        g: h.g,
        b: h.b,
        luma: h.luma,
    }
}
