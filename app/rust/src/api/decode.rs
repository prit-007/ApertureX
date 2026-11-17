//! JPEG decode API exposed across the `flutter_rust_bridge` boundary.
//!
//! Thin wrappers over [`crate::decode`]. These give the Dart viewport a real
//! image source: read dimensions, decode a full RGBA buffer, or decode just a
//! region of interest (the tile decode path).

use crate::decode;

/// Image dimensions in pixels.
pub struct ImageDims {
    pub width: u32,
    pub height: u32,
}

/// A decoded RGBA8 image buffer with its dimensions.
#[derive(Clone)]
pub struct RgbaImage {
    pub width: u32,
    pub height: u32,
    /// RGBA8 pixels, length always `width * height * 4`.
    pub rgba: Vec<u8>,
}

/// Reads JPEG dimensions without decoding pixels.
pub fn jpeg_dimensions(jpeg: Vec<u8>) -> Result<ImageDims, String> {
    let (w, h) = decode::dimensions(&jpeg)?;
    Ok(ImageDims {
        width: w as u32,
        height: h as u32,
    })
}

/// Decodes a JPEG into a full RGBA8 buffer.
pub fn decode_jpeg_rgba(jpeg: Vec<u8>) -> Result<RgbaImage, String> {
    let img = decode::decode_rgba(&jpeg)?;
    Ok(RgbaImage {
        width: img.width as u32,
        height: img.height as u32,
        rgba: img.rgba,
    })
}

/// Decodes a JPEG and returns the RGBA pixels inside the given region of
/// interest (ROI).
///
/// Current implementation decodes with `zune-jpeg` and crops the requested region,
/// immediately dropping the full-frame buffer before returning so only the ROI
/// buffer is retained. Native platform decoders (`BitmapRegionDecoder` on Android /
/// `CGImageSource` on iOS) can replace this decode+crop path in future iterations.
pub fn decode_jpeg_roi(
    jpeg: Vec<u8>,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
) -> Result<RgbaImage, String> {
    let img = decode::decode_rgba(&jpeg)?;
    let cropped = decode::crop_rgba(
        &img,
        x as usize,
        y as usize,
        width as usize,
        height as usize,
    )?;
    drop(img);
    Ok(RgbaImage {
        width: cropped.width as u32,
        height: cropped.height as u32,
        rgba: cropped.rgba,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use jpeg_encoder::{ColorType, Encoder};

    fn make_test_jpeg(w: u16, h: u16) -> Vec<u8> {
        let mut rgb = Vec::with_capacity(w as usize * h as usize * 3);
        for y in 0..h {
            for x in 0..w {
                rgb.extend_from_slice(&[(x % 256) as u8, (y % 256) as u8, 128]);
            }
        }
        let mut out = Vec::new();
        Encoder::new(&mut out, 95)
            .encode(&rgb, w, h, ColorType::Rgb)
            .expect("encode test jpeg");
        out
    }

    #[test]
    fn test_decode_jpeg_roi_subregion_and_buffer_size() {
        let jpeg = make_test_jpeg(100, 100);
        let roi = decode_jpeg_roi(jpeg, 10, 20, 30, 40).expect("decode roi");
        assert_eq!(roi.width, 30);
        assert_eq!(roi.height, 40);
        assert_eq!(roi.rgba.len(), 30 * 40 * 4);
        assert!(roi.rgba.len() < 100 * 100 * 4);
    }

    #[test]
    fn test_decode_jpeg_roi_out_of_bounds() {
        let jpeg = make_test_jpeg(50, 50);
        let err = decode_jpeg_roi(jpeg, 40, 40, 20, 20);
        assert!(err.is_err());
    }
}
