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
