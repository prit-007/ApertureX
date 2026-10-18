//! Masking & local adjustments (P2.5). One model behind Lightroom "local
//! adjustments" and Snapseed "Stack": an adjustment layer = a mask + a
//! point-wise sub-grade, composited over the base. Masks are analytic
//! (linear / radial / luminance) so they stay small + non-destructive.

use crate::color::{grade_pointwise, GradeParams};

/// Mask kinds.
pub const MASK_LINEAR: u32 = 0;
pub const MASK_RADIAL: u32 = 1;
pub const MASK_LUMINANCE: u32 = 2;
pub const MASK_BRUSH: u32 = 3;
pub const MASK_SUBJECT: u32 = 4;
pub const MASK_SKY: u32 = 5;
pub const MASK_BITMAP: u32 = 6;

/// A parametric or bitmap mask.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct MaskSpec {
    pub kind: u32,
    /// linear `[x0,y0,x1,y1]`, radial `[cx,cy,rx,ry]`, luminance `[lo,hi]`,
    /// brush `[radius, feather, count, x0, y0, p0, ...]`,
    /// subject `[cx, cy, rx, ry, feather]`,
    /// sky `[horizon_y, feather, blue_weight]`,
    /// bitmap `[width, height, alpha_0, alpha_1, ...]`.
    pub params: Vec<f32>,
}

impl MaskSpec {
    pub fn linear(x0: f32, y0: f32, x1: f32, y1: f32) -> Self {
        MaskSpec {
            kind: MASK_LINEAR,
            params: vec![x0, y0, x1, y1],
        }
    }

    pub fn radial(cx: f32, cy: f32, rx: f32, ry: f32, feather: f32) -> Self {
        MaskSpec {
            kind: MASK_RADIAL,
            params: vec![cx, cy, rx, ry, feather],
        }
    }

    pub fn luminance(lo: f32, hi: f32) -> Self {
        MaskSpec {
            kind: MASK_LUMINANCE,
            params: vec![lo, hi],
        }
    }

    pub fn luminance_band(min_luma: f32, max_luma: f32, feather_lo: f32, feather_hi: f32) -> Self {
        MaskSpec {
            kind: MASK_LUMINANCE,
            params: vec![min_luma, max_luma, feather_lo, feather_hi],
        }
    }

    pub fn bitmap(w: usize, h: usize, alpha_bytes: &[u8]) -> Self {
        let mut params = Vec::with_capacity(2 + w * h);
        params.push(w as f32);
        params.push(h as f32);
        for &a in alpha_bytes {
            params.push(a as f32 / 255.0);
        }
        MaskSpec {
            kind: MASK_BITMAP,
            params,
        }
    }
}

/// Mask join operations for boolean coverage algebra (ADR 0013).
pub const JOIN_ADD: u32 = 0;
pub const JOIN_SUBTRACT: u32 = 1;
pub const JOIN_INTERSECT: u32 = 2;

/// A stack entry: where ([`MaskSpec`]) and what ([`GradeParams`]) to adjust.
#[derive(Clone, Debug, PartialEq)]
pub struct LocalAdjustment {
    pub mask: MaskSpec,
    pub params: GradeParams,
    pub inverted: bool,
    pub amount: f32,
    pub group_id: Option<String>,
    pub join_op: u32,
    pub group_inverted: bool,
    pub group_amount: f32,
}

impl Default for LocalAdjustment {
    fn default() -> Self {
        Self {
            mask: MaskSpec::default(),
            params: GradeParams::default(),
            inverted: false,
            amount: 1.0,
            group_id: None,
            join_op: JOIN_ADD,
            group_inverted: false,
            group_amount: 1.0,
        }
    }
}

fn smoothstep(a: f32, b: f32, x: f32) -> f32 {
    if (b - a).abs() < 1e-6 {
        return if x >= b { 1.0 } else { 0.0 };
    }
    let t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}

/// Computes the distance from `(u, v)` to a line segment `(x0, y0) -> (x1, y1)`
/// along with the projected parameter `t in [0, 1]`.
pub fn dist_to_segment(u: f32, v: f32, x0: f32, y0: f32, x1: f32, y1: f32) -> (f32, f32) {
    let dx = x1 - x0;
    let dy = y1 - y0;
    let len2 = dx * dx + dy * dy;
    if len2 < 1e-7 {
        let dist = ((u - x0).powi(2) + (v - y0).powi(2)).sqrt();
        return (dist, 0.0);
    }
    let t = (((u - x0) * dx + (v - y0) * dy) / len2).clamp(0.0, 1.0);
    let px = x0 + t * dx;
    let py = y0 + t * dy;
    let dist = ((u - px).powi(2) + (v - py).powi(2)).sqrt();
    (dist, t)
}

/// Mask coverage in `[0,1]` at normalised `(u,v)` (0..1) with luminance [luma].
pub fn coverage(kind: u32, p: &[f32], u: f32, v: f32, luma: f32) -> f32 {
    coverage_rgb(kind, p, u, v, luma, [luma, luma, luma])
}

/// Mask coverage in `[0,1]` at normalised `(u,v)` (0..1) with luminance [luma]
/// and source color [rgb].
pub fn coverage_rgb(kind: u32, p: &[f32], u: f32, v: f32, luma: f32, rgb: [f32; 3]) -> f32 {
    match kind {
        MASK_RADIAL => {
            if p.len() < 4 {
                return 0.0;
            }
            let (cx, cy) = (p[0], p[1]);
            let (rx, ry) = (p[2].max(1e-3), p[3].max(1e-3));
            let feather = p.get(4).copied().unwrap_or(0.3).clamp(1e-3, 1.0);
            let d = (((u - cx) / rx).powi(2) + ((v - cy) / ry).powi(2)).sqrt();
            1.0 - smoothstep(1.0 - feather, 1.0, d)
        }
        MASK_LUMINANCE => {
            if p.is_empty() {
                return 0.0;
            }
            if p.len() < 3 {
                // Legacy: selects dark tones: coverage 1 below `lo`, fading to 0 at `hi`.
                let (lo, hi) = (p[0], p.get(1).copied().unwrap_or(0.4));
                1.0 - smoothstep(lo, hi, luma)
            } else {
                // Zone System band: [min_luma, max_luma, feather_lo, feather_hi]
                let min_luma = p[0];
                let max_luma = p[1];
                let f_lo = p[2].max(1e-4);
                let f_hi = p.get(3).copied().unwrap_or(f_lo).max(1e-4);
                if luma < min_luma {
                    smoothstep(min_luma - f_lo, min_luma, luma)
                } else if luma > max_luma {
                    1.0 - smoothstep(max_luma, max_luma + f_hi, luma)
                } else {
                    1.0
                }
            }
        }
        MASK_BRUSH => {
            // [radius, feather, count, x0, y0, p0, x1, y1, p1, ...]
            if p.len() < 3 || p[2] < 0.0 {
                return 0.0;
            }
            let radius = p[0].max(1e-4);
            let feather = p[1].clamp(1e-3, 1.0);
            let count = p[2] as usize;
            let required_len = match count.checked_mul(3).and_then(|c| 3usize.checked_add(c)) {
                Some(len) => len,
                None => return 0.0,
            };
            if count == 0 || p.len() < required_len {
                return 0.0;
            }
            let points = &p[3..required_len];

            // Fast bounding box check (filtering out stroke-break sentinels < 0.0)
            let mut min_x = f32::MAX;
            let mut max_x = f32::MIN;
            let mut min_y = f32::MAX;
            let mut max_y = f32::MIN;
            for chunk in points.as_chunks::<3>().0 {
                if chunk[0] >= 0.0 && chunk[1] >= 0.0 {
                    min_x = min_x.min(chunk[0]);
                    max_x = max_x.max(chunk[0]);
                    min_y = min_y.min(chunk[1]);
                    max_y = max_y.max(chunk[1]);
                }
            }
            if min_x > max_x
                || u < min_x - radius
                || u > max_x + radius
                || v < min_y - radius
                || v > max_y + radius
            {
                return 0.0;
            }

            let mut max_cov = 0.0f32;
            for i in 0..count {
                let (x0, y0, pr0) = (
                    points[i * 3],
                    points[i * 3 + 1],
                    points[i * 3 + 2].clamp(0.0, 1.0),
                );
                if x0 < 0.0 || y0 < 0.0 {
                    continue;
                }
                // Check distance to point itself (covers single taps and stroke endpoints)
                let dist_pt = ((u - x0).powi(2) + (v - y0).powi(2)).sqrt();
                let eff_r_pt = radius * pr0.max(0.1);
                if dist_pt < eff_r_pt {
                    let cov_pt =
                        (1.0 - smoothstep(eff_r_pt * (1.0 - feather), eff_r_pt, dist_pt)) * pr0;
                    max_cov = max_cov.max(cov_pt);
                }

                // Check distance to segment connecting to next point if not break
                if i + 1 < count {
                    let (x1, y1, pr1) = (
                        points[(i + 1) * 3],
                        points[(i + 1) * 3 + 1],
                        points[(i + 1) * 3 + 2].clamp(0.0, 1.0),
                    );
                    if x1 >= 0.0 && y1 >= 0.0 {
                        let (dist, t) = dist_to_segment(u, v, x0, y0, x1, y1);
                        let pr = pr0 + t * (pr1 - pr0);
                        let eff_r = radius * pr.max(0.1);
                        if dist < eff_r {
                            let cov = (1.0 - smoothstep(eff_r * (1.0 - feather), eff_r, dist)) * pr;
                            max_cov = max_cov.max(cov);
                        }
                    }
                }
            }
            max_cov
        }
        MASK_SUBJECT => {
            // [cx, cy, rx, ry, feather]
            let cx = p.first().copied().unwrap_or(0.5);
            let cy = p.get(1).copied().unwrap_or(0.5);
            let rx = p.get(2).copied().unwrap_or(0.28).max(1e-3);
            let ry = p.get(3).copied().unwrap_or(0.38).max(1e-3);
            let feather = p.get(4).copied().unwrap_or(0.3).clamp(1e-3, 1.0);
            let d = (((u - cx) / rx).powi(2) + ((v - cy) / ry).powi(2)).sqrt();
            1.0 - smoothstep(1.0 - feather, 1.0, d)
        }
        MASK_SKY => {
            // [horizon_y, feather, blue_weight]
            let horizon = p.first().copied().unwrap_or(0.55);
            let feather = p.get(1).copied().unwrap_or(0.2).clamp(1e-3, 1.0);
            let blue_weight = p.get(2).copied().unwrap_or(0.5).clamp(0.0, 1.0);
            let v_cov = 1.0 - smoothstep(horizon - feather, horizon + feather, v);
            if v_cov <= 1e-4 {
                return 0.0;
            }
            // Sky chromaticity prior: blue dominance or bright cloud
            let is_blue_sky = rgb[2] > rgb[0] * 0.85 && luma > 0.2;
            let is_cloud = luma > 0.65 && (rgb[0] - rgb[2]).abs() < 0.25;
            let color_score = if is_blue_sky || is_cloud { 1.0 } else { 0.35 };
            v_cov * (1.0 - blue_weight + blue_weight * color_score)
        }
        MASK_BITMAP => {
            // [width, height, alpha_0, alpha_1, ...]
            if p.len() < 2 || p[0] <= 0.0 || p[1] <= 0.0 {
                return 0.0;
            }
            let bw = p[0].round() as usize;
            let bh = p[1].round() as usize;
            let required_len = match bw.checked_mul(bh).and_then(|px| 2usize.checked_add(px)) {
                Some(len) => len,
                None => return 0.0,
            };
            if bw == 0 || bh == 0 || p.len() < required_len {
                return 0.0;
            }
            let data = &p[2..required_len];
            let uf = (u.clamp(0.0, 1.0) * (bw.saturating_sub(1) as f32)).max(0.0);
            let vf = (v.clamp(0.0, 1.0) * (bh.saturating_sub(1) as f32)).max(0.0);
            let x0 = uf.floor() as usize;
            let y0 = vf.floor() as usize;
            let x1 = (x0 + 1).min(bw - 1);
            let y1 = (y0 + 1).min(bh - 1);
            let fx = uf - x0 as f32;
            let fy = vf - y0 as f32;

            let c00 = data[y0 * bw + x0];
            let c10 = data[y0 * bw + x1];
            let c01 = data[y1 * bw + x0];
            let c11 = data[y1 * bw + x1];

            let c0 = c00 + (c10 - c00) * fx;
            let c1 = c01 + (c11 - c01) * fx;
            (c0 + (c1 - c0) * fy).clamp(0.0, 1.0)
        }
        // MASK_LINEAR: gradient from (x0,y0) to (x1,y1).
        MASK_LINEAR => {
            if p.len() < 4 {
                return 0.0;
            }
            let (x0, y0, x1, y1) = (p[0], p[1], p[2], p[3]);
            let (dx, dy) = (x1 - x0, y1 - y0);
            let len2 = dx * dx + dy * dy;
            let t = if len2 < 1e-6 {
                0.0
            } else {
                ((u - x0) * dx + (v - y0) * dy) / len2
            };
            smoothstep(0.0, 1.0, t)
        }
        _ => 0.0,
    }
}

/// Detected sky parameters from a proxy image.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct DetectedSky {
    pub horizon_y: f32,
    pub feather: f32,
    pub blue_weight: f32,
}

/// Estimates sky horizon position, edge feather, and blue chromaticity weight
/// using vertical luma/chroma skyline gradients and sky chromaticity priors.
/// Returns `None` if the upper frame contains insufficient sky characteristics.
pub fn detect_sky(rgba: &[u8], width: usize, height: usize) -> Option<DetectedSky> {
    if width < 8 || height < 8 || rgba.len() < width * height * 4 {
        return None;
    }

    // 1. Compute per-row sky statistics
    let mut row_sky_count = vec![0usize; height];
    let mut row_blue_count = vec![0usize; height];

    for y in 0..height {
        let row_start = y * width * 4;
        let mut sky_c = 0;
        let mut blue_c = 0;

        for x in 0..width {
            let px = row_start + x * 4;
            let r = rgba[px] as f32 / 255.0;
            let g = rgba[px + 1] as f32 / 255.0;
            let b = rgba[px + 2] as f32 / 255.0;
            let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;

            // Blue sky: blue dominance over red and green, plus moderate luma
            let is_blue_sky = (b - r) > 0.05 && b > g * 0.85 && luma > 0.20;
            // Overcast/cloud: high luma neutral tone
            let is_cloud = luma > 0.55 && (r - b).abs() < 0.25 && (g - b).abs() < 0.25;

            if is_blue_sky || is_cloud {
                sky_c += 1;
                if is_blue_sky && (b - r) > 0.10 {
                    blue_c += 1;
                }
            }
        }

        row_sky_count[y] = sky_c;
        row_blue_count[y] = blue_c;
    }

    // 2. Validate top portion has sky (ADR 0010: heuristic fallback)
    let top_check_rows = (height * 3 / 10).max(2);
    let top_sky_sum: usize = row_sky_count[..top_check_rows].iter().sum();
    let top_total_px = top_check_rows * width;
    let top_sky_ratio = top_sky_sum as f32 / top_total_px as f32;

    if top_sky_ratio < 0.25 {
        return None;
    }

    // 3. Find optimal skyline boundary using between-class variance (Otsu-style 1D split)
    let total_sky: usize = row_sky_count.iter().sum();
    let min_split = (height / 10).max(1);
    let max_split = (height * 9 / 10).min(height - 1);

    let mut best_score = -1.0f32;
    let mut best_horizon_row = height / 2;
    let mut best_mu_top = 0.0f32;
    let mut best_mu_bot = 0.0f32;

    let mut top_cum_sky: usize = row_sky_count[..min_split].iter().sum();

    for y in min_split..=max_split {
        top_cum_sky += row_sky_count[y - 1];
        let bot_cum_sky = total_sky.saturating_sub(top_cum_sky);

        let top_px = y * width;
        let bot_px = (height - y) * width;

        let mu_top = top_cum_sky as f32 / top_px as f32;
        let mu_bot = bot_cum_sky as f32 / bot_px as f32;

        if mu_top > mu_bot {
            let weight = (y as f32 / height as f32) * ((height - y) as f32 / height as f32);
            let diff = mu_top - mu_bot;
            let score = weight * diff * diff;

            if score > best_score {
                best_score = score;
                best_horizon_row = y;
                best_mu_top = mu_top;
                best_mu_bot = mu_bot;
            }
        }
    }

    // Check that we found a clear skyline transition
    if best_score <= 0.0 || (best_mu_top - best_mu_bot) < 0.15 || best_mu_top < 0.35 {
        return None;
    }

    let horizon_y = (best_horizon_row as f32 / height as f32).clamp(0.05, 0.95);

    // 4. Estimate feather based on transition softness around best_horizon_row
    let window = (height / 8).max(2);
    let y_start = best_horizon_row.saturating_sub(window);
    let y_end = (best_horizon_row + window).min(height);
    let mut trans_rows = 1usize;
    let high_thresh = (best_mu_top * 0.75).max(0.2);
    let low_thresh = (best_mu_bot * 1.25).min(high_thresh - 0.05);

    for &count in &row_sky_count[y_start..y_end] {
        let r_ratio = count as f32 / width as f32;
        if r_ratio < high_thresh && r_ratio > low_thresh {
            trans_rows += 1;
        }
    }
    let feather = ((trans_rows as f32 / height as f32) * 1.5).clamp(0.08, 0.25);

    // 5. Estimate blue_weight from chromaticity in the detected sky region
    let sky_region_blue: usize = row_blue_count[..best_horizon_row].iter().sum();
    let sky_region_total: usize = row_sky_count[..best_horizon_row].iter().sum();
    let blue_ratio = if sky_region_total > 0 {
        sky_region_blue as f32 / sky_region_total as f32
    } else {
        0.5
    };
    // Blue skies -> 0.6 - 0.85; Overcast/cloudy skies -> 0.20 - 0.50
    let blue_weight = (0.30 + 0.45 * blue_ratio).clamp(0.20, 0.85);

    Some(DetectedSky {
        horizon_y,
        feather,
        blue_weight,
    })
}

/// Detected subject parameters from a proxy image.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct DetectedSubject {
    pub cx: f32,
    pub cy: f32,
    pub rx: f32,
    pub ry: f32,
    pub feather: f32,
}

/// Automatically detects dominant subject center, radii, and feather using
/// spatial saliency and boundary-contrast priors.
pub fn detect_subject(rgba: &[u8], width: usize, height: usize) -> Option<DetectedSubject> {
    if width < 8 || height < 8 || rgba.len() < width * height * 4 {
        return None;
    }

    // 1. Compute average boundary color (background prior)
    let mut bg_r = 0.0f32;
    let mut bg_g = 0.0f32;
    let mut bg_b = 0.0f32;
    let mut border_count = 0usize;

    for x in 0..width {
        // top row
        let idx0 = x * 4;
        bg_r += rgba[idx0] as f32 / 255.0;
        bg_g += rgba[idx0 + 1] as f32 / 255.0;
        bg_b += rgba[idx0 + 2] as f32 / 255.0;
        // bottom row
        let idx1 = ((height - 1) * width + x) * 4;
        bg_r += rgba[idx1] as f32 / 255.0;
        bg_g += rgba[idx1 + 1] as f32 / 255.0;
        bg_b += rgba[idx1 + 2] as f32 / 255.0;
        border_count += 2;
    }

    for y in 1..height - 1 {
        // left column
        let idx0 = y * width * 4;
        bg_r += rgba[idx0] as f32 / 255.0;
        bg_g += rgba[idx0 + 1] as f32 / 255.0;
        bg_b += rgba[idx0 + 2] as f32 / 255.0;
        // right column
        let idx1 = (y * width + (width - 1)) * 4;
        bg_r += rgba[idx1] as f32 / 255.0;
        bg_g += rgba[idx1 + 1] as f32 / 255.0;
        bg_b += rgba[idx1 + 2] as f32 / 255.0;
        border_count += 2;
    }

    if border_count > 0 {
        bg_r /= border_count as f32;
        bg_g /= border_count as f32;
        bg_b /= border_count as f32;
    }

    // 2. Compute saliency map & first/second moments
    let mut sum_w = 0.0f32;
    let mut sum_x = 0.0f32;
    let mut sum_y = 0.0f32;

    for y in 0..height {
        let v = (y as f32 + 0.5) / height as f32;
        let row_start = y * width * 4;
        for x in 0..width {
            let u = (x as f32 + 0.5) / width as f32;
            let px = row_start + x * 4;
            let r = rgba[px] as f32 / 255.0;
            let g = rgba[px + 1] as f32 / 255.0;
            let b = rgba[px + 2] as f32 / 255.0;

            // Distance from background
            let dr = r - bg_r;
            let dg = g - bg_g;
            let db = b - bg_b;
            let color_diff = (dr * dr + dg * dg + db * db).sqrt();

            // Local gradient energy (horizontal + vertical step)
            let grad_x = if x + 1 < width {
                let next = px + 4;
                ((rgba[next] as f32 - rgba[px] as f32).abs()
                    + (rgba[next + 1] as f32 - rgba[px + 1] as f32).abs()
                    + (rgba[next + 2] as f32 - rgba[px + 2] as f32).abs())
                    / (3.0 * 255.0)
            } else {
                0.0
            };

            let grad_y = if y + 1 < height {
                let next = (y + 1) * width * 4 + x * 4;
                ((rgba[next] as f32 - rgba[px] as f32).abs()
                    + (rgba[next + 1] as f32 - rgba[px + 1] as f32).abs()
                    + (rgba[next + 2] as f32 - rgba[px + 2] as f32).abs())
                    / (3.0 * 255.0)
            } else {
                0.0
            };

            // Center prior (Gaussian-like soft falloff)
            let du = u - 0.5;
            let dv = v - 0.5;
            let center_falloff = (-2.0 * (du * du + dv * dv)).exp();

            let saliency = (color_diff * 0.65 + (grad_x + grad_y) * 0.35) * center_falloff;
            sum_w += saliency;
            sum_x += u * saliency;
            sum_y += v * saliency;
        }
    }

    if sum_w < 1e-4 {
        // Fallback default center subject
        return Some(DetectedSubject {
            cx: 0.5,
            cy: 0.5,
            rx: 0.28,
            ry: 0.38,
            feather: 0.25,
        });
    }

    let cx = (sum_x / sum_w).clamp(0.15, 0.85);
    let cy = (sum_y / sum_w).clamp(0.15, 0.85);

    // Second central moments for rx and ry
    let mut sum_var_x = 0.0f32;
    let mut sum_var_y = 0.0f32;

    for y in 0..height {
        let v = (y as f32 + 0.5) / height as f32;
        let row_start = y * width * 4;
        for x in 0..width {
            let u = (x as f32 + 0.5) / width as f32;
            let px = row_start + x * 4;
            let r = rgba[px] as f32 / 255.0;
            let g = rgba[px + 1] as f32 / 255.0;
            let b = rgba[px + 2] as f32 / 255.0;

            let dr = r - bg_r;
            let dg = g - bg_g;
            let db = b - bg_b;
            let color_diff = (dr * dr + dg * dg + db * db).sqrt();

            let du = u - 0.5;
            let dv = v - 0.5;
            let center_falloff = (-2.0 * (du * du + dv * dv)).exp();

            let saliency = color_diff * center_falloff;
            let dx = u - cx;
            let dy = v - cy;
            sum_var_x += dx * dx * saliency;
            sum_var_y += dy * dy * saliency;
        }
    }

    let rx = ((sum_var_x / sum_w).sqrt() * 2.2).clamp(0.12, 0.45);
    let ry = ((sum_var_y / sum_w).sqrt() * 2.2).clamp(0.15, 0.48);

    Some(DetectedSubject {
        cx,
        cy,
        rx,
        ry,
        feather: 0.25,
    })
}

/// Rasterizes a mask into an alpha plane `[0.0, 1.0]` of dimensions `w x h`.
///
/// If `rgba` is provided (RGBA8, `w * h * 4`), it is used for luminance-dependent
/// and sky-dependent mask evaluation. Otherwise a neutral 50% gray image is assumed.
pub fn rasterize_mask(
    kind: u32,
    params: &[f32],
    w: usize,
    h: usize,
    rgba: Option<&[u8]>,
) -> Vec<f32> {
    if w == 0 || h == 0 {
        return Vec::new();
    }
    let mut out = vec![0.0f32; w * h];
    for y in 0..h {
        let v = (y as f32 + 0.5) / h as f32;
        let row_offset = y * w;
        for x in 0..w {
            let u = (x as f32 + 0.5) / w as f32;
            let idx = row_offset + x;
            let (luma, rgb) = if let Some(buf) = rgba {
                if (idx + 1) * 4 <= buf.len() {
                    let r = buf[idx * 4] as f32 / 255.0;
                    let g = buf[idx * 4 + 1] as f32 / 255.0;
                    let b = buf[idx * 4 + 2] as f32 / 255.0;
                    let l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
                    (l, [r, g, b])
                } else {
                    (0.5, [0.5, 0.5, 0.5])
                }
            } else {
                (0.5, [0.5, 0.5, 0.5])
            };
            out[idx] = coverage_rgb(kind, params, u, v, luma, rgb);
        }
    }
    out
}

/// Refines a mask alpha channel using guided-filter re-matting against image luminance.
///
/// Implements edge-preserving alpha matting where the underlying image edges guide
/// the transition boundaries of the mask.
///
/// If `stroke_points` is non-empty (`[x0, y0, x1, y1, ...]`), refinement is localized
/// to within `brush_radius` of the stroke points (Refine Edge Brush).
/// If `stroke_points` is empty, refinement applies along the mask's edge transitions
/// (whole-mask edge refine).
#[allow(clippy::too_many_arguments)]
pub fn refine_mask_guided(
    rgba: &[u8],
    w: usize,
    h: usize,
    mask_alphas: &[f32],
    stroke_points: &[f32],
    brush_radius: f32,
    filter_radius: usize,
    eps: f32,
) -> Vec<f32> {
    if w == 0 || h == 0 || mask_alphas.is_empty() {
        return mask_alphas.to_vec();
    }
    let n = w * h;
    assert_eq!(mask_alphas.len(), n);

    // 1. Compute guide image (normalized luminance in 0..1)
    let mut luma_guide = Vec::with_capacity(n);
    for i in 0..n {
        let (r, g, b) = if (i + 1) * 4 <= rgba.len() {
            (
                rgba[i * 4] as f32 / 255.0,
                rgba[i * 4 + 1] as f32 / 255.0,
                rgba[i * 4 + 2] as f32 / 255.0,
            )
        } else {
            (0.5, 0.5, 0.5)
        };
        luma_guide.push(0.2126 * r + 0.7152 * g + 0.0722 * b);
    }

    // 2. Run guided filter on mask alphas with luma guide
    let filtered_q = crate::spatial::guided_filter_channel(
        &luma_guide,
        mask_alphas,
        w,
        h,
        filter_radius.max(1),
        eps.max(1e-6),
    );

    // 3. Blend filtered alphas back into original mask according to region of influence
    let mut out = Vec::with_capacity(n);

    if stroke_points.len() >= 2 {
        // Refine Edge Brush: blend inside stroke radius
        let pt_count = stroke_points.len() / 2;
        let r_eff = brush_radius.max(1e-4);
        let r_sq = r_eff * r_eff;

        for y in 0..h {
            let v = (y as f32 + 0.5) / h as f32;
            let row_offset = y * w;
            for x in 0..w {
                let u = (x as f32 + 0.5) / w as f32;
                let idx = row_offset + x;
                let p = mask_alphas[idx];
                let q = filtered_q[idx].clamp(0.0, 1.0);

                // Find minimum distance to stroke points/segments
                let mut min_d_sq = f32::MAX;
                for i in 0..pt_count {
                    let px0 = stroke_points[i * 2];
                    let py0 = stroke_points[i * 2 + 1];
                    if px0 < 0.0 || py0 < 0.0 {
                        continue;
                    }
                    if i + 1 < pt_count {
                        let px1 = stroke_points[(i + 1) * 2];
                        let py1 = stroke_points[(i + 1) * 2 + 1];
                        if px1 >= 0.0 && py1 >= 0.0 {
                            let (dist, _) = dist_to_segment(u, v, px0, py0, px1, py1);
                            min_d_sq = min_d_sq.min(dist * dist);
                            continue;
                        }
                    }
                    let d_sq = (u - px0).powi(2) + (v - py0).powi(2);
                    min_d_sq = min_d_sq.min(d_sq);
                }

                if min_d_sq <= r_sq {
                    let dist = min_d_sq.sqrt();
                    let stroke_weight = 1.0 - smoothstep(r_eff * 0.4, r_eff, dist);
                    out.push(p * (1.0 - stroke_weight) + q * stroke_weight);
                } else {
                    out.push(p);
                }
            }
        }
    } else {
        // Whole-mask edge refine: re-matte the transition zone (0.01 < p < 0.99)
        for i in 0..n {
            let p = mask_alphas[i];
            let q = filtered_q[i].clamp(0.0, 1.0);
            let edge_weight = (1.0 - (2.0 * p - 1.0).abs().powi(2)).clamp(0.0, 1.0);
            out.push(p * (1.0 - edge_weight) + q * edge_weight);
        }
    }

    out
}

/// Composites every layer over [rgba] (RGBA8, `w*h*4`), in order.
pub fn apply_local(rgba: &[u8], w: usize, h: usize, layers: &[LocalAdjustment]) -> Vec<u8> {
    let mut out = rgba.to_vec();
    if layers.is_empty() || w == 0 || h == 0 {
        return out;
    }
    apply_local_rows(&mut out, w, 0, 0, w, h, layers);
    out
}

/// Composites every layer over a **band** of rows `y0..y0+bh` (RGBA8,
/// `w*bh*4`), where `full_h` is the full image height.
///
/// Masks are analytic and per-pixel (no neighbourhood), so a band needs no
/// halo: the only tile-awareness is that `u,v` are normalised against the
/// **full** image, which is what makes bands stitch seamlessly.
pub fn apply_local_band(
    band: &[u8],
    w: usize,
    full_h: usize,
    y0: usize,
    layers: &[LocalAdjustment],
) -> Vec<u8> {
    let mut out = band.to_vec();
    if layers.is_empty() || w == 0 || full_h == 0 {
        return out;
    }
    apply_local_rows(&mut out, w, 0, y0, w, full_h, layers);
    out
}

/// Composites every layer over a **rect (tile)** whose top-left pixel sits at
/// `(x0, y0)` of the `full_w x full_h` image (RGBA8, `tw*th*4`, [tw] per row).
///
/// Same seam-free argument as [`apply_local_band`]: `u,v` normalise against
/// the **full** image, so neighbouring tiles agree at their shared pixels.
pub fn apply_local_rect(
    band: &[u8],
    tw: usize,
    x0: usize,
    y0: usize,
    full_w: usize,
    full_h: usize,
    layers: &[LocalAdjustment],
) -> Vec<u8> {
    let mut out = band.to_vec();
    if layers.is_empty() || tw == 0 || full_w == 0 || full_h == 0 {
        return out;
    }
    apply_local_rows(&mut out, tw, x0, y0, full_w, full_h, layers);
    out
}

struct LocalGroup<'a> {
    params: GradeParams,
    inverted: bool,
    amount: f32,
    members: Vec<&'a LocalAdjustment>,
}

fn group_adjustments<'a>(layers: &'a [LocalAdjustment]) -> Vec<LocalGroup<'a>> {
    let mut groups: Vec<LocalGroup<'a>> = Vec::new();
    let mut group_indices: std::collections::HashMap<&str, usize> =
        std::collections::HashMap::new();

    for layer in layers {
        if let Some(gid) = layer.group_id.as_deref().filter(|s| !s.is_empty()) {
            if let Some(&idx) = group_indices.get(gid) {
                groups[idx].members.push(layer);
            } else {
                let idx = groups.len();
                group_indices.insert(gid, idx);
                groups.push(LocalGroup {
                    params: layer.params,
                    inverted: layer.group_inverted,
                    amount: layer.group_amount,
                    members: vec![layer],
                });
            }
        } else {
            groups.push(LocalGroup {
                params: layer.params,
                inverted: false,
                amount: 1.0,
                members: vec![layer],
            });
        }
    }
    groups
}

/// The shared per-pixel body of [`apply_local`] / [`apply_local_band`] /
/// [`apply_local_rect`]. `(x_origin, row_origin)` is the global position of
/// the buffer's first pixel (0,0 for the full image; tile/band offsets
/// otherwise), so normalised `u,v` always span the full frame.
fn apply_local_rows(
    buf: &mut [u8],
    buf_w: usize,
    x_origin: usize,
    row_origin: usize,
    full_w: usize,
    full_h: usize,
    layers: &[LocalAdjustment],
) {
    let groups = group_adjustments(layers);
    for group in groups {
        if group.members.is_empty() {
            continue;
        }
        for y in 0..buf.len() / (buf_w * 4).max(1) {
            let v = ((row_origin + y) as f32 + 0.5) / full_h as f32;
            for x in 0..buf_w {
                let i = (y * buf_w + x) * 4;
                let u = ((x_origin + x) as f32 + 0.5) / full_w as f32;
                let base = [
                    buf[i] as f32 / 255.0,
                    buf[i + 1] as f32 / 255.0,
                    buf[i + 2] as f32 / 255.0,
                ];
                let luma = 0.2126 * base[0] + 0.7152 * base[1] + 0.0722 * base[2];

                let mut group_cov = 0.0f32;
                for (m_idx, member) in group.members.iter().enumerate() {
                    let raw_cov = coverage(member.mask.kind, &member.mask.params, u, v, luma);
                    let member_cov = if member.inverted {
                        1.0 - raw_cov
                    } else {
                        raw_cov
                    };
                    let c = (member_cov * member.amount).clamp(0.0, 1.0);
                    if m_idx == 0 {
                        group_cov = if group.members.len() > 1 {
                            c
                        } else {
                            member_cov * member.amount
                        };
                    } else {
                        match member.join_op {
                            JOIN_SUBTRACT => {
                                group_cov = (group_cov - c).max(0.0);
                            }
                            JOIN_INTERSECT => {
                                group_cov *= c;
                            }
                            _ => {
                                group_cov = (group_cov + c).min(1.0);
                            }
                        }
                    }
                }

                if group.inverted {
                    group_cov = (1.0 - group_cov).clamp(0.0, 1.0);
                }

                let t = group_cov * group.amount;
                if t <= 0.0 {
                    continue;
                }

                let adjusted = grade_pointwise(base, group.params);
                for c in 0..3 {
                    // Lightroom-style Amount (0–200%): t extrapolates past 1.0 when amount > 1.0.
                    // Keep unclamped t so overdrive works, clamping to [0.0, 255.0] only at final byte write.
                    let mixed = base[c] + (adjusted[c] - base[c]) * t;
                    buf[i + c] = (mixed * 255.0 + 0.5).clamp(0.0, 255.0) as u8;
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn grey(w: usize, h: usize, v: u8) -> Vec<u8> {
        let mut b = Vec::with_capacity(w * h * 4);
        for _ in 0..w * h {
            b.extend_from_slice(&[v, v, v, 255]);
        }
        b
    }

    fn brighten() -> GradeParams {
        GradeParams {
            exposure: 1.0,
            ..Default::default()
        }
    }

    #[test]
    fn empty_layers_is_identity() {
        let src = grey(8, 8, 100);
        assert_eq!(apply_local(&src, 8, 8, &[]), src);
    }

    #[test]
    fn radial_mask_brightens_the_centre_only() {
        let src = grey(32, 32, 100);
        let layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_RADIAL,
                params: vec![0.5, 0.5, 0.3, 0.3, 0.3],
            },
            params: brighten(),
            inverted: false,
            amount: 1.0,
            ..Default::default()
        };
        let out = apply_local(&src, 32, 32, &[layer]);
        let centre = out[(16 * 32 + 16) * 4];
        let corner = out[0];
        assert!(centre > 120, "centre should brighten: {centre}");
        assert_eq!(corner, 100, "corner untouched");
    }

    #[test]
    fn linear_mask_brightens_one_side() {
        let src = grey(16, 16, 100);
        let layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_LINEAR,
                params: vec![0.0, 0.0, 0.0, 1.0],
            },
            params: brighten(),
            inverted: false,
            amount: 1.0,
            ..Default::default()
        };
        let out = apply_local(&src, 16, 16, &[layer]);
        let top = out[(16 + 8) * 4];
        let bottom = out[(15 * 16 + 8) * 4];
        assert!(bottom > top, "gradient brightens downward: {top} {bottom}");
    }

    #[test]
    fn luminance_mask_targets_darks() {
        let mut img = grey(16, 8, 0);
        for y in 0..8 {
            for x in 0..16 {
                let v = if x < 8 { 40u8 } else { 220u8 };
                let i = (y * 16 + x) * 4;
                img[i] = v;
                img[i + 1] = v;
                img[i + 2] = v;
            }
        }
        let layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_LUMINANCE,
                params: vec![0.0, 0.5],
            },
            params: brighten(),
            inverted: false,
            amount: 1.0,
            ..Default::default()
        };
        let out = apply_local(&img, 16, 8, &[layer]);
        let dark = out[(4 * 16 + 2) * 4];
        let bright = out[(4 * 16 + 13) * 4];
        assert!(dark > 48, "darks brightened: {dark}");
        assert!(bright.abs_diff(220) < 8, "brights ~untouched: {bright}");
    }

    #[test]
    fn luminance_mask_zone_band_selects_midtones() {
        // Target middle gray (Zone V ~ 0.5) with [0.4, 0.6, 0.1, 0.1]
        let layer = LocalAdjustment {
            mask: MaskSpec::luminance_band(0.4, 0.6, 0.1, 0.1),
            params: brighten(),
            inverted: false,
            amount: 1.0,
            ..Default::default()
        };
        // Create 3 pixels: dark (luma ~0.2), mid (luma ~0.5), bright (luma ~0.8)
        let img = vec![51, 51, 51, 255, 128, 128, 128, 255, 204, 204, 204, 255];
        let out = apply_local(&img, 3, 1, &[layer]);
        let p_dark = out[0];
        let p_mid = out[4];
        let p_bright = out[8];

        // Midtone pixel is inside [0.4, 0.6] -> fully brightened
        assert!(p_mid > 150, "mid pixel brightened: {p_mid}");
        // Dark pixel (0.2 < 0.3) -> outside feather, untouched
        assert_eq!(p_dark, 51, "dark pixel untouched: {p_dark}");
        // Bright pixel (0.8 > 0.7) -> outside feather, untouched
        assert_eq!(p_bright, 204, "bright pixel untouched: {p_bright}");
    }

    #[test]
    fn luminance_mask_zone_band_falls_off_smoothly() {
        // Band [0.5, 0.5, 0.2, 0.2]
        // Center at 0.5 has cov 1.0; 0.4 has cov 0.5; 0.2 has cov 0.0
        let cov_center = coverage(MASK_LUMINANCE, &[0.5, 0.5, 0.2, 0.2], 0.0, 0.0, 0.5);
        let cov_half_lo = coverage(MASK_LUMINANCE, &[0.5, 0.5, 0.2, 0.2], 0.0, 0.0, 0.4);
        let cov_half_hi = coverage(MASK_LUMINANCE, &[0.5, 0.5, 0.2, 0.2], 0.0, 0.0, 0.6);
        let cov_outside_lo = coverage(MASK_LUMINANCE, &[0.5, 0.5, 0.2, 0.2], 0.0, 0.0, 0.2);
        let cov_outside_hi = coverage(MASK_LUMINANCE, &[0.5, 0.5, 0.2, 0.2], 0.0, 0.0, 0.8);

        assert_eq!(cov_center, 1.0);
        assert!((cov_half_lo - 0.5).abs() < 1e-3);
        assert!((cov_half_hi - 0.5).abs() < 1e-3);
        assert_eq!(cov_outside_lo, 0.0);
        assert_eq!(cov_outside_hi, 0.0);
    }

    /// A deterministic per-pixel ramp so mask coverage varies across the frame.
    fn ramp(w: usize, h: usize) -> Vec<u8> {
        let mut v = Vec::with_capacity(w * h * 4);
        for y in 0..h {
            for x in 0..w {
                let r = ((x * 13 + y * 5) % 256) as u8;
                let g = ((x * 7 + y * 29) % 256) as u8;
                let b = ((x * 3 + y * 11) % 256) as u8;
                v.extend_from_slice(&[r, g, b, 255]);
            }
        }
        v
    }

    /// A representative stack: one of each mask kind, with distinct sub-grades.
    fn stack() -> Vec<LocalAdjustment> {
        vec![
            LocalAdjustment {
                mask: MaskSpec {
                    kind: MASK_RADIAL,
                    params: vec![0.5, 0.5, 0.4, 0.35, 0.3],
                },
                params: brighten(),
                inverted: false,
                amount: 1.0,
                ..Default::default()
            },
            LocalAdjustment {
                mask: MaskSpec {
                    kind: MASK_LINEAR,
                    params: vec![0.1, 0.1, 0.9, 0.8],
                },
                params: GradeParams {
                    saturation: 0.5,
                    ..Default::default()
                },
                inverted: false,
                amount: 1.0,
                ..Default::default()
            },
            LocalAdjustment {
                mask: MaskSpec {
                    kind: MASK_LUMINANCE,
                    params: vec![0.3, 0.8],
                },
                params: GradeParams {
                    contrast: 0.4,
                    ..Default::default()
                },
                inverted: false,
                amount: 1.0,
                ..Default::default()
            },
        ]
    }

    #[test]
    fn banded_masks_stitch_to_the_full_frame() {
        let (w, h) = (48, 40);
        let src = ramp(w, h);
        let layers = stack();
        let full = apply_local(&src, w, h, &layers);
        for band_rows in [1usize, 7, 13, 20, 40] {
            let mut stitched = Vec::with_capacity(w * h * 4);
            let mut y0 = 0;
            while y0 < h {
                let bh = band_rows.min(h - y0);
                let band: Vec<u8> = (y0..y0 + bh)
                    .flat_map(|y| src[y * w * 4..(y + 1) * w * 4].iter().copied())
                    .collect();
                stitched.extend_from_slice(&apply_local_band(&band, w, h, y0, &layers));
                y0 += bh;
            }
            assert_eq!(stitched, full, "band_rows={band_rows} diverged");
        }
    }

    #[test]
    fn band_without_layers_is_a_copy() {
        let band = ramp(8, 3);
        assert_eq!(
            apply_local_band(&band, 8, 32, 4, &[]),
            band,
            "empty layers must not touch pixels"
        );
    }

    #[test]
    fn brush_mask_brightens_along_stroke() {
        let src = grey(32, 32, 100);
        // Single horizontal stroke at y = 0.5 from x = 0.2 to x = 0.8
        let layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_BRUSH,
                params: vec![
                    0.15, // radius
                    0.2,  // feather
                    2.0,  // count
                    0.2, 0.5, 1.0, // p0
                    0.8, 0.5, 1.0, // p1
                ],
            },
            params: brighten(),
            inverted: false,
            amount: 1.0,
            ..Default::default()
        };
        let out = apply_local(&src, 32, 32, &[layer]);
        let center = out[(16 * 32 + 16) * 4];
        let corner = out[0];
        assert!(center > 130, "center of stroke brightens: {center}");
        assert_eq!(corner, 100, "corner outside stroke is untouched");
    }

    #[test]
    fn brush_mask_multiple_strokes_respect_break_sentinel() {
        let src = grey(32, 32, 100);
        // Stroke 1 in top-left: (0.1, 0.2) to (0.2, 0.2)
        // Sentinel: (-1.0, -1.0, -1.0)
        // Stroke 2 in bottom-right: (0.8, 0.8) to (0.9, 0.8)
        let layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_BRUSH,
                params: vec![
                    0.08, // radius
                    0.2,  // feather
                    5.0,  // count (2 + 1 + 2)
                    0.1, 0.2, 1.0, // stroke 1 pt 0
                    0.2, 0.2, 1.0, // stroke 1 pt 1
                    -1.0, -1.0, -1.0, // stroke break sentinel
                    0.8, 0.8, 1.0, // stroke 2 pt 0
                    0.9, 0.8, 1.0, // stroke 2 pt 1
                ],
            },
            params: brighten(),
            inverted: false,
            amount: 1.0,
            ..Default::default()
        };
        let out = apply_local(&src, 32, 32, &[layer]);
        // Pixel along stroke 1
        let s1 = out[(6 * 32 + 5) * 4];
        // Pixel along stroke 2
        let s2 = out[(26 * 32 + 27) * 4];
        // Pixel exactly midway between the two strokes (at 0.5, 0.5 -> idx (16, 16))
        let midway = out[(16 * 32 + 16) * 4];

        assert!(s1 > 120, "stroke 1 pixel brightens: {s1}");
        assert!(s2 > 120, "stroke 2 pixel brightens: {s2}");
        assert_eq!(
            midway, 100,
            "midway between strokes is untouched (no line connecting them)"
        );
    }

    #[test]
    fn subject_mask_brightens_center_figure() {
        let src = grey(32, 32, 100);
        let layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_SUBJECT,
                params: vec![0.5, 0.5, 0.25, 0.35, 0.2],
            },
            params: brighten(),
            inverted: false,
            amount: 1.0,
            ..Default::default()
        };
        let out = apply_local(&src, 32, 32, &[layer]);
        let center = out[(16 * 32 + 16) * 4];
        let corner = out[0];
        assert!(center > 130, "subject center brightens: {center}");
        assert_eq!(corner, 100, "corner outside subject is untouched");
    }

    #[test]
    fn sky_mask_brightens_upper_frame() {
        // Image with upper half blue (sky) and lower half green (ground)
        let mut img = Vec::with_capacity(32 * 32 * 4);
        for y in 0..32 {
            for _ in 0..32 {
                if y < 16 {
                    img.extend_from_slice(&[80, 120, 200, 255]); // blue sky
                } else {
                    img.extend_from_slice(&[50, 140, 50, 255]); // ground
                }
            }
        }
        let layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_SKY,
                params: vec![0.5, 0.1, 0.6],
            },
            params: brighten(),
            inverted: false,
            amount: 1.0,
            ..Default::default()
        };
        let out = apply_local(&img, 32, 32, &[layer]);
        let sky_pixel = out[(4 * 32 + 16) * 4 + 2]; // Blue channel in sky
        let ground_pixel = out[(28 * 32 + 16) * 4 + 1]; // Green channel in ground
        assert!(sky_pixel > 200, "sky pixel brightened: {sky_pixel}");
        assert_eq!(ground_pixel, 140, "ground pixel untouched: {ground_pixel}");
    }

    #[test]
    fn bitmap_mask_samples_with_bilinear_interpolation() {
        // 2x2 bitmap mask:
        // [0.0, 1.0]
        // [0.0, 1.0]
        let bitmap_alphas = vec![0u8, 255u8, 0u8, 255u8];
        let layer = LocalAdjustment {
            mask: MaskSpec::bitmap(2, 2, &bitmap_alphas),
            params: brighten(),
            inverted: false,
            amount: 1.0,
            ..Default::default()
        };
        let src = grey(32, 32, 100);
        let out = apply_local(&src, 32, 32, &[layer]);

        // Left column (u ~= 0.5/32 = 0.0156) is barely touched (<= 102)
        let left_px = out[(16 * 32) * 4];
        // Right column (u ~= 31.5/32 = 0.984) is almost fully brightened (> 180)
        let right_px = out[(16 * 32 + 31) * 4];
        // Mid column (u ~= 16.5/32 = 0.515) is half brightened
        let mid_px = out[(16 * 32 + 16) * 4];

        assert!(left_px <= 102);
        assert!(right_px > 130);
        assert!(mid_px > left_px && mid_px < right_px);
    }

    #[test]
    fn bitmap_mask_banded_stitching_matches_full_frame() {
        // 4x4 bitmap with arbitrary gradients
        let bitmap_alphas: Vec<u8> = (0..16).map(|i| (i * 16) as u8).collect();
        let src = grey(24, 24, 80);
        let full = apply_local(
            &src,
            24,
            24,
            &[LocalAdjustment {
                mask: MaskSpec::bitmap(4, 4, &bitmap_alphas),
                params: brighten(),
                inverted: false,
                amount: 1.0,
                ..Default::default()
            }],
        );

        // Process in two 12-row bands
        let band0 = apply_local_band(
            &src[..24 * 12 * 4],
            24,
            24,
            0,
            &[LocalAdjustment {
                mask: MaskSpec::bitmap(4, 4, &bitmap_alphas),
                params: brighten(),
                inverted: false,
                amount: 1.0,
                ..Default::default()
            }],
        );
        let band1 = apply_local_band(
            &src[24 * 12 * 4..],
            24,
            24,
            12,
            &[LocalAdjustment {
                mask: MaskSpec::bitmap(4, 4, &bitmap_alphas),
                params: brighten(),
                inverted: false,
                amount: 1.0,
                ..Default::default()
            }],
        );

        let mut stitched = Vec::with_capacity(24 * 24 * 4);
        stitched.extend_from_slice(&band0);
        stitched.extend_from_slice(&band1);

        assert_eq!(
            stitched, full,
            "Banded bitmap mask stitching must exactly equal full frame render"
        );
    }

    #[test]
    fn synthetic_gradient_sky_with_known_horizon() {
        let (w, h) = (64, 64);
        let mut img = Vec::with_capacity(w * h * 4);
        for y in 0..h {
            for _x in 0..w {
                if y < 32 {
                    // Blue sky gradient in upper half (horizon at y = 32 -> 0.50)
                    img.extend_from_slice(&[80, 140, 230, 255]);
                } else {
                    // Green ground in lower half
                    img.extend_from_slice(&[30, 120, 40, 255]);
                }
            }
        }

        let detected = detect_sky(&img, w, h).expect("sky should be detected");
        assert!(
            (detected.horizon_y - 0.50).abs() <= 0.05,
            "horizon_y was {}, expected within 0.50 +/- 0.05",
            detected.horizon_y
        );
        assert!(
            detected.blue_weight > 0.55,
            "blue_weight was {}, expected > 0.55 for clear blue sky",
            detected.blue_weight
        );
    }

    #[test]
    fn overcast_cloud_fixture() {
        let (w, h) = (64, 64);
        let mut img = Vec::with_capacity(w * h * 4);
        for y in 0..h {
            for _x in 0..w {
                if y < 26 {
                    // Overcast/white-grey cloud sky (horizon at 26/64 ~= 0.406)
                    img.extend_from_slice(&[210, 215, 220, 255]);
                } else {
                    // Dark ground/buildings
                    img.extend_from_slice(&[40, 40, 45, 255]);
                }
            }
        }

        let detected = detect_sky(&img, w, h).expect("overcast sky should be detected");
        assert!(
            (detected.horizon_y - 0.41).abs() <= 0.05,
            "horizon_y was {}, expected within 0.41 +/- 0.05",
            detected.horizon_y
        );
        assert!(
            detected.blue_weight <= 0.50,
            "blue_weight was {}, expected <= 0.50 for overcast cloud",
            detected.blue_weight
        );
    }

    #[test]
    fn no_sky_indoor_fixture() {
        let (w, h) = (64, 64);
        // Uniform warm indoor studio/wall image (no sky characteristics)
        let img = [140u8, 95, 70, 255].repeat(w * h);

        let detected = detect_sky(&img, w, h);
        assert!(
            detected.is_none(),
            "indoor fixture should return None, got {:?}",
            detected
        );
    }

    #[test]
    fn inverted_linear_mask_brightens_opposite_side() {
        let src = grey(16, 16, 100);
        let normal_layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_LINEAR,
                params: vec![0.0, 0.0, 0.0, 1.0],
            },
            params: brighten(),
            inverted: false,
            amount: 1.0,
            ..Default::default()
        };
        let inverted_layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_LINEAR,
                params: vec![0.0, 0.0, 0.0, 1.0],
            },
            params: brighten(),
            inverted: true,
            amount: 1.0,
            ..Default::default()
        };
        let out_normal = apply_local(&src, 16, 16, &[normal_layer]);
        let out_inverted = apply_local(&src, 16, 16, &[inverted_layer]);

        let normal_top = out_normal[(16 + 8) * 4];
        let normal_bottom = out_normal[(15 * 16 + 8) * 4];
        assert!(normal_bottom > normal_top);

        let inverted_top = out_inverted[(16 + 8) * 4];
        let inverted_bottom = out_inverted[(15 * 16 + 8) * 4];
        assert!(
            inverted_top > inverted_bottom,
            "inverted linear mask brightens top instead of bottom: top={inverted_top}, bottom={inverted_bottom}"
        );
        assert!(inverted_top > 120);
        assert_eq!(inverted_bottom, 100);
    }

    #[test]
    fn inverted_mask_coverage_is_complement() {
        let src = grey(16, 16, 100);
        let normal_layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_RADIAL,
                params: vec![0.5, 0.5, 0.3, 0.3, 0.0],
            },
            params: brighten(),
            inverted: false,
            amount: 1.0,
            ..Default::default()
        };
        let inverted_layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_RADIAL,
                params: vec![0.5, 0.5, 0.3, 0.3, 0.0],
            },
            params: brighten(),
            inverted: true,
            amount: 1.0,
            ..Default::default()
        };
        let out_normal = apply_local(&src, 16, 16, &[normal_layer]);
        let out_inverted = apply_local(&src, 16, 16, &[inverted_layer]);

        // Inside center: normal is brightened, inverted is untouched
        let center_idx = (8 * 16 + 8) * 4;
        assert!(out_normal[center_idx] > 120);
        assert_eq!(out_inverted[center_idx], 100);

        // Outside corner: normal is untouched, inverted is brightened
        let corner_idx = 0;
        assert_eq!(out_normal[corner_idx], 100);
        assert!(out_inverted[corner_idx] > 120);
    }

    #[test]
    fn inverted_bitmap_mask_flips_coverage() {
        // 4x4 bitmap mask:
        // [0, 0, 255, 255]
        let bitmap_alphas = vec![
            0u8, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, 255,
        ];
        let inverted_layer = LocalAdjustment {
            mask: MaskSpec::bitmap(4, 4, &bitmap_alphas),
            params: brighten(),
            inverted: true,
            amount: 1.0,
            ..Default::default()
        };
        let src = grey(32, 32, 100);
        let out = apply_local(&src, 32, 32, &[inverted_layer]);

        // Left column (alpha=0, so inverted cov=1.0) is brightened (> 130)
        let left_px = out[(16 * 32) * 4];
        // Right column (alpha=255, so inverted cov=0.0) is untouched (== 100)
        let right_px = out[(16 * 32 + 31) * 4];

        assert!(
            left_px > 130,
            "inverted bitmap: left pixel with 0 alpha should brighten: {left_px}"
        );
        assert_eq!(
            right_px, 100,
            "inverted bitmap: right pixel with 255 alpha should be untouched: {right_px}"
        );
    }

    #[test]
    fn amount_zero_is_byte_identical_to_input() {
        let src = ramp(32, 32);
        let layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_RADIAL,
                params: vec![0.5, 0.5, 0.4, 0.4, 0.2],
            },
            params: brighten(),
            inverted: false,
            amount: 0.0,
            ..Default::default()
        };
        let out = apply_local(&src, 32, 32, &[layer]);
        assert_eq!(out, src, "amount=0.0 must be byte-identical to input");
    }

    #[test]
    fn amount_scales_per_pixel_delta_linearly_and_doubles_at_two() {
        let src = grey(16, 16, 100);
        let layer_full = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_RADIAL,
                params: vec![0.5, 0.5, 0.5, 0.5, 0.0],
            },
            params: GradeParams {
                exposure: 0.5,
                ..Default::default()
            },
            inverted: false,
            amount: 1.0,
            ..Default::default()
        };
        let layer_half = LocalAdjustment {
            amount: 0.5,
            ..layer_full.clone()
        };
        let layer_double = LocalAdjustment {
            amount: 2.0,
            ..layer_full.clone()
        };

        let out_full = apply_local(&src, 16, 16, &[layer_full]);
        let out_half = apply_local(&src, 16, 16, &[layer_half]);
        let out_double = apply_local(&src, 16, 16, &[layer_double]);

        let center_idx = (8 * 16 + 8) * 4;
        let base_val = 100.0f32;
        let delta_full = out_full[center_idx] as f32 - base_val;
        let delta_half = out_half[center_idx] as f32 - base_val;
        let delta_double = out_double[center_idx] as f32 - base_val;

        assert!(
            delta_full > 10.0,
            "full delta should be significant: {delta_full}"
        );
        // Half delta should be approximately half of full delta (+/- 1 due to rounding)
        assert!(
            (delta_half - delta_full * 0.5).abs() <= 1.5,
            "delta_half ({delta_half}) should be ~half of delta_full ({delta_full})"
        );
        // Double delta should be approximately double of full delta (+/- 1 due to rounding)
        assert!(
            (delta_double - delta_full * 2.0).abs() <= 1.5,
            "delta_double ({delta_double}) should be ~double of delta_full ({delta_full})"
        );
    }

    #[test]
    fn mask_group_add_combines_coverage() {
        let src = grey(32, 32, 100);
        let group_id = Some("test_group".to_string());
        let layer1 = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_RADIAL,
                params: vec![0.3, 0.5, 0.15, 0.15, 0.0],
            },
            params: brighten(),
            inverted: false,
            amount: 1.0,
            group_id: group_id.clone(),
            join_op: JOIN_ADD,
            group_inverted: false,
            group_amount: 1.0,
        };
        let layer2 = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_RADIAL,
                params: vec![0.7, 0.5, 0.15, 0.15, 0.0],
            },
            params: brighten(),
            inverted: false,
            amount: 1.0,
            group_id: group_id.clone(),
            join_op: JOIN_ADD,
            group_inverted: false,
            group_amount: 1.0,
        };
        let out = apply_local(&src, 32, 32, &[layer1, layer2]);
        // Point in circle 1: brightened
        let p1 = out[(16 * 32 + (0.3 * 32.0) as usize) * 4];
        // Point in circle 2: brightened
        let p2 = out[(16 * 32 + (0.7 * 32.0) as usize) * 4];
        // Point between them: untouched
        let p_mid = out[(16 * 32 + 16) * 4];
        assert!(p1 > 120, "circle 1 should brighten: {p1}");
        assert!(p2 > 120, "circle 2 should brighten: {p2}");
        assert_eq!(p_mid, 100, "point between circles untouched");
    }

    #[test]
    fn mask_group_subtract_removes_coverage() {
        let src = grey(32, 32, 100);
        let group_id = Some("sub_group".to_string());
        // Layer 1 covers left half (x=0 is 1.0, x=1 is 0.0)
        let layer_base = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_LINEAR,
                params: vec![1.0, 0.0, 0.0, 0.0],
            },
            params: brighten(),
            inverted: false,
            amount: 1.0,
            group_id: group_id.clone(),
            join_op: JOIN_ADD,
            group_inverted: false,
            group_amount: 1.0,
        };
        // Layer 2 subtracts a radial spot in bottom-left
        let layer_sub = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_RADIAL,
                params: vec![0.15, 0.85, 0.15, 0.15, 0.0],
            },
            params: brighten(),
            inverted: false,
            amount: 1.0,
            group_id: group_id.clone(),
            join_op: JOIN_SUBTRACT,
            group_inverted: false,
            group_amount: 1.0,
        };
        let out = apply_local(&src, 32, 32, &[layer_base, layer_sub]);
        // Point in top-left (linear without subtracted radial): brightened
        let p_top_left = out[(4 * 32 + 4) * 4];
        // Point in bottom-left (subtracted): untouched
        let p_bot_left = out[(27 * 32 + 4) * 4];
        assert!(
            p_top_left > 120,
            "non-subtracted region brightened: {p_top_left}"
        );
        assert_eq!(p_bot_left, 100, "subtracted region untouched: {p_bot_left}");
    }

    #[test]
    fn mask_group_intersect_multiplies_coverage() {
        let src = grey(32, 32, 100);
        let group_id = Some("intersect_group".to_string());
        // Linear 1: top half (bright at y=0)
        let layer1 = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_LINEAR,
                params: vec![0.0, 1.0, 0.0, 0.0],
            },
            params: brighten(),
            inverted: false,
            amount: 1.0,
            group_id: group_id.clone(),
            join_op: JOIN_ADD,
            group_inverted: false,
            group_amount: 1.0,
        };
        // Linear 2: left half (bright at x=0)
        let layer2 = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_LINEAR,
                params: vec![1.0, 0.0, 0.0, 0.0],
            },
            params: brighten(),
            inverted: false,
            amount: 1.0,
            group_id: group_id.clone(),
            join_op: JOIN_INTERSECT,
            group_inverted: false,
            group_amount: 1.0,
        };
        let out = apply_local(&src, 32, 32, &[layer1, layer2]);
        // Top-left: both are ~1.0 -> 1.0 * 1.0 = 1.0 (brightened)
        let top_left = out[(2 * 32 + 2) * 4];
        // Top-right: ~1.0 * 0.0 = 0.0 (untouched)
        let top_right = out[(2 * 32 + 30) * 4];
        // Bottom-left: 0.0 * ~1.0 = 0.0 (untouched)
        let bottom_left = out[(30 * 32 + 2) * 4];
        // Bottom-right: 0.0 * 0.0 = 0.0 (untouched)
        let bottom_right = out[(30 * 32 + 30) * 4];

        assert!(top_left > 120, "intersection brightened: {top_left}");
        assert_eq!(top_right, 100, "top-right untouched");
        assert_eq!(bottom_left, 100, "bottom-left untouched");
        assert_eq!(bottom_right, 100, "bottom-right untouched");
    }

    #[test]
    fn mask_group_invert_inverts_composite_coverage() {
        let src = grey(32, 32, 100);
        let group_id = Some("inv_group".to_string());
        let layer = LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_RADIAL,
                params: vec![0.5, 0.5, 0.3, 0.3, 0.0],
            },
            params: brighten(),
            inverted: false,
            amount: 1.0,
            group_id: group_id.clone(),
            join_op: JOIN_ADD,
            group_inverted: true,
            group_amount: 1.0,
        };
        let out = apply_local(&src, 32, 32, &[layer]);
        // Center: inside radial, but group inverted -> untouched
        let center = out[(16 * 32 + 16) * 4];
        // Corner: outside radial, group inverted -> brightened
        let corner = out[0];
        assert_eq!(center, 100, "center inverted to untouched");
        assert!(corner > 120, "corner inverted to brightened: {corner}");
    }

    #[test]
    fn mask_group_amount_scales_composite_coverage() {
        let src = grey(16, 16, 100);
        let group_id = Some("amt_group".to_string());
        let mk_group = |grp_amt: f32| LocalAdjustment {
            mask: MaskSpec {
                kind: MASK_RADIAL,
                params: vec![0.5, 0.5, 0.5, 0.5, 0.0],
            },
            params: GradeParams {
                exposure: 0.5,
                ..Default::default()
            },
            inverted: false,
            amount: 1.0,
            group_id: group_id.clone(),
            join_op: JOIN_ADD,
            group_inverted: false,
            group_amount: grp_amt,
        };

        let out_zero = apply_local(&src, 16, 16, &[mk_group(0.0)]);
        let out_half = apply_local(&src, 16, 16, &[mk_group(0.5)]);
        let out_full = apply_local(&src, 16, 16, &[mk_group(1.0)]);
        let out_double = apply_local(&src, 16, 16, &[mk_group(2.0)]);

        assert_eq!(out_zero, src, "group amount 0 is identity");

        let center_idx = (8 * 16 + 8) * 4;
        let delta_half = out_half[center_idx] as f32 - 100.0;
        let delta_full = out_full[center_idx] as f32 - 100.0;
        let delta_double = out_double[center_idx] as f32 - 100.0;

        assert!(delta_full > 10.0);
        assert!((delta_half - delta_full * 0.5).abs() <= 1.5);
        assert!((delta_double - delta_full * 2.0).abs() <= 1.5);
    }

    #[test]
    fn test_rasterize_mask() {
        // 32x32 radial mask centered at (0.5, 0.5) with radius 0.25, feather 0.0
        let p = vec![0.5, 0.5, 0.25, 0.25, 0.0];
        let alphas = rasterize_mask(MASK_RADIAL, &p, 32, 32, None);
        assert_eq!(alphas.len(), 32 * 32);

        // Center pixel (16, 16) is inside
        let center_idx = 16 * 32 + 16;
        assert_eq!(alphas[center_idx], 1.0);

        // Corner pixel (0, 0) is outside
        assert_eq!(alphas[0], 0.0);
    }

    #[test]
    fn test_refine_mask_guided_aligns_to_step_edge() {
        let w = 32;
        let h = 32;
        // Image with dark background on left (x < 16) and bright foreground on right (x >= 16)
        let mut rgba = vec![0u8; w * h * 4];
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                let val = if x < 16 { 25 } else { 230 };
                rgba[idx] = val;
                rgba[idx + 1] = val;
                rgba[idx + 2] = val;
                rgba[idx + 3] = 255;
            }
        }

        // Initial mask with a fuzzy linear transition ramp across x = 8..24
        let mut initial_mask = vec![0.0f32; w * h];
        for y in 0..h {
            for x in 0..w {
                let idx = y * w + x;
                initial_mask[idx] = if x < 8 {
                    0.0
                } else if x >= 24 {
                    1.0
                } else {
                    (x as f32 - 8.0) / 16.0
                };
            }
        }

        let refined = refine_mask_guided(&rgba, w, h, &initial_mask, &[], 0.05, 4, 0.005);
        assert_eq!(refined.len(), w * h);

        // At y = 16, x = 14 (dark background side): refined alpha should be pulled lower than initial
        let idx_dark = 16 * w + 14;
        assert!(
            refined[idx_dark] < initial_mask[idx_dark],
            "refined on dark side ({}) should be lower than initial ({})",
            refined[idx_dark],
            initial_mask[idx_dark]
        );

        // At y = 16, x = 18 (bright foreground side): refined alpha should be pulled higher than initial
        let idx_bright = 16 * w + 18;
        assert!(
            refined[idx_bright] > initial_mask[idx_bright],
            "refined on bright side ({}) should be higher than initial ({})",
            refined[idx_bright],
            initial_mask[idx_bright]
        );

        // Pure background (x = 2) and pure foreground (x = 30) stay clean
        assert_eq!(refined[16 * w + 2], 0.0);
        assert_eq!(refined[16 * w + 30], 1.0);
    }

    #[test]
    fn test_refine_mask_guided_with_brush_stroke() {
        let w = 32;
        let h = 32;
        let mut rgba = vec![0u8; w * h * 4];
        for y in 0..h {
            for x in 0..w {
                let idx = (y * w + x) * 4;
                let val = if x < 16 { 25 } else { 230 };
                rgba[idx] = val;
                rgba[idx + 1] = val;
                rgba[idx + 2] = val;
                rgba[idx + 3] = 255;
            }
        }

        let mut initial_mask = vec![0.0f32; w * h];
        for y in 0..h {
            for x in 0..w {
                let idx = y * w + x;
                initial_mask[idx] = if x < 8 {
                    0.0
                } else if x >= 24 {
                    1.0
                } else {
                    (x as f32 - 8.0) / 16.0
                };
            }
        }

        // Brush stroke only over top-left region around (u=0.45, v=0.2)
        let stroke_points = vec![0.45, 0.15, 0.45, 0.25];
        let brush_radius = 0.15;

        let refined = refine_mask_guided(
            &rgba,
            w,
            h,
            &initial_mask,
            &stroke_points,
            brush_radius,
            4,
            0.005,
        );

        // In brushed region (e.g. y = 6, x = 14), alpha changed
        let idx_brushed = 6 * w + 14;
        assert!((refined[idx_brushed] - initial_mask[idx_brushed]).abs() > 1e-4);

        // In distant unbrushed region (e.g. bottom half, y = 28, x = 14), alpha is unchanged!
        let idx_unbrushed = 28 * w + 14;
        assert_eq!(
            refined[idx_unbrushed], initial_mask[idx_unbrushed],
            "unbrushed region must remain completely untouched"
        );
    }

    #[test]
    fn test_detect_subject_centered_figure() {
        let w = 40;
        let h = 40;
        let mut rgba = vec![30u8; w * h * 4]; // Dark background (30)

        // Draw bright salient subject (220) around center (x=20, y=20)
        for y in 12..28 {
            for x in 12..28 {
                let idx = (y * w + x) * 4;
                rgba[idx] = 220;
                rgba[idx + 1] = 210;
                rgba[idx + 2] = 200;
                rgba[idx + 3] = 255;
            }
        }

        let detected = detect_subject(&rgba, w, h).expect("subject detected");
        assert!(
            (detected.cx - 0.5).abs() < 0.05,
            "cx near center: {}",
            detected.cx
        );
        assert!(
            (detected.cy - 0.5).abs() < 0.05,
            "cy near center: {}",
            detected.cy
        );
        assert!(detected.rx > 0.15 && detected.rx < 0.45);
        assert!(detected.ry > 0.15 && detected.ry < 0.45);
    }

    #[test]
    fn test_detect_subject_off_center_figure() {
        let w = 40;
        let h = 40;
        let mut rgba = vec![40u8; w * h * 4];

        // Draw bright salient subject in left third (x=10, y=14)
        for y in 8..20 {
            for x in 6..16 {
                let idx = (y * w + x) * 4;
                rgba[idx] = 240;
                rgba[idx + 1] = 230;
                rgba[idx + 2] = 220;
                rgba[idx + 3] = 255;
            }
        }

        let detected = detect_subject(&rgba, w, h).expect("subject detected");
        // cx should shift towards 0.25 - 0.35
        assert!(
            detected.cx < 0.42,
            "cx pulled towards left: {}",
            detected.cx
        );
        assert!(detected.cy < 0.45, "cy pulled towards top: {}", detected.cy);
    }

    #[test]
    fn test_detect_subject_uniform_fallback() {
        let w = 32;
        let h = 32;
        let rgba = vec![128u8; w * h * 4];
        let detected = detect_subject(&rgba, w, h).expect("fallback detected");
        assert_eq!(detected.cx, 0.5);
        assert_eq!(detected.cy, 0.5);
    }
}
