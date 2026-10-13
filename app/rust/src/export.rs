//! CPU grading + JPEG encode — the export path (P1/P2 Slice D).
//!
//! Grading reuses [`crate::color`] — the *same* colour pipeline Rust bakes into
//! the preview 3D LUT — so preview and export agree by construction
//! (ARCHITECTURE §8/§16).

use jpeg_encoder::{ColorType, Encoder};

use crate::color;

/// Grades [rgba] (RGBA8, `width*height*4` bytes) on the CPU and encodes a JPEG.
///
/// Alpha is dropped (JPEG has no alpha). [exposure] is in EV; [contrast] and
/// [saturation] are unitless around 0.
pub fn encode_jpeg(
    rgba: &[u8],
    width: u32,
    height: u32,
    quality: u8,
    exposure: f32,
    contrast: f32,
    saturation: f32,
) -> Result<Vec<u8>, String> {
    if width == 0 || height == 0 {
        return Err("export dimensions must be at least 1x1".to_string());
    }
    // JPEG dimensions are u16-bounded; refuse anything that cannot be encoded.
    if width > u16::MAX as u32 || height > u16::MAX as u32 {
        return Err(format!(
            "export dimensions {width}x{height} exceed the JPEG limit of {}",
            u16::MAX
        ));
    }
    let expected = width as usize * height as usize * 4;
    if rgba.len() != expected {
        return Err(format!(
            "rgba buffer has {} bytes, expected {expected} for {width}x{height}",
            rgba.len()
        ));
    }

    let params = color::GradeParams {
        exposure,
        contrast,
        saturation,
        ..Default::default()
    };
    let mut rgb = Vec::with_capacity(width as usize * height as usize * 3);
    for px in rgba.as_chunks::<4>().0 {
        let c = color::grade_pixel_srgb(
            px[0] as f32 / 255.0,
            px[1] as f32 / 255.0,
            px[2] as f32 / 255.0,
            params,
        );
        rgb.push((c[0] * 255.0 + 0.5) as u8);
        rgb.push((c[1] * 255.0 + 0.5) as u8);
        rgb.push((c[2] * 255.0 + 0.5) as u8);
    }

    let mut out = Vec::new();
    Encoder::new(&mut out, quality)
        .encode(&rgb, width as u16, height as u16, ColorType::Rgb)
        .map_err(|e| format!("jpeg encode failed: {e}"))?;
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A solid RGBA fill of `n` pixels.
    fn solid_rgba(width: u32, height: u32, r: u8, g: u8, b: u8) -> Vec<u8> {
        let mut v = Vec::with_capacity(width as usize * height as usize * 4);
        for _ in 0..width * height {
            v.extend_from_slice(&[r, g, b, 255]);
        }
        v
    }

    /// Mean luma of a decoded JPEG, in 0..=255.
    fn mean_luma(jpeg: &[u8]) -> f64 {
        let img = crate::decode::decode_rgba(jpeg).unwrap();
        let n = (img.rgba.len() / 4) as f64;
        let sum: f64 = img
            .rgba
            .as_chunks::<4>()
            .0
            .iter()
            .map(|p| 0.2126 * p[0] as f64 + 0.7152 * p[1] as f64 + 0.0722 * p[2] as f64)
            .sum();
        sum / n
    }

    fn encode(
        rgba: &[u8],
        w: u32,
        h: u32,
        exposure: f32,
        contrast: f32,
        saturation: f32,
    ) -> Vec<u8> {
        encode_jpeg(rgba, w, h, 95, exposure, contrast, saturation).unwrap()
    }

    #[test]
    fn neutral_export_preserves_brightness_within_jpeg_tolerance() {
        let src = solid_rgba(32, 32, 128, 128, 128);
        let jpeg = encode(&src, 32, 32, 0.0, 0.0, 0.0);
        // Solid mid-grey should survive a high-quality JPEG nearly intact.
        assert!(
            (mean_luma(&jpeg) - 128.0).abs() < 6.0,
            "neutral export drifted too far from the source"
        );
    }

    #[test]
    fn exposure_brightens_and_negative_exposure_darkens() {
        let src = solid_rgba(32, 32, 96, 96, 96);
        let neutral = mean_luma(&encode(&src, 32, 32, 0.0, 0.0, 0.0));
        let brighter = mean_luma(&encode(&src, 32, 32, 1.0, 0.0, 0.0));
        let darker = mean_luma(&encode(&src, 32, 32, -1.0, 0.0, 0.0));

        assert!(
            brighter > neutral,
            "exposure must brighten ({brighter} !> {neutral})"
        );
        assert!(
            darker < neutral,
            "negative exposure must darken ({darker} !< {neutral})"
        );
    }

    #[test]
    fn saturation_on_a_grey_source_is_a_no_op() {
        // mix(luma, col, s) == col when col == luma, so grey must not shift.
        let src = solid_rgba(16, 16, 140, 140, 140);
        let neutral = mean_luma(&encode(&src, 16, 16, 0.0, 0.0, 0.0));
        let saturated = mean_luma(&encode(&src, 16, 16, 0.0, 0.0, 1.0));
        assert!((saturated - neutral).abs() < 4.0);
    }

    #[test]
    fn lower_quality_produces_a_smaller_file() {
        // A noisy gradient so JPEG size actually varies with quality.
        let mut src = Vec::new();
        for y in 0..64 {
            for x in 0..64 {
                src.extend_from_slice(&[(x * 3 + y) as u8, (x ^ y) as u8, (x + y * 2) as u8, 255]);
            }
        }
        let hi = encode_jpeg(&src, 64, 64, 95, 0.0, 0.0, 0.0).unwrap();
        let lo = encode_jpeg(&src, 64, 64, 20, 0.0, 0.0, 0.0).unwrap();
        assert!(
            lo.len() < hi.len(),
            "quality 20 ({}) should beat 95 ({})",
            lo.len(),
            hi.len()
        );
    }

    #[test]
    fn rejects_a_mismatched_buffer_length() {
        let err = encode_jpeg(&[0u8; 9], 2, 2, 90, 0.0, 0.0, 0.0).unwrap_err();
        assert!(err.contains("expected 16"), "got: {err}");
    }

    #[test]
    fn rejects_zero_dimensions() {
        assert!(encode_jpeg(&[], 0, 10, 90, 0.0, 0.0, 0.0).is_err());
        assert!(encode_jpeg(&[], 10, 0, 90, 0.0, 0.0, 0.0).is_err());
    }

    #[test]
    fn drops_alpha_without_panicking() {
        let src = solid_rgba(8, 8, 200, 100, 50);
        let jpeg = encode(&src, 8, 8, 0.0, 0.0, 0.0);
        let (w, h) = crate::decode::dimensions(&jpeg).unwrap();
        assert_eq!((w, h), (8, 8));
    }
}
