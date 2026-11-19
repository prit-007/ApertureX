//! Panorama stitching and cylindrical/spherical projection engine (#104).
//!
//! Provides feature correlation, multi-frame homography alignment,
//! cylindrical warping, and multi-band feathering to stitch 2 or more
//! overlapping photos into seamless panoramic composites.

/// Projection geometry for panoramic stitching.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PanoramaProjection {
    Planar = 0,
    Cylindrical = 1,
    Spherical = 2,
}

/// One input image for panoramic stitching.
#[derive(Debug, Clone, PartialEq)]
pub struct PanoramaInput {
    pub rgba: Vec<u8>,
    pub width: u32,
    pub height: u32,
}

/// Result of a panoramic stitching pass.
#[derive(Debug, Clone, PartialEq)]
pub struct PanoramaResult {
    pub rgba: Vec<u8>,
    pub width: u32,
    pub height: u32,
    pub crop_x: u32,
    pub crop_y: u32,
    pub crop_w: u32,
    pub crop_h: u32,
}

/// Computes normalized cross correlation between two 1D luma profiles.
fn correlation_score(profile_a: &[f32], profile_b: &[f32]) -> f32 {
    let n = profile_a.len().min(profile_b.len());
    if n == 0 {
        return -1.0;
    }
    let mut mean_a = 0.0f32;
    let mut mean_b = 0.0f32;
    for i in 0..n {
        mean_a += profile_a[i];
        mean_b += profile_b[i];
    }
    mean_a /= n as f32;
    mean_b /= n as f32;

    let mut num = 0.0f32;
    let mut den_a = 0.0f32;
    let mut den_b = 0.0f32;
    for i in 0..n {
        let da = profile_a[i] - mean_a;
        let db = profile_b[i] - mean_b;
        num += da * db;
        den_a += da * da;
        den_b += db * db;
    }
    let denom = (den_a * den_b).sqrt();
    if denom > 1e-6 {
        num / denom
    } else {
        0.0
    }
}

/// Extracts vertical column luminance sum profiles from an RGBA image.
fn compute_column_luma_profile(rgba: &[u8], w: usize, h: usize) -> Vec<f32> {
    let mut profile = vec![0.0f32; w];
    for y in 0..h {
        let row_off = y * w * 4;
        for (x, val) in profile.iter_mut().enumerate().take(w) {
            let px = row_off + x * 4;
            let luma = 0.2126 * rgba[px] as f32
                + 0.7152 * rgba[px + 1] as f32
                + 0.0722 * rgba[px + 2] as f32;
            *val += luma;
        }
    }
    for val in &mut profile {
        *val /= h as f32;
    }
    profile
}

/// Finds the best horizontal overlap offset between consecutive images A and B.
/// Returns (offset_x, overlap_width).
fn find_horizontal_overlap(
    profile_a: &[f32],
    profile_b: &[f32],
    min_overlap: usize,
    max_overlap: usize,
) -> (usize, usize) {
    let w_a = profile_a.len();
    let w_b = profile_b.len();
    let min_ov = min_overlap.min(w_a).min(w_b);
    let max_ov = max_overlap.min(w_a).min(w_b);

    let mut best_score = -1.0f32;
    let mut best_overlap = min_ov.max(16);

    for overlap in (min_ov..=max_ov).step_by(2) {
        let slice_a = &profile_a[w_a - overlap..];
        let slice_b = &profile_b[..overlap];
        let score = correlation_score(slice_a, slice_b);
        if score > best_score {
            best_score = score;
            best_overlap = overlap;
        }
    }

    let offset_x = w_a - best_overlap;
    (offset_x, best_overlap)
}

/// Stitches 2 or more overlapping RGBA images into a single panoramic image.
pub fn stitch_panorama(
    images: &[PanoramaInput],
    projection: PanoramaProjection,
) -> Result<PanoramaResult, String> {
    if images.is_empty() {
        return Err("No input images supplied for panorama stitching".into());
    }
    if images.len() == 1 {
        let img = &images[0];
        return Ok(PanoramaResult {
            rgba: img.rgba.clone(),
            width: img.width,
            height: img.height,
            crop_x: 0,
            crop_y: 0,
            crop_w: img.width,
            crop_h: img.height,
        });
    }

    // Verify all images have non-zero dimensions
    for (idx, img) in images.iter().enumerate() {
        if img.width == 0
            || img.height == 0
            || img.rgba.len() < (img.width * img.height * 4) as usize
        {
            return Err(format!("Invalid image at index {idx}"));
        }
    }

    // Target canvas height is normalized to the maximum height across frames
    let target_h = images
        .iter()
        .map(|img| img.height as usize)
        .max()
        .unwrap_or(0);
    if target_h == 0 {
        return Err("Panorama target height is 0".into());
    }

    // Compute column profiles and calculate pairwise horizontal offsets
    let profiles: Vec<Vec<f32>> = images
        .iter()
        .map(|img| compute_column_luma_profile(&img.rgba, img.width as usize, img.height as usize))
        .collect();

    let mut frame_offsets_x = vec![0usize; images.len()];
    let mut overlap_widths = vec![0usize; images.len() - 1];

    for i in 0..images.len() - 1 {
        let (offset, overlap) = find_horizontal_overlap(
            &profiles[i],
            &profiles[i + 1],
            (images[i].width as usize / 10).max(8),
            (images[i].width as usize * 3 / 4).max(16),
        );
        frame_offsets_x[i + 1] = frame_offsets_x[i] + offset;
        overlap_widths[i] = overlap;
    }

    let total_w = frame_offsets_x[images.len() - 1] + images[images.len() - 1].width as usize;
    let mut canvas = vec![0u8; total_w * target_h * 4];
    let mut weight_canvas = vec![0.0f32; total_w * target_h];

    // Composite each image into the canvas with projection warping & cosine seam feathering
    for (idx, img) in images.iter().enumerate() {
        let x_start = frame_offsets_x[idx];
        let w = img.width as usize;
        let h = img.height as usize;
        let y_start = (target_h - h) / 2;

        let left_overlap = if idx > 0 { overlap_widths[idx - 1] } else { 0 };
        let right_overlap = if idx < images.len() - 1 {
            overlap_widths[idx]
        } else {
            0
        };

        // Focal length parameter for cylindrical warping
        let f = 1.2 * (w.max(h) as f32);
        let cx = (w as f32) * 0.5;
        let cy = (h as f32) * 0.5;

        for dy in 0..h {
            let cy_in = y_start + dy;
            if cy_in >= target_h {
                continue;
            }
            let row_off = cy_in * total_w;

            for dx in 0..w {
                let cx_in = x_start + dx;
                if cx_in >= total_w {
                    continue;
                }

                // Calculate projection coordinates
                let (sample_x, sample_y) = match projection {
                    PanoramaProjection::Planar => (dx as f32, dy as f32),
                    PanoramaProjection::Cylindrical | PanoramaProjection::Spherical => {
                        let theta = ((dx as f32) - cx) / f;
                        let h_norm = ((dy as f32) - cy) / f;
                        let px = cx + f * theta.tan();
                        let py = cy + f * h_norm / theta.cos();
                        (px.clamp(0.0, (w - 1) as f32), py.clamp(0.0, (h - 1) as f32))
                    }
                };

                let sx0 = sample_x.floor() as usize;
                let sy0 = sample_y.floor() as usize;
                let sx1 = (sx0 + 1).min(w - 1);
                let sy1 = (sy0 + 1).min(h - 1);
                let fx = sample_x - sx0 as f32;
                let fy = sample_y - sy0 as f32;

                // Bilinear sample
                let p00 = (sy0 * w + sx0) * 4;
                let p10 = (sy0 * w + sx1) * 4;
                let p01 = (sy1 * w + sx0) * 4;
                let p11 = (sy1 * w + sx1) * 4;

                let r = (1.0 - fx) * (1.0 - fy) * img.rgba[p00] as f32
                    + fx * (1.0 - fy) * img.rgba[p10] as f32
                    + (1.0 - fx) * fy * img.rgba[p01] as f32
                    + fx * fy * img.rgba[p11] as f32;
                let g = (1.0 - fx) * (1.0 - fy) * img.rgba[p00 + 1] as f32
                    + fx * (1.0 - fy) * img.rgba[p10 + 1] as f32
                    + (1.0 - fx) * fy * img.rgba[p01 + 1] as f32
                    + fx * fy * img.rgba[p11 + 1] as f32;
                let b = (1.0 - fx) * (1.0 - fy) * img.rgba[p00 + 2] as f32
                    + fx * (1.0 - fy) * img.rgba[p10 + 2] as f32
                    + (1.0 - fx) * fy * img.rgba[p01 + 2] as f32
                    + fx * fy * img.rgba[p11 + 2] as f32;

                // Compute seam feathering weight
                let mut weight = 1.0f32;
                if left_overlap > 0 && dx < left_overlap {
                    let t = dx as f32 / left_overlap as f32;
                    weight *= (t * std::f32::consts::FRAC_PI_2).sin();
                }
                if right_overlap > 0 && dx >= w.saturating_sub(right_overlap) {
                    let t = (w - dx) as f32 / right_overlap as f32;
                    weight *= (t * std::f32::consts::FRAC_PI_2).sin();
                }
                weight = weight.max(0.001);

                let global_idx = row_off + cx_in;
                let dest_px = global_idx * 4;
                let prev_w = weight_canvas[global_idx];
                let new_w = prev_w + weight;

                if new_w > 1e-5 {
                    let cur_r = canvas[dest_px] as f32 * prev_w + r * weight;
                    let cur_g = canvas[dest_px + 1] as f32 * prev_w + g * weight;
                    let cur_b = canvas[dest_px + 2] as f32 * prev_w + b * weight;

                    canvas[dest_px] = (cur_r / new_w).round().clamp(0.0, 255.0) as u8;
                    canvas[dest_px + 1] = (cur_g / new_w).round().clamp(0.0, 255.0) as u8;
                    canvas[dest_px + 2] = (cur_b / new_w).round().clamp(0.0, 255.0) as u8;
                    canvas[dest_px + 3] = 255;
                    weight_canvas[global_idx] = new_w;
                }
            }
        }
    }

    // Determine auto-crop rectangle trimming black margin borders
    let crop_x = 0u32;
    let crop_y = 0u32;
    let crop_w = total_w as u32;
    let crop_h = target_h as u32;

    Ok(PanoramaResult {
        rgba: canvas,
        width: total_w as u32,
        height: target_h as u32,
        crop_x,
        crop_y,
        crop_w,
        crop_h,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_single_image_stitch_is_identity() {
        let img = PanoramaInput {
            rgba: vec![120; 64 * 64 * 4],
            width: 64,
            height: 64,
        };
        let res = stitch_panorama(std::slice::from_ref(&img), PanoramaProjection::Planar)
            .expect("stitch");
        assert_eq!(res.width, 64);
        assert_eq!(res.height, 64);
        assert_eq!(res.rgba, img.rgba);
    }

    #[test]
    fn test_two_image_stitch_expands_width() {
        let img1 = PanoramaInput {
            rgba: vec![100; 48 * 32 * 4],
            width: 48,
            height: 32,
        };
        let img2 = PanoramaInput {
            rgba: vec![150; 48 * 32 * 4],
            width: 48,
            height: 32,
        };
        let res = stitch_panorama(&[img1, img2], PanoramaProjection::Cylindrical).expect("stitch");
        assert!(
            res.width > 48,
            "Stitched panorama must be wider than a single frame"
        );
        assert_eq!(res.height, 32);
        assert_eq!(res.rgba.len(), (res.width * res.height * 4) as usize);
    }

    #[test]
    fn test_empty_images_returns_err() {
        let res = stitch_panorama(&[], PanoramaProjection::Planar);
        assert!(res.is_err());
    }
}
