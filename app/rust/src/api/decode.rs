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

/// Decodes a JPEG and returns only the RGBA pixels inside the given region of
/// interest. This is the tile decode path: only the requested rect is produced,
/// never the full image buffer.
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
    Ok(RgbaImage {
        width: cropped.width as u32,
        height: cropped.height as u32,
        rgba: cropped.rgba,
    })
}
