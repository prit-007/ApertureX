//! JPEG decode core: header/dimension reads, full RGBA decode, and ROI crop.
//!
//! This is the `ImageSource` decode path for JPEG (ARCHITECTURE §7). The real
//! platform ROI decoders (`BitmapRegionDecoder` / `CGImageSource`) can replace
//! the decode+crop strategy later without changing the call surface; for now we
//! decode with `zune-jpeg` and crop the requested region in Rust, which keeps the
//! whole path memory-safe and testable off-device.

use std::io::Cursor;

use zune_jpeg::{
    zune_core::{colorspace::ColorSpace, options::DecoderOptions},
    JpegDecoder,
};

/// A fully decoded RGBA8 image.
pub struct DecodedImage {
    pub width: usize,
    pub height: usize,
    /// RGBA8 pixels, length always `width * height * 4`.
    pub rgba: Vec<u8>,
}

/// Reads the JPEG dimensions without producing a pixel buffer.
pub fn dimensions(data: &[u8]) -> Result<(usize, usize), String> {
    let mut decoder = JpegDecoder::new(Cursor::new(data));
    decoder
        .decode_headers()
        .map_err(|e| format!("jpeg header: {e:?}"))?;
    let info = decoder.info().ok_or("jpeg: no image info")?;
    Ok((info.width as usize, info.height as usize))
}

/// Decodes a JPEG into a full RGBA8 buffer.
pub fn decode_rgba(data: &[u8]) -> Result<DecodedImage, String> {
    let options = DecoderOptions::new_safe().jpeg_set_out_colorspace(ColorSpace::RGBA);
    let mut decoder = JpegDecoder::new_with_options(Cursor::new(data), options);
    let rgba = decoder
        .decode()
        .map_err(|e| format!("jpeg decode: {e:?}"))?;
    let info = decoder.info().ok_or("jpeg: no image info after decode")?;

    let width = info.width as usize;
    let height = info.height as usize;
    let expected = width
        .checked_mul(height)
        .and_then(|n| n.checked_mul(4))
        .ok_or("jpeg: dimensions overflow")?;
    if rgba.len() != expected {
        return Err(format!(
            "jpeg: decoded {} bytes, expected {expected}",
            rgba.len()
        ));
    }
    Ok(DecodedImage {
        width,
        height,
        rgba,
    })
}

/// Crops an RGBA image to the region `(x, y, width, height)`.
///
/// The region must lie fully inside the source image; it is copied losslessly
/// out of an already-decoded buffer.
pub fn crop_rgba(
    img: &DecodedImage,
    x: usize,
    y: usize,
    width: usize,
    height: usize,
) -> Result<DecodedImage, String> {
    if x.saturating_add(width) > img.width || y.saturating_add(height) > img.height {
        return Err(format!(
            "crop rect ({x},{y},{width},{height}) outside {}x{} image",
            img.width, img.height
        ));
    }
    let mut out = vec![0u8; width * height * 4];
    for row in 0..height {
        let src = ((y + row) * img.width + x) * 4;
        let dst = row * width * 4;
        out[dst..dst + width * 4].copy_from_slice(&img.rgba[src..src + width * 4]);
    }
    Ok(DecodedImage {
        width,
        height,
        rgba: out,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use jpeg_encoder::{ColorType, Encoder};

    fn solid_rgb(width: u16, height: u16, r: u8, g: u8, b: u8) -> Vec<u8> {
        let mut px = Vec::with_capacity(width as usize * height as usize * 3);
        for _ in 0..(width as usize * height as usize) {
            px.extend_from_slice(&[r, g, b]);
        }
        px
    }

    fn encode_test_jpeg(width: u16, height: u16, rgb: &[u8]) -> Vec<u8> {
        let mut out = Vec::new();
        Encoder::new(&mut out, 100)
            .encode(rgb, width, height, ColorType::Rgb)
            .expect("encode test jpeg");
        out
    }

    #[test]
    fn dimensions_round_trip() {
        let jpeg = encode_test_jpeg(64, 48, &solid_rgb(64, 48, 10, 20, 30));
        assert_eq!(dimensions(&jpeg).unwrap(), (64, 48));
    }

    #[test]
    fn dimensions_reject_garbage() {
        assert!(dimensions(b"not a jpeg at all").is_err());
    }

    #[test]
    fn decode_rgba_produces_expected_size_and_opaque_alpha() {
        let jpeg = encode_test_jpeg(32, 16, &solid_rgb(32, 16, 200, 40, 60));
        let img = decode_rgba(&jpeg).unwrap();
        assert_eq!(img.width, 32);
        assert_eq!(img.height, 16);
        assert_eq!(img.rgba.len(), 32 * 16 * 4);

        // Centre pixel should be close to the solid source (JPEG is lossy).
        let idx = (8 * 32 + 16) * 4;
        let (r, g, b, a) = (
            img.rgba[idx],
            img.rgba[idx + 1],
            img.rgba[idx + 2],
            img.rgba[idx + 3],
        );
        assert_eq!(a, 255, "alpha should be opaque");
        assert!(r.abs_diff(200) <= 8, "r={r}");
        assert!(g.abs_diff(40) <= 8, "g={g}");
        assert!(b.abs_diff(60) <= 8, "b={b}");
    }

    #[test]
    fn crop_returns_exact_subregion_of_full_decode() {
        let (w, h) = (40u16, 30u16);
        let mut rgb = Vec::new();
        for y in 0..h {
            for x in 0..w {
                rgb.extend_from_slice(&[(x * 5) as u8, (y * 7) as u8, (x + y) as u8]);
            }
        }
        let jpeg = encode_test_jpeg(w, h, &rgb);
        let full = decode_rgba(&jpeg).unwrap();

        let (cx, cy, cw, ch) = (10usize, 5usize, 12usize, 9usize);
        let cropped = crop_rgba(&full, cx, cy, cw, ch).unwrap();
        assert_eq!(cropped.width, cw);
        assert_eq!(cropped.height, ch);

        // Crop is a lossless copy out of the decoded buffer, so it must match a
        // manual extraction exactly.
        for row in 0..ch {
            for col in 0..cw {
                let src = ((cy + row) * full.width + (cx + col)) * 4;
                let dst = (row * cw + col) * 4;
                assert_eq!(
                    cropped.rgba[dst..dst + 4],
                    full.rgba[src..src + 4],
                    "mismatch at cropped ({col},{row})"
                );
            }
        }
    }

    #[test]
    fn crop_accepts_exact_fit_but_rejects_out_of_bounds() {
        let jpeg = encode_test_jpeg(20, 20, &solid_rgb(20, 20, 0, 0, 0));
        let full = decode_rgba(&jpeg).unwrap();
        assert!(crop_rgba(&full, 0, 0, 20, 20).is_ok());
        assert!(crop_rgba(&full, 0, 0, 21, 5).is_err());
        assert!(crop_rgba(&full, 15, 15, 10, 10).is_err());
        assert!(crop_rgba(&full, 1, 1, 0, 0).is_ok()); // degenerate but in-bounds
    }
}
