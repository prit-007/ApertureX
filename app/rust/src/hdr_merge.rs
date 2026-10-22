//! HDR multi-exposure merge (Issue #20).
//!
//! Takes N bracketed exposures (RGBA8 + EV offsets) and merges them into a
//! single linear HDR radiance map (f32 RGB per pixel), then optionally bakes
//! into an Ultra HDR JPEG (SDR base + ISO 21496-1 gain map).

use crate::color::{linear_to_srgb, srgb_to_linear};

/// One bracketed exposure: RGBA8 pixels + EV offset in stops.
#[derive(Debug, Clone)]
pub struct HdrExposure {
    pub rgba: Vec<u8>,
    pub width: usize,
    pub height: usize,
    /// Exposure value in stops relative to the base (0.0). Negative = darker,
    /// positive = brighter. EV of 1.0 = 2x more light.
    pub ev: f32,
}

/// Merges bracketed exposures into a linear HDR radiance map (f32 RGB per pixel).
///
/// Uses exposure-weighted averaging (Debevec-style): each pixel's radiance is
/// a weighted sum of the per-exposure linear values, weighted by a Gaussian
/// around middle gray (0.18). Underexposed pixels are trusted more in bright
/// regions, overexposed pixels in dark regions.
///
/// Returns `Vec<f32>` of length `width * height * 3` in linear RGB.
pub fn merge_exposures(exposures: &[HdrExposure]) -> Result<Vec<f32>, String> {
    if exposures.is_empty() {
        return Err("at least one exposure required".to_string());
    }

    let w = exposures[0].width;
    let h = exposures[0].height;

    // Validate all exposures have same dimensions
    for e in exposures {
        if e.width != w || e.height != h {
            return Err("all exposures must have same dimensions".to_string());
        }
    }

    let n_px = w * h;
    let mut radiance = vec![0.0f32; n_px * 3];
    let mut weight_sum_r = vec![0.0f32; n_px];
    let mut weight_sum_g = vec![0.0f32; n_px];
    let mut weight_sum_b = vec![0.0f32; n_px];

    // Middle gray reference for weight curve
    const MID_GRAY: f32 = 0.18;
    const WEIGHT_SIGMA: f32 = 0.45; // width of the weight curve

    for exp in exposures {
        let ev_factor = 2f32.powf(-exp.ev); // divide by 2^ev to get linear scene radiance

        for py in 0..h {
            for px in 0..w {
                let idx = (py * w + px) * 4;
                let r = srgb_to_linear(exp.rgba[idx] as f32 / 255.0);
                let g = srgb_to_linear(exp.rgba[idx + 1] as f32 / 255.0);
                let b = srgb_to_linear(exp.rgba[idx + 2] as f32 / 255.0);

                // Scene radiance = sensor value / 2^ev
                let scene_r = r * ev_factor;
                let scene_g = g * ev_factor;
                let scene_b = b * ev_factor;

                // Weight: Gaussian around middle gray, per-channel
                let w_r = ((scene_r - MID_GRAY).powi(2) / (2.0 * WEIGHT_SIGMA.powi(2))).exp();
                let w_g = ((scene_g - MID_GRAY).powi(2) / (2.0 * WEIGHT_SIGMA.powi(2))).exp();
                let w_b = ((scene_b - MID_GRAY).powi(2) / (2.0 * WEIGHT_SIGMA.powi(2))).exp();

                let ri = py * w + px;
                radiance[ri * 3] += scene_r * w_r;
                radiance[ri * 3 + 1] += scene_g * w_g;
                radiance[ri * 3 + 2] += scene_b * w_b;
                weight_sum_r[ri] += w_r;
                weight_sum_g[ri] += w_g;
                weight_sum_b[ri] += w_b;
            }
        }
    }

    // Normalize each channel by its own weight sum
    for i in 0..n_px {
        let wr = weight_sum_r[i].max(1e-6);
        let wg = weight_sum_g[i].max(1e-6);
        let wb = weight_sum_b[i].max(1e-6);
        radiance[i * 3] /= wr;
        radiance[i * 3 + 1] /= wg;
        radiance[i * 3 + 2] /= wb;
    }

    Ok(radiance)
}

/// Tone-maps linear HDR radiance to SDR RGBA8 using a simple Reinhard tone map.
pub fn tone_map_to_sdr(radiance: &[f32], width: usize, height: usize) -> Vec<u8> {
    let mut sdr = vec![0u8; width * height * 4];

    for i in 0..(width * height) {
        let r = radiance[i * 3];
        let g = radiance[i * 3 + 1];
        let b = radiance[i * 3 + 2];

        // Reinhard: L / (1 + L)
        let tr = r / (1.0 + r);
        let tg = g / (1.0 + g);
        let tb = b / (1.0 + b);

        let ri = i * 4;
        sdr[ri] = linear_to_srgb(tr.clamp(0.0, 1.0)) as u8 * 255;
        sdr[ri + 1] = linear_to_srgb(tg.clamp(0.0, 1.0)) as u8 * 255;
        sdr[ri + 2] = linear_to_srgb(tb.clamp(0.0, 1.0)) as u8 * 255;
        sdr[ri + 3] = 255;
    }

    sdr
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_exposure(rgba: &[u8], w: usize, h: usize, ev: f32) -> HdrExposure {
        HdrExposure {
            rgba: rgba.to_vec(),
            width: w,
            height: h,
            ev,
        }
    }

    #[test]
    fn merge_single_exposure_is_identity() {
        // Single exposure at EV 0: output should equal linearized input
        let exp = make_exposure(
            &[255, 128, 64, 255, 0, 255, 0, 255, 0, 0, 255, 255],
            1,
            3,
            0.0,
        );
        let out = merge_exposures(&[exp]).unwrap();

        // Pixel 0: (255,128,64) -> linear
        assert!((out[0] - srgb_to_linear(1.0)).abs() < 1e-4);
        assert!((out[1] - srgb_to_linear(128.0 / 255.0)).abs() < 1e-4);
        assert!((out[2] - srgb_to_linear(64.0 / 255.0)).abs() < 1e-4);
        // Pixel 1: (0,255,0) -> linear
        assert!((out[3] - srgb_to_linear(0.0)).abs() < 1e-4);
        assert!((out[4] - srgb_to_linear(1.0)).abs() < 1e-4);
        assert!((out[5] - srgb_to_linear(0.0)).abs() < 1e-4);
        // Pixel 2: (0,0,255) -> linear
        assert!((out[6] - srgb_to_linear(0.0)).abs() < 1e-4);
        assert!((out[7] - srgb_to_linear(0.0)).abs() < 1e-4);
        assert!((out[8] - srgb_to_linear(1.0)).abs() < 1e-4);
    }

    #[test]
    fn merge_rejects_empty() {
        let err = merge_exposures(&[]).unwrap_err();
        assert!(err.contains("at least one"));
    }

    #[test]
    fn merge_rejects_mismatched_dims() {
        let e1 = make_exposure(&[255; 4], 2, 2, 0.0);
        let e2 = make_exposure(&[255; 16], 4, 4, 0.0);
        let err = merge_exposures(&[e1, e2]).unwrap_err();
        assert!(err.contains("same dimensions"));
    }

    #[test]
    fn merge_brightens_underexposed() {
        // Same scene at EV -2 (dark) and EV +2 (bright). The merged result
        // should preserve detail: bright areas from the dark exposure, dark
        // areas from the bright exposure.
        let dark_rgba = [10, 10, 10, 255]; // very dark
        let bright_rgba = [240, 240, 240, 255]; // very bright

        let dark = make_exposure(&dark_rgba, 1, 1, -2.0);
        let bright = make_exposure(&bright_rgba, 1, 1, 2.0);

        let out = merge_exposures(&[dark, bright]).unwrap();

        // At EV -2, scene radiance = 10/255 / 2^-2 = 10/255 * 4 ≈ 0.157 linear
        // At EV +2, scene radiance = 240/255 / 2^2 = 240/255 / 4 ≈ 0.235 linear
        // Weighted average should be somewhere in between, closer to mid-gray
        let lum = 0.2126 * out[0] + 0.7152 * out[1] + 0.0722 * out[2];
        assert!(
            lum > 0.1,
            "merged luminance should be above pure dark: {lum}"
        );
        assert!(lum < 0.5, "merged luminance should be below bright: {lum}");
    }

    #[test]
    fn tone_map_clamps_to_sdr_range() {
        let radiance = vec![
            0.0, 0.0, 0.0, // black
            100.0, 100.0, 100.0, // very bright
            1.0, 0.0, 0.0, // red
        ];
        let sdr = tone_map_to_sdr(&radiance, 3, 1);

        // Black should map to ~0
        assert_eq!(sdr[0], 0);
        assert_eq!(sdr[1], 0);
        assert_eq!(sdr[2], 0);

        // Black should map to ~0
        assert_eq!(sdr[0], 0);
        assert_eq!(sdr[1], 0);
        assert_eq!(sdr[2], 0);

        // Bright pixels should map to non-zero
        assert!(sdr[3] > 0 || sdr[4] > 0 || sdr[5] > 0);
    }

    #[test]
    fn merge_preserves_hdr_range() {
        // Two exposures of a bright highlight: one underexposed (preserves detail),
        // one overexposed (clipped). The merge should recover the bright value.
        let underexposed = make_exposure(&[100, 100, 100, 255], 1, 1, -2.0);
        let overexposed = make_exposure(&[255, 255, 255, 255], 1, 1, 2.0);

        let out = merge_exposures(&[underexposed, overexposed]).unwrap();

        // Underexposed: scene = 100/255 * 4 = 1.569 linear
        // Overexposed: scene = 255/255 / 4 = 0.25 linear (clipped sensor, unreliable)
        // The merged result should be between the two exposure values
        assert!(
            out[0] > 0.25,
            "merged should be > overexposed value: {}",
            out[0]
        );
        assert!(
            out[0] < 1.57,
            "merged should be < underexposed value: {}",
            out[0]
        );
    }
}
