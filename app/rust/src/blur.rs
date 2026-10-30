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
}

impl BokehShape {
    /// Bridge-facing index (`0..4`, matching the Dart `BokehShape` enum order).
    pub fn from_index(index: u8) -> Self {
        match index {
            0 => BokehShape::Circle,
            1 => BokehShape::Pentagon,
            2 => BokehShape::Hexagon,
            3 => BokehShape::Septagon,
            _ => BokehShape::Swirl,
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
        }
    }
}

impl LensBlurParams {
    pub fn is_neutral(&self) -> bool {
        !self.enabled || (self.amount <= 1e-4 && !self.background_blur)
    }

    /// Builds params from the flat bridge fields shared by
    /// `PreviewBaseSpec` (preview bake) and `ExportSpec` (export pipeline).
    pub fn from_fields(
        enabled: bool,
        amount: f32,
        focal_point: f32,
        focal_range: f32,
        bokeh_shape: u8,
        bokeh_boost: f32,
        background_blur: bool,
    ) -> Self {
        Self {
            enabled,
            amount,
            focal_point,
            focal_range,
            bokeh_shape: BokehShape::from_index(bokeh_shape),
            bokeh_boost,
            background_blur,
        }
    }
}

/// Computes the Circle of Confusion (CoC) radius `0..1` for a given pixel depth.
#[inline(always)]
pub fn circle_of_confusion(depth: f32, focal_point: f32, focal_range: f32, amount: f32) -> f32 {
    let diff = (depth - focal_point).abs();
    let half_range = (focal_range * 0.5).max(1e-4);
    if diff <= half_range {
        0.0
    } else {
        let t = ((diff - half_range) / (1.0 - half_range).max(1e-4)).clamp(0.0, 1.0);
        t * amount
    }
}

/// Evaluates aperture blade distance threshold at polar angle `theta`.
#[inline(always)]
fn aperture_radius_limit(theta: f32, shape: BokehShape) -> f32 {
    match shape {
        BokehShape::Circle => 1.0,
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
        BokehShape::Swirl => {
            // Anamorphic/Petzval swirl: elliptical compression with radial twist
            1.0 + 0.25 * (2.0 * theta).sin()
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
    samples.push(BokehSample {
        dx: 0.0,
        dy: 0.0,
        weight: 1.0,
    });
    // Golden angle spiral distribution
    for i in 0..n {
        let theta = i as f32 * 2.399_963_1; // tau * (1 - 1/phi)
        let r = ((i as f32 + 0.5) / n as f32).sqrt();
        let limit = aperture_radius_limit(theta, shape);
        if r <= limit {
            let norm_r = r / limit;
            let sample_dx = norm_r * theta.cos();
            let sample_dy = norm_r * theta.sin();
            let weight = 1.0 - norm_r * norm_r * 0.3;
            samples.push(BokehSample {
                dx: sample_dx,
                dy: sample_dy,
                weight,
            });
        }
    }
    samples
}

fn generate_synthetic_depth_map(w: usize, h: usize) -> Vec<f32> {
    let mut depth = Vec::with_capacity(w * h);
    let inv_h = 1.0 / (h - 1).max(1) as f32;
    let inv_w = 1.0 / (w - 1).max(1) as f32;
    for y in 0..h {
        let py = y as f32 * inv_h; // 0.0 at top, 1.0 at bottom
        let dy = py - 0.45; // Portrait subject optical center
        for x in 0..w {
            let px = x as f32 * inv_w; // 0.0 at left, 1.0 at right
            let dx = px - 0.5;
            let dist_from_subject = (dx * dx * 1.5 + dy * dy).sqrt();

            // Portrait subject in focus zone (depth ~ 0.50):
            let subject_weight = (1.0 - (dist_from_subject / 0.35).clamp(0.0, 1.0)).powi(2);

            // Background perspective: top and distant perimeter are far (depth 0.85 .. 1.0),
            // bottom is close foreground (depth 0.15 .. 0.25).
            let bg_depth = (1.0 - 0.80 * py + 0.25 * dx.abs()).clamp(0.15, 1.0);

            let d = ((1.0 - subject_weight) * bg_depth + subject_weight * 0.50).clamp(0.0, 1.0);
            depth.push(d);
        }
    }
    depth
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
    sample_count: usize,
) -> Vec<u8> {
    if params.is_neutral() || w <= 1 || h <= 1 {
        return rgba.to_vec();
    }

    let min_dim = w.min(h) as f32;
    // Power curve: low amounts stay subtle, 100% gives a creamy DSLR blur.
    // Max radius raised from 24 to 60 for a true shallow-depth-of-field look.
    let max_radius = (params.amount.powf(2.0) * min_dim * 0.12).clamp(1.0, 60.0);
    let mut out = vec![0u8; w * h * 4];

    // Precalculate depth buffer (either from provided map or optical perspective gradient)
    let depth_buffer: Vec<f32> = if params.background_blur {
        // Background blur: subject stays sharp (depth 0), background blurs (depth 1).
        // Invert any provided subject mask; fall back to synthetic gradient.
        if let Some(dm) = depth_map {
            if dm.len() == w * h {
                dm.iter().map(|d| 1.0 - d.clamp(0.0, 1.0)).collect()
            } else {
                generate_synthetic_depth_map(w, h)
            }
        } else {
            generate_synthetic_depth_map(w, h)
        }
    } else if let Some(dm) = depth_map {
        if dm.len() == w * h {
            dm.iter().map(|d| d.clamp(0.0, 1.0)).collect()
        } else {
            generate_synthetic_depth_map(w, h)
        }
    } else {
        generate_synthetic_depth_map(w, h)
    };

    let kernel = build_bokeh_kernel(params.bokeh_shape, sample_count);

    out.par_chunks_exact_mut(w * 4)
        .enumerate()
        .for_each(|(y, row)| {
            for x in 0..w {
                let idx = x * 4;
                let src_idx = (y * w + x) * 4;
                let pixel_depth = depth_buffer[y * w + x];
                let coc = circle_of_confusion(
                    pixel_depth,
                    params.focal_point,
                    params.focal_range,
                    params.amount,
                );

                // In sharp focal plane: copy pixel intact
                if coc <= 1e-3 {
                    row[idx..idx + 4].copy_from_slice(&rgba[src_idx..src_idx + 4]);
                    continue;
                }

                let kernel_r = (coc * max_radius).max(1.0);
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
                    let depth_weight = if sample_depth < pixel_depth - 0.15 {
                        0.1 // de-weight foreground bleeding onto background
                    } else {
                        1.0
                    };

                    let s_idx = (s_y * w + s_x) * 4;
                    let mut sr = rgba[s_idx] as f32;
                    let mut sg = rgba[s_idx + 1] as f32;
                    let mut sb = rgba[s_idx + 2] as f32;

                    // Specular highlight boost: amplify bright out-of-focus spots
                    if params.bokeh_boost > 0.0 {
                        let luma = 0.2126 * sr + 0.7152 * sg + 0.0722 * sb;
                        if luma > 180.0 {
                            let boost = 1.0 + params.bokeh_boost * ((luma - 180.0) / 75.0);
                            sr *= boost;
                            sg *= boost;
                            sb *= boost;
                        }
                    }

                    let w_val = depth_weight * sample.weight;
                    r_acc += sr * w_val;
                    g_acc += sg * w_val;
                    b_acc += sb * w_val;
                    weight_acc += w_val;
                }

                if weight_acc > 0.0 {
                    row[idx] = (r_acc / weight_acc).round().clamp(0.0, 255.0) as u8;
                    row[idx + 1] = (g_acc / weight_acc).round().clamp(0.0, 255.0) as u8;
                    row[idx + 2] = (b_acc / weight_acc).round().clamp(0.0, 255.0) as u8;
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
        let out = apply_lens_blur(&src, 16, 16, LensBlurParams::default(), None, 36);
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
        };

        let out = apply_lens_blur(&src, w, h, params, Some(&depth_map), 36);

        // In-focus left side (x=2, y=2): should retain high contrast checkerboard
        let in_focus_idx = (2 * w + 2) * 4;
        assert_eq!(out[in_focus_idx], src[in_focus_idx]);

        // Out-of-focus right side (x=12, y=12): checkerboard (initially 255) should be heavily blurred away from 255
        let out_focus_idx = (12 * w + 12) * 4;
        assert!(
            out[out_focus_idx] < 150,
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
        };
        let out_normal = apply_lens_blur(&src, w, h, base_params, Some(&depth_map), 36);

        let boosted_params = LensBlurParams {
            bokeh_boost: 1.0,
            ..base_params
        };
        let out_boosted = apply_lens_blur(&src, w, h, boosted_params, Some(&depth_map), 36);

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
        };

        // None passed for depth_map -> uses optical synthetic perspective
        let out = apply_lens_blur(&src, w, h, params, None, 36);

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
        let out_12 = apply_lens_blur(&src, 16, 16, LensBlurParams::default(), None, 12);
        let out_36 = apply_lens_blur(&src, 16, 16, LensBlurParams::default(), None, 36);
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
        };

        let seq = apply_lens_blur(&src, w, h, params, Some(&depth_map), 36);

        // Parallel version: split rows into chunks and process each in parallel
        let mut out = vec![0u8; w * h * 4];
        let depth_buffer = depth_map;
        let kernel = build_bokeh_kernel(params.bokeh_shape, 36);
        let num_threads = std::thread::available_parallelism()
            .map(|n| n.get())
            .unwrap_or(4)
            .clamp(1, 8);
        let rows_per_chunk = h.div_ceil(num_threads);

        out.par_chunks_mut(rows_per_chunk * w * 4)
            .enumerate()
            .for_each(|(chunk_idx, out_chunk)| {
                let start_y = chunk_idx * rows_per_chunk;
                let end_y = (start_y + rows_per_chunk).min(h);
                for y in start_y..end_y {
                    let chunk_y = y - start_y;
                    for x in 0..w {
                        let idx = (chunk_y * w + x) * 4;
                        let src_idx = (y * w + x) * 4;
                        let pixel_depth = depth_buffer[y * w + x];
                        let coc = circle_of_confusion(
                            pixel_depth,
                            params.focal_point,
                            params.focal_range,
                            params.amount,
                        );

                        if coc <= 1e-3 {
                            out_chunk[idx..idx + 4].copy_from_slice(&src[src_idx..src_idx + 4]);
                            continue;
                        }

                        let kernel_r = (coc
                            * (params.amount * w.min(h) as f32 * 0.08).clamp(1.0, 24.0))
                        .max(1.0);
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
                            let depth_weight = if sample_depth < pixel_depth - 0.15 {
                                0.1
                            } else {
                                1.0
                            };

                            let s_idx = (s_y * w + s_x) * 4;
                            let mut sr = src[s_idx] as f32;
                            let mut sg = src[s_idx + 1] as f32;
                            let mut sb = src[s_idx + 2] as f32;

                            if params.bokeh_boost > 0.0 {
                                let luma = 0.2126 * sr + 0.7152 * sg + 0.0722 * sb;
                                if luma > 180.0 {
                                    let boost = 1.0 + params.bokeh_boost * ((luma - 180.0) / 75.0);
                                    sr *= boost;
                                    sg *= boost;
                                    sb *= boost;
                                }
                            }

                            let w_val = depth_weight * sample.weight;
                            r_acc += sr * w_val;
                            g_acc += sg * w_val;
                            b_acc += sb * w_val;
                            weight_acc += w_val;
                        }

                        if weight_acc > 0.0 {
                            out_chunk[idx] = (r_acc / weight_acc).round().clamp(0.0, 255.0) as u8;
                            out_chunk[idx + 1] =
                                (g_acc / weight_acc).round().clamp(0.0, 255.0) as u8;
                            out_chunk[idx + 2] =
                                (b_acc / weight_acc).round().clamp(0.0, 255.0) as u8;
                            out_chunk[idx + 3] = src[src_idx + 3];
                        } else {
                            out_chunk[idx..idx + 4].copy_from_slice(&src[src_idx..src_idx + 4]);
                        }
                    }
                }
            });

        assert_eq!(out, seq, "parallel blur must match sequential blur");
    }
}
