//! Flutter Rust Bridge API for panoramic stitching (#104).

use crate::panorama::{stitch_panorama as core_stitch, PanoramaInput, PanoramaProjection};

#[derive(Debug, Clone)]
pub struct ApiPanoramaInput {
    pub rgba: Vec<u8>,
    pub width: u32,
    pub height: u32,
}

#[derive(Debug, Clone)]
pub struct ApiPanoramaResult {
    pub rgba: Vec<u8>,
    pub width: u32,
    pub height: u32,
    pub crop_x: u32,
    pub crop_y: u32,
    pub crop_w: u32,
    pub crop_h: u32,
}

pub fn stitch_panorama(
    images: Vec<ApiPanoramaInput>,
    projection_index: u32,
) -> Result<ApiPanoramaResult, String> {
    let proj = match projection_index {
        1 => PanoramaProjection::Cylindrical,
        2 => PanoramaProjection::Spherical,
        _ => PanoramaProjection::Planar,
    };

    let core_inputs: Vec<PanoramaInput> = images
        .into_iter()
        .map(|img| PanoramaInput {
            rgba: img.rgba,
            width: img.width,
            height: img.height,
        })
        .collect();

    let res = core_stitch(&core_inputs, proj)?;
    Ok(ApiPanoramaResult {
        rgba: res.rgba,
        width: res.width,
        height: res.height,
        crop_x: res.crop_x,
        crop_y: res.crop_y,
        crop_w: res.crop_w,
        crop_h: res.crop_h,
    })
}
