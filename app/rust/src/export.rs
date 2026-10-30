//! JPEG encode — the final export step. Pure: grading lives in [`crate::color`].
//!
//! The export path grades via `color::grade_pixel_c` (the same pipeline —
//! including tone curves — the preview LUT bakes) and then encodes here, so
//! preview and export share the exact colour math.

use jpeg_encoder::{ColorType, Encoder};

/// Encodes an RGBA8 buffer (`width*height*4`) as a JPEG, dropping alpha. If
/// [exif] is non-empty (a full APP1 segment), it is injected so metadata
/// survives export.
pub fn encode_jpeg(
    rgba: &[u8],
    width: u32,
    height: u32,
    quality: u8,
    exif: &[u8],
) -> Result<Vec<u8>, String> {
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
    let final_exif = if !exif.is_empty() {
        let mut exif_buf = exif.to_vec();
        crate::exif::rewrite_orientation_to_normal(&mut exif_buf);
        exif_buf
    } else {
        Vec::new()
    };
    Ok(crate::exif::inject_app1(out, &final_exif))
}

const CRC_TABLE: [u32; 256] = {
    let mut table = [0u32; 256];
    let mut i = 0;
    while i < 256 {
        let mut c = i as u32;
        let mut k = 0;
        while k < 8 {
            if c & 1 != 0 {
                c = 0xEDB88320 ^ (c >> 1);
            } else {
                c >>= 1;
            }
            k += 1;
        }
        table[i] = c;
        i += 1;
    }
    table
};

fn crc32(tag: &[u8; 4], data: &[u8]) -> u32 {
    let mut crc = 0xFFFFFFFFu32;
    for &b in tag {
        crc = CRC_TABLE[((crc ^ (b as u32)) & 0xFF) as usize] ^ (crc >> 8);
    }
    for &b in data {
        crc = CRC_TABLE[((crc ^ (b as u32)) & 0xFF) as usize] ^ (crc >> 8);
    }
    !crc
}

fn write_png_chunk(out: &mut Vec<u8>, tag: &[u8; 4], data: &[u8]) {
    out.extend_from_slice(&(data.len() as u32).to_be_bytes());
    out.extend_from_slice(tag);
    out.extend_from_slice(data);
    let crc = crc32(tag, data);
    out.extend_from_slice(&crc.to_be_bytes());
}

/// Encodes an RGBA8 buffer (`width * height * 4`) as a lossless PNG.
///
/// Uses `miniz_oxide` deflate compression with 0 external dependencies.
pub fn encode_png(rgba: &[u8], width: u32, height: u32) -> Result<Vec<u8>, String> {
    if width == 0 || height == 0 {
        return Err("export dimensions must be at least 1x1".to_string());
    }
    let expected = width as usize * height as usize * 4;
    if rgba.len() != expected {
        return Err(format!(
            "rgba buffer has {} bytes, expected {expected} for {width}x{height}",
            rgba.len()
        ));
    }

    let row_len = width as usize * 4;
    let mut raw_data = Vec::with_capacity(height as usize * (row_len + 1));
    for y in 0..height as usize {
        raw_data.push(0); // Filter type 0 (None)
        let start = y * row_len;
        raw_data.extend_from_slice(&rgba[start..start + row_len]);
    }

    let compressed = miniz_oxide::deflate::compress_to_vec_zlib(&raw_data, 6);

    let mut out = Vec::with_capacity(compressed.len() + 64);
    out.extend_from_slice(b"\x89PNG\r\n\x1a\n");

    let mut ihdr = Vec::with_capacity(13);
    ihdr.extend_from_slice(&width.to_be_bytes());
    ihdr.extend_from_slice(&height.to_be_bytes());
    ihdr.push(8); // Bit depth: 8
    ihdr.push(6); // Color type: 6 (RGBA)
    ihdr.push(0); // Compression: 0 (deflate)
    ihdr.push(0); // Filter: 0
    ihdr.push(0); // Interlace: 0
    write_png_chunk(&mut out, b"IHDR", &ihdr);

    write_png_chunk(&mut out, b"IDAT", &compressed);
    write_png_chunk(&mut out, b"IEND", &[]);

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
        let hi = encode_jpeg(&src, 64, 64, 95, &[]).unwrap();
        let lo = encode_jpeg(&src, 64, 64, 20, &[]).unwrap();
        assert!(
            lo.len() < hi.len(),
            "quality 20 ({}) should beat 95 ({})",
            lo.len(),
            hi.len()
        );
    }

    #[test]
    fn rejects_a_mismatched_buffer_length() {
        let err = encode_jpeg(&[0u8; 9], 2, 2, 90, &[]).unwrap_err();
        assert!(err.contains("expected 16"), "got: {err}");
    }

    #[test]
    fn rejects_zero_dimensions() {
        assert!(encode_jpeg(&[], 0, 10, 90, &[]).is_err());
        assert!(encode_jpeg(&[], 10, 0, 90, &[]).is_err());
    }

    #[test]
    fn encodes_a_decodable_jpeg_and_drops_alpha() {
        let jpeg = encode_jpeg(&solid_rgba(8, 8, 200, 100, 50), 8, 8, 90, &[]).unwrap();
        assert_eq!(crate::decode::dimensions(&jpeg).unwrap(), (8, 8));
    }

    #[test]
    fn round_trips_colour_within_jpeg_tolerance() {
        let jpeg = encode_jpeg(&solid_rgba(32, 32, 128, 128, 128), 32, 32, 95, &[]).unwrap();
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

    #[test]
    fn rewrites_exif_orientation_to_normal_on_export() {
        let tiff = vec![
            b'I', b'I', 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00, 0x01, 0x00, 0x12, 0x01, 0x03, 0x00,
            0x01, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ];
        let payload_len = 6 + tiff.len();
        let mut app1 = vec![
            0xFF,
            0xE1,
            ((payload_len + 2) >> 8) as u8,
            ((payload_len + 2) & 0xFF) as u8,
        ];
        app1.extend_from_slice(b"Exif\0\0");
        app1.extend_from_slice(&tiff);

        assert_eq!(crate::exif::parse_orientation(&app1), Some(6));

        let jpeg = encode_jpeg(&solid_rgba(8, 8, 100, 100, 100), 8, 8, 90, &app1).unwrap();
        assert_eq!(crate::exif::parse_orientation(&jpeg), Some(1));
    }

    #[test]
    fn encode_png_produces_decodable_png_with_exact_pixels() {
        let rgba = solid_rgba(16, 12, 120, 200, 250);
        let png = encode_png(&rgba, 16, 12).expect("encode_png should succeed");
        assert_eq!(&png[..8], b"\x89PNG\r\n\x1a\n");

        let (decoded, w, h) = crate::watermark::decode_png_rgba(&png).expect("decodable png");
        assert_eq!((w, h), (16, 12));
        assert_eq!(decoded.len(), 16 * 12 * 4);
        assert_eq!(decoded, rgba);
    }

    #[test]
    fn encode_png_rejects_invalid_dimensions() {
        assert!(encode_png(&[], 0, 10).is_err());
        assert!(encode_png(&[], 10, 0).is_err());
        assert!(encode_png(&[0u8; 10], 4, 4).is_err());
    }
}
