//! Retouch API wrappers across flutter_rust_bridge.

use crate::retouch::{self, RetouchMode, RetouchPatch};

/// Flutter-facing retouch patch parameter descriptor.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ApiRetouchPatch {
    pub target_x: f32,
    pub target_y: f32,
    pub source_x: f32,
    pub source_y: f32,
    pub radius: f32,
    pub feather: f32,
    pub opacity: f32,
    pub is_clone: bool,
}

/// Applies a list of retouch patches onto the RGBA pixel buffer.
pub fn retouch_apply(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    patches: Vec<ApiRetouchPatch>,
) -> Vec<u8> {
    let internal_patches: Vec<RetouchPatch> = patches
        .into_iter()
        .map(|p| RetouchPatch {
            target_x: p.target_x,
            target_y: p.target_y,
            source_x: p.source_x,
            source_y: p.source_y,
            radius: p.radius,
            feather: p.feather,
            opacity: p.opacity,
            mode: if p.is_clone {
                RetouchMode::Clone
            } else {
                RetouchMode::Heal
            },
        })
        .collect();

    retouch::apply_retouch(&rgba, width as usize, height as usize, &internal_patches)
}
