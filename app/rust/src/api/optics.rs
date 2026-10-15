//! Optics API wrappers across flutter_rust_bridge.

use crate::optics::{self, OpticsParams};

/// The full optics pass (lateral CA removal → longitudinal defringe).
#[allow(clippy::too_many_arguments)]
pub fn optics_apply(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    remove_chromatic_aberration: bool,
    defringe_purple_amount: f32,
    defringe_purple_hue_min: f32,
    defringe_purple_hue_max: f32,
    defringe_green_amount: f32,
    defringe_green_hue_min: f32,
    defringe_green_hue_max: f32,
    profile_corrections: bool,
    profile_distortion: f32,
    profile_vignetting: f32,
) -> Vec<u8> {
    optics::apply_optics(
        &rgba,
        width as usize,
        height as usize,
        OpticsParams {
            remove_chromatic_aberration,
            defringe_purple_amount,
            defringe_purple_hue_min,
            defringe_purple_hue_max,
            defringe_green_amount,
            defringe_green_hue_min,
            defringe_green_hue_max,
            profile_corrections,
            profile_distortion,
            profile_vignetting,
        },
    )
}

/// Applies longitudinal defringe alone.
#[allow(clippy::too_many_arguments)]
pub fn optics_defringe(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    purple_amount: f32,
    purple_min: f32,
    purple_max: f32,
    green_amount: f32,
    green_min: f32,
    green_max: f32,
) -> Vec<u8> {
    optics::apply_defringe(
        &rgba,
        width as usize,
        height as usize,
        purple_amount,
        purple_min,
        purple_max,
        green_amount,
        green_min,
        green_max,
    )
}

/// Applies lateral chromatic aberration correction alone.
pub fn optics_lateral_ca(rgba: Vec<u8>, width: u32, height: u32) -> Vec<u8> {
    optics::apply_lateral_ca(&rgba, width as usize, height as usize)
}

/// Applies lens profile geometric distortion and vignetting correction alone.
pub fn optics_lens_profile(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    distortion: f32,
    vignetting: f32,
) -> Vec<u8> {
    optics::apply_lens_profile(
        &rgba,
        width as usize,
        height as usize,
        distortion,
        vignetting,
    )
}
