//! JPEG encode — the final export step. Pure: grading lives in [`crate::color`].
//!
//! The export path grades via `color::grade_pixel_c` (the same pipeline —
//! including tone curves — the preview LUT bakes) and then encodes here, so
//! preview and export share the exact colour math.

use jpeg_encoder::{ColorType, Encoder};

/// Encodes an RGBA8 buffer (`width*height*4`) as a JPEG, dropping alpha.
pub fn encode_jpeg(rgba: &[u8], width: u32, height: u32, quality: u8) -> Result<Vec<u8>, String> {
    if width == 0 || height == 0 {
        return Err("export dimensions must be at least 1x1".to_string());
    }
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

    let mut rgb = Vec::with_capacity(width as usize * height as usize * 3);
    for px in rgba.as_chunks::<4>().0 {
        rgb.extend_from_slice(&[px[0], px[1], px[2]]);
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

    fn solid_rgba(width: u32, height: u32, r: u8, g: u8, b: u8) -> Vec<u8> {
        let mut v = Vec::with_capacity(width as usize * height as usize * 4);
        for _ in 0..width * height {
            v.extend_from_slice(&[r, g, b, 255]);
        }
        v
    }

    #[test]
    fn lower_quality_produces_a_smaller_file() {
        let mut src = Vec::new();
        for y in 0..64 {
            for x in 0..64 {
                src.extend_from_slice(&[(x * 3 + y) as u8, (x ^ y) as u8, (x + y * 2) as u8, 255]);
            }
        }
        let hi = encode_jpeg(&src, 64, 64, 95).unwrap();
        let lo = encode_jpeg(&src, 64, 64, 20).unwrap();
        assert!(
            lo.len() < hi.len(),
            "quality 20 ({}) should beat 95 ({})",
            lo.len(),
            hi.len()
        );
    }

    #[test]
    fn rejects_a_mismatched_buffer_length() {
        let err = encode_jpeg(&[0u8; 9], 2, 2, 90).unwrap_err();
        assert!(err.contains("expected 16"), "got: {err}");
    }

    #[test]
    fn rejects_zero_dimensions() {
        assert!(encode_jpeg(&[], 0, 10, 90).is_err());
        assert!(encode_jpeg(&[], 10, 0, 90).is_err());
    }

    #[test]
    fn encodes_a_decodable_jpeg_and_drops_alpha() {
        let jpeg = encode_jpeg(&solid_rgba(8, 8, 200, 100, 50), 8, 8, 90).unwrap();
        assert_eq!(crate::decode::dimensions(&jpeg).unwrap(), (8, 8));
    }

    #[test]
    fn round_trips_colour_within_jpeg_tolerance() {
        let jpeg = encode_jpeg(&solid_rgba(32, 32, 128, 128, 128), 32, 32, 95).unwrap();
        let img = crate::decode::decode_rgba(&jpeg).unwrap();
        let mean = img
            .rgba
            .as_chunks::<4>()
            .0
            .iter()
            .map(|p| p[0] as f64)
            .sum::<f64>()
            / (img.rgba.len() / 4) as f64;
        assert!((mean - 128.0).abs() < 4.0, "mean {mean}");
    }
}
