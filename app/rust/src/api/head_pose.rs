//! Flutter Rust Bridge API for Head Pose estimation & warping (#104).

use crate::head_pose::{adjust_head_pose as core_adjust, estimate_head_pose as core_estimate};

#[derive(Debug, Clone, Copy)]
pub struct ApiHeadPoseEstimate {
    pub yaw: f32,
    pub pitch: f32,
    pub roll: f32,
    pub face_x: f32,
    pub face_y: f32,
    pub face_w: f32,
    pub face_h: f32,
}

pub fn estimate_head_pose(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
) -> Result<ApiHeadPoseEstimate, String> {
    crate::validate::validate_rgba(&rgba, width, height)?;
    let est = core_estimate(&rgba, width as usize, height as usize)?;
    Ok(ApiHeadPoseEstimate {
        yaw: est.yaw,
        pitch: est.pitch,
        roll: est.roll,
        face_x: est.face_x,
        face_y: est.face_y,
        face_w: est.face_w,
        face_h: est.face_h,
    })
}

#[allow(clippy::too_many_arguments)]
pub fn adjust_head_pose(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    delta_yaw: f32,
    delta_pitch: f32,
    delta_roll: f32,
    smile: f32,
    pupil_distance: f32,
) -> Result<Vec<u8>, String> {
    crate::validate::validate_rgba(&rgba, width, height)?;
    core_adjust(
        &rgba,
        width as usize,
        height as usize,
        delta_yaw,
        delta_pitch,
        delta_roll,
        smile,
        pupil_distance,
    )
}
