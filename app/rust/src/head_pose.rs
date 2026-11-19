//! Head Pose estimation and facial geometry warping (Snapseed / Lightroom parity, #104).
//!
//! Computes 3D head orientation (Yaw, Pitch, Roll) from 5-point facial landmarks
//! and performs smooth localized facial deformation for pose tilting, smile adjustment,
//! and pupil distance scaling.

/// 3D Head orientation and facial bounds estimate.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct HeadPoseEstimate {
    /// Yaw angle in degrees (-45.0 left to +45.0 right).
    pub yaw: f32,
    /// Pitch angle in degrees (-30.0 down to +30.0 up).
    pub pitch: f32,
    /// Roll angle in degrees (-180.0 to +180.0 rotation).
    pub roll: f32,
    pub face_x: f32,
    pub face_y: f32,
    pub face_w: f32,
    pub face_h: f32,
}

/// Estimates head pose from YuNet face landmarks or fallback bounding geometry.
pub fn estimate_head_pose(rgba: &[u8], w: usize, h: usize) -> Result<HeadPoseEstimate, String> {
    if w == 0 || h == 0 || rgba.len() < w * h * 4 {
        return Err("Invalid image dimensions for head pose estimation".into());
    }

    #[cfg(feature = "ai")]
    {
        if let Ok(Some(face)) = crate::yunet::detect_largest_face(rgba, w, h) {
            let re = face.landmarks[0];
            let le = face.landmarks[1];
            let nose = face.landmarks[2];
            let rm = face.landmarks[3];
            let lm = face.landmarks[4];

            // Roll angle from eye slope
            let eye_dx = le[0] - re[0];
            let eye_dy = le[1] - re[1];
            let roll = eye_dy.atan2(eye_dx).to_degrees();

            let eye_center = [(re[0] + le[0]) * 0.5, (re[1] + le[1]) * 0.5];
            let ipd = (eye_dx * eye_dx + eye_dy * eye_dy).sqrt().max(1.0);

            // Yaw angle from nose deviation relative to eye midpoint
            let yaw = (((nose[0] - eye_center[0]) / (0.5 * ipd)) * 45.0).clamp(-45.0, 45.0);

            // Pitch angle from nose height relative to eye-mouth span
            let mouth_center = [(rm[0] + lm[0]) * 0.5, (rm[1] + lm[1]) * 0.5];
            let vert_span = (mouth_center[1] - eye_center[1]).abs().max(1.0);
            let nose_rel = (nose[1] - eye_center[1]) / vert_span;
            let pitch = ((nose_rel - 0.55) * 60.0).clamp(-30.0, 30.0);

            return Ok(HeadPoseEstimate {
                yaw,
                pitch,
                roll,
                face_x: face.x,
                face_y: face.y,
                face_w: face.w,
                face_h: face.h,
            });
        }
    }

    // Default neutral center face estimate
    let fw = (w as f32) * 0.35;
    let fh = (h as f32) * 0.45;
    let fx = ((w as f32) - fw) * 0.5;
    let fy = ((h as f32) - fh) * 0.4;
    Ok(HeadPoseEstimate {
        yaw: 0.0,
        pitch: 0.0,
        roll: 0.0,
        face_x: fx,
        face_y: fy,
        face_w: fw,
        face_h: fh,
    })
}

/// Adjusts facial pose and expression parameters.
///
/// * `delta_yaw`: -30.0 to +30.0 degrees
/// * `delta_pitch`: -20.0 to +20.0 degrees
/// * `delta_roll`: -20.0 to +20.0 degrees
/// * `smile`: 0.0 to 1.0 (neutral to bright smile)
/// * `pupil_distance`: -1.0 to +1.0 (narrow to wide)
#[allow(clippy::too_many_arguments)]
pub fn adjust_head_pose(
    rgba: &[u8],
    w: usize,
    h: usize,
    delta_yaw: f32,
    delta_pitch: f32,
    delta_roll: f32,
    smile: f32,
    pupil_distance: f32,
) -> Result<Vec<u8>, String> {
    if w == 0 || h == 0 || rgba.len() < w * h * 4 {
        return Err("Invalid buffer for head pose adjustment".into());
    }

    // If all adjustments are neutral, return copy
    if delta_yaw.abs() < 1e-3
        && delta_pitch.abs() < 1e-3
        && delta_roll.abs() < 1e-3
        && smile.abs() < 1e-3
        && pupil_distance.abs() < 1e-3
    {
        return Ok(rgba.to_vec());
    }

    let estimate = estimate_head_pose(rgba, w, h)?;
    let cx = estimate.face_x + estimate.face_w * 0.5;
    let cy = estimate.face_y + estimate.face_h * 0.5;
    let radius = (estimate.face_w.max(estimate.face_h) * 0.75).max(16.0);
    let radius_sq = radius * radius;

    // Angle radians
    let rad_yaw = delta_yaw.to_radians();
    let rad_pitch = delta_pitch.to_radians();
    let rad_roll = delta_roll.to_radians();

    let mut out = rgba.to_vec();

    for y in 0..h {
        let dy = y as f32 - cy;
        let row_off = y * w * 4;

        for x in 0..w {
            let dx = x as f32 - cx;
            let dist_sq = dx * dx + dy * dy;

            if dist_sq >= radius_sq {
                continue;
            }

            // Smooth C1 falloff weight (1.0 at center, 0.0 at radius)
            let norm_dist = (dist_sq / radius_sq).sqrt();
            let weight = (1.0 - norm_dist) * (1.0 - norm_dist);

            // Yaw horizontal displacement with cylindrical parallax
            let shift_x = rad_yaw.sin() * radius * 0.4 * weight;

            // Pitch vertical displacement
            let shift_y = rad_pitch.sin() * radius * 0.4 * weight;

            // Roll rotation
            let cos_r = rad_roll.cos();
            let sin_r = rad_roll.sin();
            let rot_x = (dx * cos_r - dy * sin_r - dx) * weight;
            let rot_y = (dx * sin_r + dy * cos_r - dy) * weight;

            // Smile adjustment (lifts mouth region: dy > 0.2 * face_h)
            let mut smile_y = 0.0f32;
            if dy > estimate.face_h * 0.15 && dy < estimate.face_h * 0.55 {
                let mouth_weight = (1.0
                    - ((dy - estimate.face_h * 0.35) / (estimate.face_h * 0.2)).abs())
                .max(0.0);
                smile_y =
                    -smile * 12.0 * mouth_weight * (dx.abs() / (estimate.face_w * 0.4)).min(1.0);
            }

            // Pupil distance adjustment (eyes region: dy < 0.0 && dy > -0.3 * face_h)
            let mut pupil_x = 0.0f32;
            if dy < 0.0 && dy > -estimate.face_h * 0.35 {
                let eye_weight = (1.0
                    - ((dy + estimate.face_h * 0.18) / (estimate.face_h * 0.18)).abs())
                .max(0.0);
                let side_sign = if dx >= 0.0 { 1.0 } else { -1.0 };
                pupil_x = side_sign * pupil_distance * 8.0 * eye_weight;
            }

            let src_x = (x as f32 - (shift_x + rot_x + pupil_x)).clamp(0.0, (w - 1) as f32);
            let src_y = (y as f32 - (shift_y + rot_y + smile_y)).clamp(0.0, (h - 1) as f32);

            let x0 = src_x.floor() as usize;
            let y0 = src_y.floor() as usize;
            let x1 = (x0 + 1).min(w - 1);
            let y1 = (y0 + 1).min(h - 1);
            let fx = src_x - x0 as f32;
            let fy = src_y - y0 as f32;

            let p00 = (y0 * w + x0) * 4;
            let p10 = (y0 * w + x1) * 4;
            let p01 = (y1 * w + x0) * 4;
            let p11 = (y1 * w + x1) * 4;

            let r = (1.0 - fx) * (1.0 - fy) * rgba[p00] as f32
                + fx * (1.0 - fy) * rgba[p10] as f32
                + (1.0 - fx) * fy * rgba[p01] as f32
                + fx * fy * rgba[p11] as f32;
            let g = (1.0 - fx) * (1.0 - fy) * rgba[p00 + 1] as f32
                + fx * (1.0 - fy) * rgba[p10 + 1] as f32
                + (1.0 - fx) * fy * rgba[p01 + 1] as f32
                + fx * fy * rgba[p11 + 1] as f32;
            let b = (1.0 - fx) * (1.0 - fy) * rgba[p00 + 2] as f32
                + fx * (1.0 - fy) * rgba[p10 + 2] as f32
                + (1.0 - fx) * fy * rgba[p01 + 2] as f32
                + fx * fy * rgba[p11 + 2] as f32;

            let px = row_off + x * 4;
            out[px] = r.round().clamp(0.0, 255.0) as u8;
            out[px + 1] = g.round().clamp(0.0, 255.0) as u8;
            out[px + 2] = b.round().clamp(0.0, 255.0) as u8;
        }
    }

    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_estimate_head_pose_fallback() {
        let dummy = vec![128u8; 64 * 64 * 4];
        let pose = estimate_head_pose(&dummy, 64, 64).expect("pose estimate");
        assert_eq!(pose.yaw, 0.0);
        assert_eq!(pose.pitch, 0.0);
        assert_eq!(pose.roll, 0.0);
        assert!(pose.face_w > 0.0);
        assert!(pose.face_h > 0.0);
    }

    #[test]
    fn test_adjust_head_pose_identity_when_zero() {
        let dummy = vec![128u8; 32 * 32 * 4];
        let res = adjust_head_pose(&dummy, 32, 32, 0.0, 0.0, 0.0, 0.0, 0.0).expect("adjust");
        assert_eq!(res, dummy);
    }

    #[test]
    fn test_adjust_head_pose_with_yaw_and_smile() {
        let mut dummy = vec![128u8; 48 * 48 * 4];
        // Draw a distinct feature in the face region
        dummy[(24 * 48 + 24) * 4] = 255;
        let res = adjust_head_pose(&dummy, 48, 48, 15.0, 5.0, 0.0, 0.8, 0.5).expect("adjust");
        assert_eq!(res.len(), dummy.len());
        assert_ne!(res, dummy, "Adjusted pose should modify pixels");
    }
}
