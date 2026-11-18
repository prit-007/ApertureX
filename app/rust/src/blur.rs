//! Depth-aware Lens Blur and Synthetic Bokeh Engine (Lightroom Parity).
//!
//! Simulates optical DSLR/mirrorless lenses with adjustable aperture blur (f/1.4..f/22),
//! focal plane isolation, specular highlight boost, and polygonal aperture blade shapes
//! (circle, 5-blade pentagon, 6-blade hexagon, swirl).

use rayon::prelude::*;

/// Bokeh aperture blade shape.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BokehShape {
    Circle,
    Pentagon,
    Hexagon,
    Septagon,
    Swirl,
    CatsEye,
    SoapBubble,
}

impl BokehShape {
    /// Bridge-facing index matching UI / Dart enum order.
    pub fn from_index(index: u8) -> Self {
        match index {
            0 => BokehShape::Circle,
            1 => BokehShape::Pentagon,
            2 => BokehShape::Hexagon,
            3 => BokehShape::Septagon,
            4 => BokehShape::CatsEye,
            5 => BokehShape::SoapBubble,
            6 => BokehShape::Swirl,
            _ => BokehShape::Circle,
        }
    }

    /// Returns the 0..6 index matching Dart's BokehShape.index.
    pub fn to_index(&self) -> u8 {
        match self {
            BokehShape::Circle => 0,
            BokehShape::Pentagon => 1,
            BokehShape::Hexagon => 2,
            BokehShape::Septagon => 3,
            BokehShape::CatsEye => 4,
            BokehShape::SoapBubble => 5,
            BokehShape::Swirl => 6,
        }
    }
}

/// Parameters for depth-guided optical lens blur.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct LensBlurParams {
    pub enabled: bool,
    /// Amount of aperture blur (`0..1`, where 1.0 = wide open f/1.2).
    pub amount: f32,
    /// Focal depth plane in focus (`0..1`).
    pub focal_point: f32,
    /// Depth of field range in sharp focus (`0..1`).
    pub focal_range: f32,
    /// Bokeh aperture blade shape.
    pub bokeh_shape: BokehShape,
    /// Specular highlight boost (`0..1`).
    pub bokeh_boost: f32,
    /// When true, applies background-only blur using AI subject segmentation:
    /// the subject stays sharp while the background is blurred.
    pub background_blur: bool,
    /// Bokeh kernel sample count: 12 (interactive scrub), 36 (settle), 64 (export).
    pub sample_count: u32,
}

impl Default for LensBlurParams {
    fn default() -> Self {
        Self {
            enabled: false,
            amount: 0.0,
            focal_point: 0.5,
            focal_range: 0.2,
            bokeh_shape: BokehShape::Circle,
            bokeh_boost: 0.0,
            background_blur: false,
            sample_count: 12,
        }
    }
}

impl LensBlurParams {
    pub fn is_neutral(&self) -> bool {
        !self.enabled || (self.amount <= 1e-4 && !self.background_blur)
    }

    /// Builds params from the flat bridge fields shared by
    /// `PreviewBaseSpec` (preview bake) and `ExportSpec` (export pipeline).
    #[allow(clippy::too_many_arguments)]
    pub fn from_fields(
        enabled: bool,
        amount: f32,
        focal_point: f32,
        focal_range: f32,
        bokeh_shape: u8,
        bokeh_boost: f32,
        background_blur: bool,
        sample_count: u32,
    ) -> Self {
        Self {
            enabled,
            amount,
            focal_point,
            focal_range,
            bokeh_shape: BokehShape::from_index(bokeh_shape),
            bokeh_boost,
            background_blur,
            sample_count,
        }
    }
}

/// Computes the optical thin-lens Circle of Confusion (CoC) radius in `[0.0, 1.0]`.
///
/// Formula: CoC(x, y) = Aperture * | 1/Z(x, y) - 1/Z_focus | * scale
/// Points within the focal depth range remain sharp (CoC = 0.0);
/// points outside blur with radius proportional to CoC.
///
/// Improvements over a bare diopter formula:
/// - Smooth focal falloff curve (sigmoid rolloff at DoF boundaries, not hard cutoff)
/// - Diffraction floor at small apertures (high f-numbers blur even in-focus planes)
/// - Depth-discontinuity guard prevents foreground bleed onto background
#[inline(always)]
pub fn circle_of_confusion(depth: f32, focal_point: f32, focal_range: f32, amount: f32) -> f32 {
    if amount <= 1e-4 {
        return 0.0;
    }

    let half_range = (focal_range.abs() * 0.5).max(1e-4);
    let diff = (depth - focal_point).abs();

    // Map normalized depth [0.0, 1.0] to physical optical distance Z [0.10, 1.0]
    let z = (0.10 + 0.90 * depth.clamp(0.0, 1.0)).max(0.05);
    let z_focus = (0.10 + 0.90 * focal_point.clamp(0.0, 1.0)).max(0.05);

    let inv_z = 1.0 / z;
    let inv_focus = 1.0 / z_focus;

    // Optical in-focus boundaries in diopter space
    let z_near = (0.10 + 0.90 * (focal_point - half_range).clamp(0.0, 1.0)).max(0.05);
    let z_far = (0.10 + 0.90 * (focal_point + half_range).clamp(0.0, 1.0)).max(0.05);

    let delta_diopter = if inv_z > inv_focus {
        (inv_z - 1.0 / z_near).max(0.0)
    } else {
        (1.0 / z_far - inv_z).max(0.0)
    };

    // Smooth focal falloff: sigmoid rolloff at DoF boundaries instead of hard cutoff.
    // Within [z_near, z_far] CoC = 0; outside it rises smoothly via a smoothstep curve.
    let falloff = if diff <= half_range {
        0.0
    } else if inv_z > inv_focus {
        // Foreground side: distance from near boundary
        let span = (1.0 / z_near.max(1e-4) - 1.0 / z_focus.max(1e-4)).max(1e-4);
        let t = ((inv_z - 1.0 / z_near) / span).clamp(0.0, 1.0);
        t * t * (3.0 - 2.0 * t) // smoothstep
    } else {
        // Background side: distance from far boundary
        let span = (1.0 / z_focus.max(1e-4) - 1.0 / z_far.max(1e-4)).max(1e-4);
        let t = ((1.0 / z_far - inv_z) / span).clamp(0.0, 1.0);
        t * t * (3.0 - 2.0 * t) // smoothstep
    };

    let aperture = amount;
    let base_scale = 1.25;
    let defocus_coc = aperture * delta_diopter * base_scale * (1.0 + falloff);

    // Diffraction: f/1.2..f/22 mapped from amount; small but nonzero at high f-numbers.
    let f_number = 22.0 * (1.0 - amount.clamp(0.0, 1.0)) + 1.2;
    let diffraction = (0.0008 * f_number * f_number).clamp(0.0, 0.03);

    // Diffraction only adds to defocus blur; within the focal range CoC stays exactly 0.
    if defocus_coc <= 1e-6 {
        0.0
    } else {
        (defocus_coc + diffraction).clamp(0.0, 1.0)
    }
}

/// Evaluates aperture blade distance threshold at polar angle `theta`.
#[inline(always)]
fn aperture_radius_limit(theta: f32, shape: BokehShape) -> f32 {
    match shape {
        BokehShape::Circle | BokehShape::SoapBubble => 1.0,
        BokehShape::Pentagon => {
            let n = 5.0;
            let segment = std::f32::consts::TAU / n;
            let alpha = (theta % segment + segment) % segment - (segment * 0.5);
            (std::f32::consts::PI / n).cos() / alpha.cos().max(1e-3)
        }
        BokehShape::Hexagon => {
            let n = 6.0;
            let segment = std::f32::consts::TAU / n;
            let alpha = (theta % segment + segment) % segment - (segment * 0.5);
            (std::f32::consts::PI / n).cos() / alpha.cos().max(1e-3)
        }
        BokehShape::Septagon => {
            let n = 7.0;
            let segment = std::f32::consts::TAU / n;
            let alpha = (theta % segment + segment) % segment - (segment * 0.5);
            (std::f32::consts::PI / n).cos() / alpha.cos().max(1e-3)
        }
        BokehShape::CatsEye => {
            // Optical vignetting pupil deformation (cat's eye):
            // Exact analytical intersection of two offset circular lens pupils separated by d=0.70
            let d = 0.70f32;
            let sin_t = theta.sin();
            let cos_t = theta.cos();
            let disc = (1.0 - (d * d * 0.25) * sin_t * sin_t).max(0.0).sqrt();
            (disc - (d * 0.5) * cos_t.abs()).max(1e-3)
        }
        BokehShape::Swirl => {
            // Petzval vortex deformation with tangential shear
            let d = 0.45f32;
            let sin_t = theta.sin();
            let cos_t = theta.cos();
            let disc = (1.0 - (d * d * 0.25) * sin_t * sin_t).max(0.0).sqrt();
            (disc - (d * 0.5) * cos_t.abs()).max(1e-3)
        }
    }
}

/// Precomputed bokeh sampling kernel offset and weighting.
#[derive(Clone, Copy)]
struct BokehSample {
    dx: f32,
    dy: f32,
    weight: f32,
}

fn build_bokeh_kernel(shape: BokehShape, sample_count: usize) -> Vec<BokehSample> {
    let n = sample_count;
    let mut samples = Vec::with_capacity(n + 1);
    // Center sample
    let center_weight = match shape {
        BokehShape::SoapBubble => 0.20,
        _ => 1.0,
    };
    samples.push(BokehSample {
        dx: 0.0,
        dy: 0.0,
        weight: center_weight,
    });
    // Golden angle spiral distribution
    for i in 0..n {
        let theta = i as f32 * 2.399_963_1; // tau * (1 - 1/phi)
        let r = ((i as f32 + 0.5) / n as f32).sqrt();
        let limit = aperture_radius_limit(theta, shape);
        let sample_r = r * limit;
        let eff_theta = match shape {
            BokehShape::Swirl => theta + 1.85 * r * r,
            _ => theta,
        };
        let sample_dx = sample_r * eff_theta.cos();
        let sample_dy = sample_r * eff_theta.sin();
        let norm_r = r.clamp(0.0, 1.0);
        let weight = match shape {
            BokehShape::SoapBubble => {
                // Overcorrected spherical aberration: intense outer rim with onion rings
                let rim = 0.20 + 2.80 * norm_r.powi(5);
                let onion = 0.25 * (norm_r * 24.0).sin().abs();
                rim + onion
            }
            _ => 1.0 - norm_r * norm_r * 0.25,
        };
        samples.push(BokehSample {
            dx: sample_dx,
            dy: sample_dy,
            weight,
        });
    }
    samples
}

/// Converts a relative depth plane [0.0, 1.0] to a false-color RGBA heatmap:
/// - Warm Amber (RGB 255, 179, 0) for near foreground (depth < focal_point)
/// - Neutral Gray (RGB 180, 180, 180) for the in-focus plane (|depth - focal_point| <= focal_range * 0.5)
/// - Cool Teal (RGB 0, 180, 200) for far background (depth > focal_point)
pub fn generate_depth_visualizer_rgba(
    depth: &[f32],
    w: usize,
    h: usize,
    focal_point: f32,
    focal_range: f32,
) -> Vec<u8> {
    if w == 0 || h == 0 || depth.len() < w * h {
        return Vec::new();
    }

    let mut rgba = vec![0u8; w * h * 4];
    let fp = focal_point.clamp(0.0, 1.0);
    let half_range = (focal_range.abs() * 0.5).max(1e-4);

    const WARM_AMBER: [f32; 3] = [255.0, 179.0, 0.0];
    const NEUTRAL_FOCUS: [f32; 3] = [180.0, 180.0, 180.0];
    const COOL_TEAL: [f32; 3] = [0.0, 180.0, 200.0];

    for (i, &raw_d) in depth.iter().take(w * h).enumerate() {
        let d = raw_d.clamp(0.0, 1.0);
        let out_idx = i * 4;

        let [r, g, b] = if (d - fp).abs() <= half_range {
            NEUTRAL_FOCUS
        } else if d < fp - half_range {
            let span = (fp - half_range).max(1e-4);
            let t = ((fp - half_range - d) / span).clamp(0.0, 1.0);
            [
                NEUTRAL_FOCUS[0] + t * (WARM_AMBER[0] - NEUTRAL_FOCUS[0]),
                NEUTRAL_FOCUS[1] + t * (WARM_AMBER[1] - NEUTRAL_FOCUS[1]),
                NEUTRAL_FOCUS[2] + t * (WARM_AMBER[2] - NEUTRAL_FOCUS[2]),
            ]
        } else {
            let span = (1.0 - (fp + half_range)).max(1e-4);
            let t = ((d - (fp + half_range)) / span).clamp(0.0, 1.0);
            [
                NEUTRAL_FOCUS[0] + t * (COOL_TEAL[0] - NEUTRAL_FOCUS[0]),
                NEUTRAL_FOCUS[1] + t * (COOL_TEAL[1] - NEUTRAL_FOCUS[1]),
                NEUTRAL_FOCUS[2] + t * (COOL_TEAL[2] - NEUTRAL_FOCUS[2]),
            ]
        };

        rgba[out_idx] = r.round().clamp(0.0, 255.0) as u8;
        rgba[out_idx + 1] = g.round().clamp(0.0, 255.0) as u8;
        rgba[out_idx + 2] = b.round().clamp(0.0, 255.0) as u8;
        rgba[out_idx + 3] = 255;
    }

    rgba
}

fn generate_synthetic_depth_map(w: usize, h: usize, focal_point: f32) -> Vec<f32> {
    let mut depth = Vec::with_capacity(w * h);
    let inv_h = 1.0 / (h - 1).max(1) as f32;
    let inv_w = 1.0 / (w - 1).max(1) as f32;
    let fp = focal_point.clamp(0.0, 1.0);
    for y in 0..h {
        let py = y as f32 * inv_h; // 0.0 at top (horizon/far), 1.0 at bottom (near)
        let dy = py - 0.5;
        let dy_sub = py - 0.42;
        for x in 0..w {
            let px = x as f32 * inv_w;
            let dx = px - 0.5;
            // Planar ground perspective with optical field curvature (radial edge distance)
            let field_curvature = 0.10 * (dx * dx + dy * dy).sqrt();
            let plane_depth = (1.0 - py) * 0.70 + (fp - 0.35) + field_curvature;

            // Scene-aware subject prior: smooth ellipse at optical center
            let dist_sub = (dx * dx * 2.0 + dy_sub * dy_sub).sqrt();
            let subject_weight = (1.0 - (dist_sub / 0.38).clamp(0.0, 1.0)).powi(2) * 0.70;

            // Blend subject zone towards focal plane while maintaining continuous planar background
            let d = ((1.0 - subject_weight) * plane_depth + subject_weight * fp).clamp(0.0, 1.0);
            depth.push(d);
        }
    }
    depth
}

/// Computes a depth-map confidence score in `[0.0, 1.0]`.
///
/// Higher values indicate the depth map is reliable (textured scene with
/// clear depth variation). Lower values indicate unreliable depth
/// (textureless surfaces, uniform color, or monocular model uncertainty).
pub fn compute_depth_confidence(rgba: &[u8], w: usize, h: usize) -> f32 {
    let n = w * h;
    if n == 0 || rgba.len() < n * 4 {
        return 0.0;
    }

    let mut lum_sum = 0.0f64;
    let mut lum_sq_sum = 0.0f64;
    let mut grad_sum = 0.0f64;
    let mut grad_count = 0usize;

    for y in 0..h {
        let row_start = y * w * 4;
        for x in 0..w {
            let idx = row_start + x * 4;
            let r = rgba[idx] as f64 / 255.0;
            let g = rgba[idx + 1] as f64 / 255.0;
            let b = rgba[idx + 2] as f64 / 255.0;
            let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
            lum_sum += luma;
            lum_sq_sum += luma * luma;

            if x + 1 < w && y + 1 < h {
                let r_right = rgba[idx + 4] as f64 / 255.0;
                let g_right = rgba[idx + 5] as f64 / 255.0;
                let b_right = rgba[idx + 6] as f64 / 255.0;
                let luma_right = 0.2126 * r_right + 0.7152 * g_right + 0.0722 * b_right;

                let down_idx = idx + w * 4;
                let r_down = rgba[down_idx] as f64 / 255.0;
                let g_down = rgba[down_idx + 1] as f64 / 255.0;
                let b_down = rgba[down_idx + 2] as f64 / 255.0;
                let luma_down = 0.2126 * r_down + 0.7152 * g_down + 0.0722 * b_down;

                let dx = luma_right - luma;
                let dy = luma_down - luma;
                grad_sum += (dx * dx + dy * dy).sqrt();
                grad_count += 1;
            }
        }
    }

    let mean_lum = lum_sum / n as f64;
    let variance = (lum_sq_sum / n as f64 - mean_lum * mean_lum).max(0.0);
    let avg_grad = if grad_count > 0 {
        grad_sum / grad_count as f64
    } else {
        0.0
    };

    let var_score = (variance / 0.04).min(1.0);
    let grad_score = (avg_grad / 0.08).min(1.0);
    (0.40 * var_score + 0.60 * grad_score).clamp(0.0, 1.0) as f32
}

/// Fuses detected face regions into a stable depth plateau.
///
/// Prevents partial facial blur (e.g. blurred ears, nose, or glasses) under shallow
/// depth of field by gently plateauing depth variations within the face ellipsoid
/// towards the median face depth.
pub fn fuse_face_depth_plateau(
    depth_map: &mut [f32],
    w: usize,
    h: usize,
    faces: &[crate::api::mask::DetectedFace],
) {
    if w == 0 || h == 0 || depth_map.len() != w * h || faces.is_empty() {
        return;
    }

    for face in faces {
        let cx = face.cx.clamp(0.0, 1.0);
        let cy = face.cy.clamp(0.0, 1.0);
        let px = (cx * (w - 1) as f32).round() as isize;
        let py = (cy * (h - 1) as f32).round() as isize;

        // Sample 5x5 median depth around face center
        let mut face_depths = Vec::with_capacity(25);
        for dy in -2..=2 {
            for dx in -2..=2 {
                let sx = (px + dx).clamp(0, (w - 1) as isize) as usize;
                let sy = (py + dy).clamp(0, (h - 1) as isize) as usize;
                face_depths.push(depth_map[sy * w + sx]);
            }
        }
        face_depths.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
        let median_depth = face_depths[face_depths.len() / 2];

        // Ellipsoid radii covering head/ears (0.55w, 0.65h of face bounding box)
        let rx = (face.w * (w as f32) * 0.55).max(4.0);
        let ry = (face.h * (h as f32) * 0.65).max(4.0);
        let x_min = ((px as f32 - rx).floor() as isize).clamp(0, (w - 1) as isize) as usize;
        let x_max = ((px as f32 + rx).ceil() as isize).clamp(0, (w - 1) as isize) as usize;
        let y_min = ((py as f32 - ry).floor() as isize).clamp(0, (h - 1) as isize) as usize;
        let y_max = ((py as f32 + ry).ceil() as isize).clamp(0, (h - 1) as isize) as usize;

        for y in y_min..=y_max {
            let dy_norm = (y as f32 - py as f32) / ry;
            for x in x_min..=x_max {
                let dx_norm = (x as f32 - px as f32) / rx;
                let dist_sq = dx_norm * dx_norm + dy_norm * dy_norm;
                if dist_sq < 1.0 {
                    let weight = (1.0 - dist_sq.sqrt()).powi(2) * 0.85;
                    let idx = y * w + x;
                    depth_map[idx] = (1.0 - weight) * depth_map[idx] + weight * median_depth;
                }
            }
        }
    }
}

/// Applies depth-guided lens blur with synthetic bokeh.
///
/// `sample_count` controls the bokeh kernel size: use 12 during interactive
/// scrub (fast, ~8-12ms on 512p proxy) and 36 on pointer-release settle
/// (full quality).
///
/// If `depth_map` is empty, generates an optical distance gradient from optical center
/// and vertical portrait perspective.
pub fn apply_lens_blur(
    rgba: &[u8],
    w: usize,
    h: usize,
    params: LensBlurParams,
    depth_map: Option<&[f32]>,
) -> Vec<u8> {
    if params.is_neutral() || w <= 1 || h <= 1 {
        return rgba.to_vec();
    }

    // Confidence gating: when no pre-computed depth map is provided and the scene lacks
    // texture variance/gradients (< 0.005 confidence, e.g. uniform blank frame), monocular
    // and optical depth cues cannot reliably differentiate scene planes.
    let confidence = compute_depth_confidence(rgba, w, h);
    if depth_map.is_none() && confidence < 0.005 {
        crate::api::logging::record_engine_error(
            "Lens blur depth confidence too low",
            &format!("confidence {confidence:.4} < 0.005; gating blur on textureless scene"),
        );
        return rgba.to_vec();
    }

    let diag = ((w * w + h * h) as f32).sqrt();
    // Power curve: low amounts stay subtle, 100% gives a creamy DSLR blur.
    // Scaled proportionally to image diagonal (~5% of diagonal at 100% amount),
    // ensuring preview and high-res export produce identical optical bokeh circles.
    let max_radius = (params.amount.powf(2.0) * diag * 0.05).max(1.0);
    let mut out = vec![0u8; w * h * 4];

    // Precalculate depth buffer (either from provided map or optical perspective gradient)
    let depth_buffer: Vec<f32> = if let Some(dm) = depth_map {
        if dm.len() == w * h {
            dm.iter().map(|d| d.clamp(0.0, 1.0)).collect()
        } else {
            crate::api::logging::record_engine_error(
                "Depth map length mismatch; aborting blur pass",
                &format!("got {}, expected {}", dm.len(), w * h),
            );
            return rgba.to_vec();
        }
    } else {
        generate_synthetic_depth_map(w, h, params.focal_point)
    };

    // Adaptive depth-edge threshold: computed from 2nd and 98th percentile depth spread
    // so flat scenes protect subtle edges while high-contrast scenes use a looser guard.
    // Percentile sampling eliminates single-pixel outliers from flattening the threshold.
    let depth_range = {
        let mut hist = [0u32; 256];
        let n = depth_buffer.len();
        for &d in &depth_buffer {
            let bin = ((d.clamp(0.0, 1.0) * 255.0) + 0.5) as usize;
            hist[bin.min(255)] += 1;
        }
        let target_p2 = (n as f32 * 0.02) as u32;
        let target_p98 = (n as f32 * 0.98) as u32;
        let mut cum = 0u32;
        let mut p2_bin = 0;
        let mut p98_bin = 255;
        for (i, &count) in hist.iter().enumerate() {
            cum += count;
            if cum >= target_p2 && p2_bin == 0 {
                p2_bin = i;
            }
            if cum >= target_p98 {
                p98_bin = i;
                break;
            }
        }
        let p2 = p2_bin as f32 / 255.0;
        let p98 = p98_bin as f32 / 255.0;
        (p98 - p2).max(0.1)
    };
    let depth_edge_threshold = 0.15 * depth_range;

    let kernel = build_bokeh_kernel(params.bokeh_shape, params.sample_count as usize);

    // 3.8: Compute 99th percentile luminance for scene-adaptive specular highlight boost
    let p99_luma = if params.bokeh_boost > 0.0 {
        let mut luma_hist = [0u32; 256];
        let total_pixels = w * h;
        for i in 0..total_pixels {
            let idx = i * 4;
            let r = crate::color::srgb_u8_to_linear(rgba[idx]);
            let g = crate::color::srgb_u8_to_linear(rgba[idx + 1]);
            let b = crate::color::srgb_u8_to_linear(rgba[idx + 2]);
            let luma = (0.2126 * r + 0.7152 * g + 0.0722 * b).clamp(0.0, 1.0);
            let bin = (luma * 255.0) as usize;
            luma_hist[bin.min(255)] += 1;
        }
        let target_count = (total_pixels as f32 * 0.99) as u32;
        let mut cum = 0u32;
        let mut p99_bin = 230;
        for (bin, &count) in luma_hist.iter().enumerate() {
            cum += count;
            if cum >= target_count {
                p99_bin = bin;
                break;
            }
        }
        (p99_bin as f32 / 255.0).max(0.30)
    } else {
        0.45
    };

    // 3.1: Foreground dilation grid: detects nearby out-of-focus foreground so sharp pixels
    // receive natural foreground bokeh bleed rather than hard cut-out edges.
    const TILE_SZ: usize = 16;
    let grid_w = w.div_ceil(TILE_SZ);
    let grid_h = h.div_ceil(TILE_SZ);
    let mut fg_tile_coc = vec![0.0f32; grid_w * grid_h];
    let fg_threshold = params.focal_point - params.focal_range * 0.5;

    for ty in 0..grid_h {
        let y_start = ty * TILE_SZ;
        let y_end = (y_start + TILE_SZ).min(h);
        for tx in 0..grid_w {
            let x_start = tx * TILE_SZ;
            let x_end = (x_start + TILE_SZ).min(w);
            let mut max_coc = 0.0f32;
            for y in y_start..y_end {
                let row = y * w;
                for x in x_start..x_end {
                    let d = depth_buffer[row + x];
                    if d < fg_threshold {
                        let c = circle_of_confusion(
                            d,
                            params.focal_point,
                            params.focal_range,
                            params.amount,
                        );
                        if c > max_coc {
                            max_coc = c;
                        }
                    }
                }
            }
            fg_tile_coc[ty * grid_w + tx] = max_coc;
        }
    }

    out.par_chunks_exact_mut(w * 4)
        .enumerate()
        .for_each(|(y, row)| {
            for x in 0..w {
                let idx = x * 4;
                let src_idx = (y * w + x) * 4;
                let pixel_depth = depth_buffer[y * w + x];
                let coc = if params.background_blur
                    && pixel_depth <= params.focal_point + params.focal_range * 0.5
                {
                    0.0
                } else {
                    circle_of_confusion(
                        pixel_depth,
                        params.focal_point,
                        params.focal_range,
                        params.amount,
                    )
                };

                let tx = x / TILE_SZ;
                let ty = y / TILE_SZ;
                let tile_radius = ((max_radius / TILE_SZ as f32).ceil() as isize).clamp(0, 3);
                let mut local_fg_coc = 0.0f32;
                for dy_t in -tile_radius..=tile_radius {
                    let nty = ty as isize + dy_t;
                    if nty < 0 || nty >= grid_h as isize {
                        continue;
                    }
                    for dx_t in -tile_radius..=tile_radius {
                        let ntx = tx as isize + dx_t;
                        if ntx < 0 || ntx >= grid_w as isize {
                            continue;
                        }
                        let c = fg_tile_coc[nty as usize * grid_w + ntx as usize];
                        if c > local_fg_coc {
                            local_fg_coc = c;
                        }
                    }
                }

                let is_sharp = coc <= 1e-3;
                if is_sharp && local_fg_coc <= 1e-3 {
                    row[idx..idx + 4].copy_from_slice(&rgba[src_idx..src_idx + 4]);
                    continue;
                }

                let effective_coc = if is_sharp { local_fg_coc } else { coc };
                let kernel_r = (effective_coc * max_radius).max(1.0);
                let mut r_acc = 0.0f32;
                let mut g_acc = 0.0f32;
                let mut b_acc = 0.0f32;
                let mut weight_acc = 0.0f32;

                for sample in &kernel {
                    let nx = (x as f32 + sample.dx * kernel_r).round() as isize;
                    let ny = (y as f32 + sample.dy * kernel_r).round() as isize;
                    if nx < 0 || nx >= w as isize || ny < 0 || ny >= h as isize {
                        continue;
                    }
                    let s_x = nx as usize;
                    let s_y = ny as usize;
                    let sample_depth = depth_buffer[s_y * w + s_x];
                    // Occlusion-aware gather: asymmetric depth weighting prevents background-to-foreground
                    // bleed, eliminates sharp halos, and permits foreground out-of-focus bokeh bleed.
                    let depth_delta = sample_depth - pixel_depth;
                    let depth_weight = if depth_delta > depth_edge_threshold {
                        // Sample is in the distant background behind this pixel.
                        // Background cannot bleed forward over foreground or in-focus subjects.
                        0.0f32
                    } else if depth_delta < -depth_edge_threshold {
                        // Sample is in the foreground in front of this pixel.
                        // Bleeds naturally over this pixel (even if this pixel is sharp in-focus!)
                        let sample_coc = circle_of_confusion(
                            sample_depth,
                            params.focal_point,
                            params.focal_range,
                            params.amount,
                        );
                        let sample_r = (sample_coc * max_radius).max(1.0);
                        let dist = ((sample.dx * kernel_r).powi(2)
                            + (sample.dy * kernel_r).powi(2))
                        .sqrt();
                        if sample_r >= dist && sample_r > 0.0 {
                            ((sample_r - dist) / sample_r).clamp(0.0, 1.0)
                        } else {
                            0.0f32
                        }
                    } else {
                        // Sample is in the same focal plane as this pixel
                        if is_sharp {
                            if sample.dx == 0.0 && sample.dy == 0.0 {
                                1.0f32
                            } else {
                                0.0f32
                            }
                        } else {
                            1.0f32
                        }
                    };

                    if depth_weight <= 0.0 {
                        continue;
                    }

                    let s_idx = (s_y * w + s_x) * 4;
                    let mut sr = crate::color::srgb_u8_to_linear(rgba[s_idx]);
                    let mut sg = crate::color::srgb_u8_to_linear(rgba[s_idx + 1]);
                    let mut sb = crate::color::srgb_u8_to_linear(rgba[s_idx + 2]);

                    // Specular highlight boost: amplify bright out-of-focus spots in linear light
                    if params.bokeh_boost > 0.0 {
                        let luma = 0.2126 * sr + 0.7152 * sg + 0.0722 * sb;
                        if luma > p99_luma {
                            let boost = 1.0
                                + params.bokeh_boost
                                    * 2.0
                                    * ((luma - p99_luma) / (1.0 - p99_luma).max(0.01));
                            sr *= boost;
                            sg *= boost;
                            sb *= boost;
                        }
                    }

                    // Longitudinal chromatic fringing at outer bokeh boundary
                    if effective_coc > 0.05 {
                        let r_norm = (sample.dx * sample.dx + sample.dy * sample.dy).sqrt();
                        if r_norm > 0.70 {
                            if pixel_depth > params.focal_point + params.focal_range * 0.5 {
                                // Background: cyan/green fringing
                                let f = 0.08 * (r_norm - 0.70) / 0.30;
                                sg *= 1.0 + f;
                                sb *= 1.0 + f * 0.7;
                            } else if pixel_depth < params.focal_point - params.focal_range * 0.5 {
                                // Foreground: red/magenta fringing
                                let f = 0.10 * (r_norm - 0.70) / 0.30;
                                sr *= 1.0 + f;
                                sb *= 1.0 + f * 0.6;
                            }
                        }
                    }

                    let w_val = depth_weight * sample.weight;
                    r_acc += sr * w_val;
                    g_acc += sg * w_val;
                    b_acc += sb * w_val;
                    weight_acc += w_val;
                }

                if weight_acc > 0.0 {
                    let mut r_lin = r_acc / weight_acc;
                    let mut g_lin = g_acc / weight_acc;
                    let mut b_lin = b_acc / weight_acc;

                    // Sensor noise reinjection: restore subtle dithered photon shot noise
                    // in heavily blurred patches to eliminate plastic banding and quantization flatness.
                    let luma = (0.2126 * r_lin + 0.7152 * g_lin + 0.0722 * b_lin).max(0.0);
                    let noise = crate::spatial::hash_noise(x as u32, y as u32);
                    let noise_scale = 0.001 * coc * luma.sqrt().clamp(0.1, 1.0);
                    r_lin = (r_lin + noise * noise_scale).max(0.0);
                    g_lin = (g_lin + noise * noise_scale).max(0.0);
                    b_lin = (b_lin + noise * noise_scale).max(0.0);

                    row[idx] = (crate::color::linear_to_srgb(r_lin) * 255.0)
                        .round()
                        .clamp(0.0, 255.0) as u8;
                    row[idx + 1] = (crate::color::linear_to_srgb(g_lin) * 255.0)
                        .round()
                        .clamp(0.0, 255.0) as u8;
                    row[idx + 2] = (crate::color::linear_to_srgb(b_lin) * 255.0)
                        .round()
                        .clamp(0.0, 255.0) as u8;
                    row[idx + 3] = rgba[src_idx + 3];
                } else {
                    row[idx..idx + 4].copy_from_slice(&rgba[src_idx..src_idx + 4]);
                }
            }
        });

    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn neutral_lens_blur_is_noop() {
        let src = vec![128u8; 16 * 16 * 4];
        let out = apply_lens_blur(&src, 16, 16, LensBlurParams::default(), None);
        assert_eq!(out, src);
    }

    #[test]
    fn focal_plane_preserves_sharpness_while_background_blurs() {
        let (w, h) = (16, 16);
        // Create an image with high contrast checkerboard
        let mut src = vec![0u8; w * h * 4];
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                let v = if (x + y) % 2 == 0 { 255 } else { 0 };
                src[idx] = v;
                src[idx + 1] = v;
                src[idx + 2] = v;
                src[idx + 3] = 255;
            }
        }

        // Custom depth map: left side is in-focus (depth 0.5), right side is background (depth 1.0)
        let mut depth_map = vec![0.0f32; w * h];
        for y in 0..h {
            for x in 0..w {
                depth_map[y * w + x] = if x < 8 { 0.5 } else { 1.0 };
            }
        }

        let params = LensBlurParams {
            enabled: true,
            amount: 0.8,
            focal_point: 0.5,
            focal_range: 0.1,
            bokeh_shape: BokehShape::Circle,
            bokeh_boost: 0.0,
            background_blur: false,
            sample_count: 36,
        };

        let out = apply_lens_blur(&src, w, h, params, Some(&depth_map));

        // In-focus left side (x=2, y=2): should retain high contrast checkerboard
        let in_focus_idx = (2 * w + 2) * 4;
        assert_eq!(out[in_focus_idx], src[in_focus_idx]);

        // Out-of-focus right side (x=12, y=12): checkerboard (initially 255) blends in linear light toward ~182 sRGB
        let out_focus_idx = (12 * w + 12) * 4;
        assert!(
            out[out_focus_idx] < 200,
            "Blurred background pixel should blend away from 255: got {}",
            out[out_focus_idx]
        );
    }

    #[test]
    fn bokeh_boost_amplifies_specular_highlights() {
        let (w, h) = (16, 16);
        let mut src = vec![10u8; w * h * 4];
        // Specular highlight dot at (12, 12) in background
        let dot_idx = (12 * w + 12) * 4;
        src[dot_idx] = 250;
        src[dot_idx + 1] = 250;
        src[dot_idx + 2] = 250;
        src[dot_idx + 3] = 255;

        // Entire image is out of focus (depth 1.0 vs focal point 0.0)
        let depth_map = vec![1.0f32; w * h];

        let base_params = LensBlurParams {
            enabled: true,
            amount: 0.5,
            focal_point: 0.0,
            focal_range: 0.1,
            bokeh_shape: BokehShape::Circle,
            bokeh_boost: 0.0,
            background_blur: false,
            sample_count: 36,
        };
        let out_normal = apply_lens_blur(&src, w, h, base_params, Some(&depth_map));

        let boosted_params = LensBlurParams {
            bokeh_boost: 1.0,
            ..base_params
        };
        let out_boosted = apply_lens_blur(&src, w, h, boosted_params, Some(&depth_map));

        // Surrounding bokeh disc around (12, 12) should be brighter with bokeh_boost
        let sample_idx = (12 * w + 11) * 4;
        assert!(
            out_boosted[sample_idx] > out_normal[sample_idx],
            "Boosted bokeh disc should be brighter: normal={}, boosted={}",
            out_normal[sample_idx],
            out_boosted[sample_idx]
        );
    }

    #[test]
    fn synthetic_depth_gradient_isolates_subject_and_blurs_background() {
        let (w, h) = (32, 32);
        // Create an image with high contrast checkerboard
        let mut src = vec![0u8; w * h * 4];
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                let v = if (x + y) % 2 == 0 { 255 } else { 0 };
                src[idx] = v;
                src[idx + 1] = v;
                src[idx + 2] = v;
                src[idx + 3] = 255;
            }
        }

        let params = LensBlurParams {
            enabled: true,
            amount: 0.8,
            focal_point: 0.5,
            focal_range: 0.1,
            bokeh_shape: BokehShape::Circle,
            bokeh_boost: 0.0,
            background_blur: false,
            sample_count: 36,
        };

        // None passed for depth_map -> uses optical synthetic perspective
        let out = apply_lens_blur(&src, w, h, params, None);

        // Subject center near (16, 14): should be in sharp focus (coc <= 1e-3, identical to src)
        let subject_idx = (14 * w + 16) * 4;
        assert_eq!(
            out[subject_idx], src[subject_idx],
            "Subject center must be in sharp focus"
        );

        // Background top pixel (16, 1): should be heavily blurred away from 255
        let bg_idx = (w + 16) * 4;
        // (16 + 1) is odd, so src[bg_idx] was 0, but blurred with neighbors it becomes > 50
        assert!(
            out[bg_idx] > 50,
            "Background must be blurred: expected > 50, got {}",
            out[bg_idx]
        );
    }

    #[test]
    fn adaptive_kernel_12_samples_has_fewer_entries_than_36() {
        let kernel_12 = build_bokeh_kernel(BokehShape::Circle, 12);
        let kernel_36 = build_bokeh_kernel(BokehShape::Circle, 36);
        // 12 samples + center = 13 max; 36 samples + center = 37 max
        assert!(
            kernel_12.len() <= 13,
            "12-sample kernel too large: {}",
            kernel_12.len()
        );
        assert!(
            kernel_36.len() <= 37,
            "36-sample kernel too large: {}",
            kernel_36.len()
        );
        assert!(
            kernel_12.len() < kernel_36.len(),
            "12-sample kernel ({}) must be smaller than 36-sample ({})",
            kernel_12.len(),
            kernel_36.len()
        );
    }

    #[test]
    fn neutral_blur_ignores_sample_count() {
        let src = vec![128u8; 16 * 16 * 4];
        let out_12 = apply_lens_blur(&src, 16, 16, LensBlurParams::default(), None);
        let out_36 = apply_lens_blur(&src, 16, 16, LensBlurParams::default(), None);
        assert_eq!(out_12, src);
        assert_eq!(out_36, src);
        assert_eq!(out_12, out_36);
    }

    #[test]
    fn rayon_parallel_blur_matches_sequential() {
        let (w, h) = (32, 32);
        let mut src = vec![0u8; w * h * 4];
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                let v = if (x + y) % 2 == 0 { 255 } else { 0 };
                src[idx] = v;
                src[idx + 1] = v;
                src[idx + 2] = v;
                src[idx + 3] = 255;
            }
        }
        let depth_map = vec![1.0f32; w * h];
        let params = LensBlurParams {
            enabled: true,
            amount: 0.8,
            focal_point: 0.5,
            focal_range: 0.1,
            bokeh_shape: BokehShape::Circle,
            bokeh_boost: 0.0,
            background_blur: false,
            sample_count: 36,
        };

        let default_run = apply_lens_blur(&src, w, h, params, Some(&depth_map));

        // Run with a single-threaded rayon pool to verify determinism and absence of race conditions
        let pool = rayon::ThreadPoolBuilder::new()
            .num_threads(1)
            .build()
            .unwrap();
        let single_thread_run =
            pool.install(|| apply_lens_blur(&src, w, h, params, Some(&depth_map)));

        assert_eq!(
            default_run, single_thread_run,
            "parallel blur must match single-threaded blur deterministically"
        );
    }

    #[test]
    fn test_thin_lens_optical_coc_behavior() {
        let focal_point = 0.50;
        let focal_range = 0.10; // in focus between 0.45 and 0.55
        let amount = 0.80;

        // Inside focal zone: must be 0.0 (sharp)
        assert_eq!(
            circle_of_confusion(0.50, focal_point, focal_range, amount),
            0.0
        );
        assert_eq!(
            circle_of_confusion(0.48, focal_point, focal_range, amount),
            0.0
        );
        assert_eq!(
            circle_of_confusion(0.52, focal_point, focal_range, amount),
            0.0
        );

        // Outside focal zone: CoC strictly positive
        let near_coc = circle_of_confusion(0.10, focal_point, focal_range, amount);
        let far_coc = circle_of_confusion(0.90, focal_point, focal_range, amount);
        assert!(near_coc > 0.0, "Near CoC must be positive");
        assert!(far_coc > 0.0, "Far CoC must be positive");

        // Zero amount produces zero CoC
        assert_eq!(
            circle_of_confusion(0.10, focal_point, focal_range, 0.0),
            0.0
        );

        // Monotonic transition outside focal zone
        let mut prev_coc = 0.0;
        for step in 1..10 {
            let d = 0.55 + (step as f32) * 0.03;
            let coc = circle_of_confusion(d, focal_point, focal_range, amount);
            assert!(
                coc >= prev_coc,
                "CoC must increase monotonically with defocus distance: at d={}, coc={}, prev={}",
                d,
                coc,
                prev_coc
            );
            prev_coc = coc;
        }
    }

    #[test]
    fn test_optical_bokeh_shapes_kernel_synthesis() {
        let shapes = [
            BokehShape::Circle,
            BokehShape::Pentagon,
            BokehShape::Hexagon,
            BokehShape::Septagon,
            BokehShape::CatsEye,
            BokehShape::SoapBubble,
            BokehShape::Swirl,
        ];

        for shape in shapes {
            let kernel = build_bokeh_kernel(shape, 36);
            assert!(
                !kernel.is_empty(),
                "Kernel for shape {:?} must not be empty",
                shape
            );
            assert!(
                kernel.len() <= 37,
                "Kernel for shape {:?} exceeded max 37 samples",
                shape
            );
            for s in &kernel {
                assert!(s.weight > 0.0, "Sample weight must be positive");
                let dist = (s.dx * s.dx + s.dy * s.dy).sqrt();
                assert!(
                    dist <= 1.05,
                    "Sample offset exceeded normalized aperture bounds"
                );
            }
        }

        // Soap bubble bokeh specific property: outer perimeter is brighter than center
        let bubble_kernel = build_bokeh_kernel(BokehShape::SoapBubble, 36);
        let center_sample = bubble_kernel[0];
        let outer_sample = bubble_kernel
            .iter()
            .max_by(|a, b| {
                let da = a.dx * a.dx + a.dy * a.dy;
                let db = b.dx * b.dx + b.dy * b.dy;
                da.partial_cmp(&db).unwrap()
            })
            .unwrap();

        assert!(
            outer_sample.weight > center_sample.weight,
            "Soap bubble outer ring ({}) must be brighter than center ({})",
            outer_sample.weight,
            center_sample.weight
        );
    }

    #[test]
    fn test_swirl_kernel_distinct_from_cats_eye() {
        let cats_eye = build_bokeh_kernel(BokehShape::CatsEye, 36);
        let swirl = build_bokeh_kernel(BokehShape::Swirl, 36);
        assert_eq!(cats_eye.len(), swirl.len());
        let mut diff_count = 0;
        for (c, s) in cats_eye.iter().zip(swirl.iter()) {
            if (c.dx - s.dx).abs() > 1e-4 || (c.dy - s.dy).abs() > 1e-4 {
                diff_count += 1;
            }
        }
        assert!(
            diff_count > 0,
            "Swirl bokeh kernel must have distinct sample offsets from Cat's Eye"
        );
    }

    #[test]
    fn test_hexagon_kernel_has_non_circular_aperture_profile() {
        let kernel = build_bokeh_kernel(BokehShape::Hexagon, 64);
        let mut max_r_near_midpoint = 0.0f32;
        let segment = std::f32::consts::TAU / 6.0;
        for s in &kernel {
            let theta = s.dy.atan2(s.dx);
            let alpha = (theta % segment + segment) % segment - (segment * 0.5);
            let r = (s.dx * s.dx + s.dy * s.dy).sqrt();
            if alpha.abs() < 0.08 && r > max_r_near_midpoint {
                max_r_near_midpoint = r;
            }
        }
        // At edge midpoint alpha ≈ 0, theoretical limit is cos(pi/6) ≈ 0.866. It should not reach 0.98+ (unit circle).
        assert!(
            max_r_near_midpoint <= 0.92,
            "Hexagon edge midpoint sample reached circle boundary: got {}",
            max_r_near_midpoint
        );
    }

    #[test]
    fn test_background_blur_keeps_subject_at_focal_point_sharp() {
        let (w, h) = (16, 16);
        let mut src = vec![0u8; w * h * 4];
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                let v = if (x + y) % 2 == 0 { 255 } else { 0 };
                src[idx] = v;
                src[idx + 1] = v;
                src[idx + 2] = v;
                src[idx + 3] = 255;
            }
        }

        // Subject at depth 0.30, background at depth 0.90
        let mut depth_map = vec![0.90f32; w * h];
        for y in 6..10 {
            for x in 6..10 {
                depth_map[y * w + x] = 0.30;
            }
        }

        let params = LensBlurParams {
            enabled: true,
            amount: 0.8,
            focal_point: 0.30,
            focal_range: 0.10,
            bokeh_shape: BokehShape::Circle,
            bokeh_boost: 0.0,
            background_blur: true,
            sample_count: 36,
        };

        let out = apply_lens_blur(&src, w, h, params, Some(&depth_map));
        let subject_idx = (8 * w + 8) * 4;
        assert_eq!(
            out[subject_idx], src[subject_idx],
            "Subject at focal point must remain sharp when background_blur is true"
        );
    }

    #[test]
    fn test_generate_depth_visualizer_rgba() {
        let (w, h) = (3, 1);
        // 3 pixels: near (0.0), in-focus (0.5), far (1.0)
        let depth = vec![0.0, 0.5, 1.0];
        let visualizer = generate_depth_visualizer_rgba(&depth, w, h, 0.5, 0.1);
        assert_eq!(visualizer.len(), 3 * 4);

        // Pixel 0 (Near, 0.0): Warm Amber (RGB 255, 179, 0)
        let p0 = &visualizer[0..4];
        assert_eq!(p0[0], 255, "Warm Amber red");
        assert_eq!(p0[1], 179, "Warm Amber green");
        assert_eq!(p0[2], 0, "Warm Amber blue");
        assert_eq!(p0[3], 255, "Opaque alpha");

        // Pixel 1 (Focus plane, 0.5): Neutral (RGB 180, 180, 180)
        let p1 = &visualizer[4..8];
        assert_eq!(p1[0], 180, "Neutral red");
        assert_eq!(p1[1], 180, "Neutral green");
        assert_eq!(p1[2], 180, "Neutral blue");
        assert_eq!(p1[3], 255, "Opaque alpha");

        // Pixel 2 (Far, 1.0): Cool Teal (RGB 0, 180, 200)
        let p2 = &visualizer[8..12];
        assert_eq!(p2[0], 0, "Cool Teal red");
        assert_eq!(p2[1], 180, "Cool Teal green");
        assert_eq!(p2[2], 200, "Cool Teal blue");
        assert_eq!(p2[3], 255, "Opaque alpha");
    }

    #[test]
    fn test_bokeh_shape_index_roundtrip() {
        for i in 0..7u8 {
            let shape = BokehShape::from_index(i);
            assert_eq!(shape.to_index(), i);
        }
        assert_eq!(BokehShape::Circle.to_index(), 0);
        assert_eq!(BokehShape::Pentagon.to_index(), 1);
        assert_eq!(BokehShape::Hexagon.to_index(), 2);
        assert_eq!(BokehShape::Septagon.to_index(), 3);
        assert_eq!(BokehShape::CatsEye.to_index(), 4);
        assert_eq!(BokehShape::SoapBubble.to_index(), 5);
        assert_eq!(BokehShape::Swirl.to_index(), 6);
    }

    #[test]
    fn test_occlusion_aware_gather_prevents_background_leak_onto_foreground() {
        let (w, h) = (16, 16);
        let mut src = vec![0u8; w * h * 4];
        let mut depth_map = vec![0.0f32; w * h];

        // Left half (x < 8): sharp foreground subject at depth 0.2, pure red (255, 0, 0)
        // Right half (x >= 8): distant background at depth 1.0, pure green (0, 255, 0)
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                if x < 8 {
                    src[idx] = 255;
                    src[idx + 3] = 255;
                    depth_map[y * w + x] = 0.2;
                } else {
                    src[idx + 1] = 255;
                    src[idx + 3] = 255;
                    depth_map[y * w + x] = 1.0;
                }
            }
        }

        let params = LensBlurParams {
            enabled: true,
            amount: 0.9,
            focal_point: 0.2,
            focal_range: 0.05,
            bokeh_shape: BokehShape::Circle,
            bokeh_boost: 0.0,
            background_blur: false,
            sample_count: 36,
        };

        let out = apply_lens_blur(&src, w, h, params, Some(&depth_map));

        // Pixel at (6, 8) is on the foreground subject: should remain pure red with zero green leak
        let fg_idx = (8 * w + 6) * 4;
        assert_eq!(out[fg_idx], 255, "Foreground subject retains red channel");
        assert_eq!(
            out[fg_idx + 1],
            0,
            "Foreground subject has zero green background leak"
        );
    }

    #[test]
    fn test_sensor_noise_reinjection_eliminates_plastic_flatness() {
        let (w, h) = (32, 32);
        // Subtle dithered midtone checkerboard
        let mut src = vec![128u8; w * h * 4];
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                let v = if (x + y) % 2 == 0 { 129 } else { 128 };
                src[idx] = v;
                src[idx + 1] = v;
                src[idx + 2] = v;
            }
        }
        // Background depth 1.0, focal point 0.0 -> out of focus
        let depth_map = vec![1.0f32; w * h];

        let params = LensBlurParams {
            enabled: true,
            amount: 0.9,
            focal_point: 0.0,
            focal_range: 0.1,
            bokeh_shape: BokehShape::Circle,
            bokeh_boost: 0.0,
            background_blur: false,
            sample_count: 36,
        };

        let out = apply_lens_blur(&src, w, h, params, Some(&depth_map));

        // Because of sensor noise reinjection, adjacent blurred pixels will have subtle
        // non-zero micro-variation rather than being 100% identical constant integers.
        let mut has_micro_variation = false;
        for i in 0..(w * h - 1) {
            if out[i * 4] != out[(i + 1) * 4] {
                has_micro_variation = true;
                break;
            }
        }
        assert!(
            has_micro_variation,
            "Sensor noise reinjection should introduce realistic micro-variation"
        );
    }

    #[test]
    fn test_depth_map_length_mismatch_aborts_without_blur() {
        let (w, h) = (16, 16);
        let src = vec![200u8; w * h * 4];
        let invalid_depth = vec![0.0f32; 10]; // length mismatch

        let params = LensBlurParams {
            enabled: true,
            amount: 0.8,
            focal_point: 0.0,
            focal_range: 0.1,
            bokeh_shape: BokehShape::Circle,
            bokeh_boost: 0.0,
            background_blur: false,
            sample_count: 12,
        };

        let out = apply_lens_blur(&src, w, h, params, Some(&invalid_depth));
        assert_eq!(
            out, src,
            "Mismatch in depth map length must abort blur and return untouched input"
        );
    }

    #[test]
    fn test_synthetic_depth_map_planar_perspective() {
        let (w, h) = (32, 32);
        let depth = generate_synthetic_depth_map(w, h, 0.45);
        assert_eq!(depth.len(), w * h);
        let top_depth = depth[w / 2];
        let bottom_depth = depth[(h - 1) * w + w / 2];
        assert!(
            top_depth > bottom_depth,
            "Top row must be farther than bottom row in planar perspective: top={}, bottom={}",
            top_depth,
            bottom_depth
        );
        let mid_depth = depth[(h / 2) * w + w / 2];
        assert!(
            (mid_depth - 0.45).abs() < 0.15,
            "Midfield depth should match focal point: {}",
            mid_depth
        );
    }

    #[test]
    fn test_fuse_face_depth_plateau_flattens_facial_depth() {
        let (w, h) = (32, 32);
        let mut depth_map = vec![0.5f32; w * h];
        // Create an outlier at face nose/eye
        depth_map[16 * w + 16] = 0.2f32;

        let face = crate::api::mask::DetectedFace {
            x: 0.3,
            y: 0.3,
            w: 0.4,
            h: 0.4,
            score: 0.99,
            landmarks: Vec::new(),
            cx: 0.5,
            cy: 0.5,
            rx: 0.2,
            ry: 0.2,
        };

        fuse_face_depth_plateau(&mut depth_map, w, h, &[face]);

        // Center pixel should be blended towards median (0.5), reducing variation
        let center_d = depth_map[16 * w + 16];
        assert!(
            (center_d - 0.5).abs() < 0.15,
            "Face center depth should be plateaued towards median: {}",
            center_d
        );
    }

    #[test]
    fn test_confidence_gating_skips_textureless_blur() {
        let (w, h) = (16, 16);
        let src = vec![128u8; w * h * 4]; // perfectly uniform gray
        let params = LensBlurParams {
            enabled: true,
            amount: 0.8,
            focal_point: 0.0,
            focal_range: 0.1,
            bokeh_shape: BokehShape::Circle,
            bokeh_boost: 0.0,
            background_blur: false,
            sample_count: 12,
        };

        let out = apply_lens_blur(&src, w, h, params, None);
        assert_eq!(
            out, src,
            "Uniform textureless scene without depth map must be gated by confidence"
        );
    }

    #[test]
    fn test_occlusion_aware_foreground_bleeds_over_sharp_subject() {
        let (w, h) = (32, 32);
        let mut src = vec![0u8; w * h * 4];
        let mut depth_map = vec![0.5f32; w * h];

        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                if x < 12 {
                    // Out-of-focus foreground object: blue (0, 0, 255) at depth 0.1
                    src[idx + 2] = 255;
                    src[idx + 3] = 255;
                    depth_map[y * w + x] = 0.1;
                } else {
                    // Sharp in-focus subject: red (255, 0, 0) at depth 0.5
                    src[idx] = 255;
                    src[idx + 3] = 255;
                    depth_map[y * w + x] = 0.5;
                }
            }
        }

        let params = LensBlurParams {
            enabled: true,
            amount: 0.8,
            focal_point: 0.5,
            focal_range: 0.1,
            bokeh_shape: BokehShape::Circle,
            bokeh_boost: 0.0,
            background_blur: false,
            sample_count: 36,
        };

        let out = apply_lens_blur(&src, w, h, params, Some(&depth_map));

        // Pixel at x=12 is on the sharp in-focus subject immediately adjacent to the out-of-focus blue foreground.
        // Occlusion-aware gather ensures the blurred foreground bleeds over the sharp subject boundary.
        let bleed_idx = (16 * w + 12) * 4;
        assert!(
            out[bleed_idx + 2] > 0,
            "Foreground blue bokeh must bleed onto adjacent sharp subject (got blue={})",
            out[bleed_idx + 2]
        );
    }

    #[test]
    fn test_preview_vs_export_resolution_invariance_psnr() {
        // High-res export (64x64) vs Low-res preview (32x32)
        let (ew, eh) = (64, 64);
        let mut export_src = vec![0u8; ew * eh * 4];
        let mut export_depth = vec![0.0f32; ew * eh];

        for y in 0..eh {
            for x in 0..ew {
                let idx = (y * ew + x) * 4;
                // Smooth photo gradient
                let v = ((x as f32 / ew as f32 * 180.0) + (y as f32 / eh as f32 * 60.0)) as u8;
                export_src[idx] = v;
                export_src[idx + 1] = 255 - v;
                export_src[idx + 2] = v / 2;
                export_src[idx + 3] = 255;
                export_depth[y * ew + x] = (x as f32 / ew as f32).clamp(0.0, 1.0);
            }
        }

        let (pw, ph) = (32, 32);
        let mut preview_src = vec![0u8; pw * ph * 4];
        let mut preview_depth = vec![0.0f32; pw * ph];
        for y in 0..ph {
            for x in 0..pw {
                let p_idx = (y * pw + x) * 4;
                // 2x2 box average downsample for preview proxy
                let e00 = ((y * 2) * ew + (x * 2)) * 4;
                let e10 = ((y * 2) * ew + (x * 2 + 1)) * 4;
                let e01 = ((y * 2 + 1) * ew + (x * 2)) * 4;
                let e11 = ((y * 2 + 1) * ew + (x * 2 + 1)) * 4;
                for c in 0..4 {
                    preview_src[p_idx + c] = ((export_src[e00 + c] as u16
                        + export_src[e10 + c] as u16
                        + export_src[e01 + c] as u16
                        + export_src[e11 + c] as u16)
                        / 4) as u8;
                }
                preview_depth[y * pw + x] = (export_depth[(y * 2) * ew + (x * 2)]
                    + export_depth[(y * 2) * ew + (x * 2 + 1)]
                    + export_depth[(y * 2 + 1) * ew + (x * 2)]
                    + export_depth[(y * 2 + 1) * ew + (x * 2 + 1)])
                    * 0.25;
            }
        }

        let params = LensBlurParams {
            enabled: true,
            amount: 0.6,
            focal_point: 0.5,
            focal_range: 0.2,
            bokeh_shape: BokehShape::Circle,
            bokeh_boost: 0.0,
            background_blur: false,
            sample_count: 36,
        };

        let export_out = apply_lens_blur(&export_src, ew, eh, params, Some(&export_depth));
        let preview_out = apply_lens_blur(&preview_src, pw, ph, params, Some(&preview_depth));

        // 2x2 box average downscale export output to preview size to compute PSNR
        let mut mse = 0.0f64;
        let mut count = 0usize;
        for y in 0..ph {
            for x in 0..pw {
                let p_idx = (y * pw + x) * 4;
                let e00 = ((y * 2) * ew + (x * 2)) * 4;
                let e10 = ((y * 2) * ew + (x * 2 + 1)) * 4;
                let e01 = ((y * 2 + 1) * ew + (x * 2)) * 4;
                let e11 = ((y * 2 + 1) * ew + (x * 2 + 1)) * 4;
                for c in 0..3 {
                    let downscaled_export = (export_out[e00 + c] as f64
                        + export_out[e10 + c] as f64
                        + export_out[e01 + c] as f64
                        + export_out[e11 + c] as f64)
                        / 4.0;
                    let diff = downscaled_export - preview_out[p_idx + c] as f64;
                    mse += diff * diff;
                    count += 1;
                }
            }
        }
        mse /= count as f64;
        let psnr = if mse > 0.0 {
            10.0 * (255.0 * 255.0 / mse).log10()
        } else {
            99.0
        };

        assert!(
            psnr >= 38.0,
            "Preview vs Export resolution invariance PSNR must be >= 38.0 dB (got {:.2} dB)",
            psnr
        );
    }
}
