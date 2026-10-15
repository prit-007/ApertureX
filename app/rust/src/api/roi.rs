//! High-zoom ROI overlay bake across the `flutter_rust_bridge` boundary
//! (issues #55/#16).
//!
//! The viewport decodes a full-width source band natively (never the whole
//! frame) and hands it here: [`bake_roi_band`] applies the **same** spatial +
//! mask chain as `preview_base` with absolute coordinates, so the overlay
//! stitches onto the proxy without a seam, and [`roi_halo`] tells Dart how
//! many context rows to decode around the output.

use crate::api::decode::RgbaImage;
use crate::api::mask::MaskLayer;
use crate::api::preview::PreviewBaseSpec;
use crate::mask::{self, LocalAdjustment, MaskSpec};
use crate::spatial::{self, SpatialParams};

/// Rows of context ([`spatial::spatial_local_margin`]) Dart must decode above
/// and below the requested output so [`bake_roi_band`] sees true neighbours.
/// Geometry never affects the halo — ROI bands are geometry-identity only.
pub fn roi_halo(spec: PreviewBaseSpec, full_width: u32, full_height: u32) -> u32 {
    spatial::spatial_local_margin(
        spatial_params(&spec),
        full_width as usize,
        full_height as usize,
    ) as u32
}

/// Bakes the preview base chain (spatial → mask layers) onto a decoded
/// full-width band of the **original** frame.
///
/// * `band` holds rows `decode_top ..` of the `full_width × full_height`
///   source, with at least [`roi_halo`] context rows around
///   `[out_top, out_top + out_rows)`;
/// * `spec`'s geometry fields **must be identity** (rotation/crop/warp are
///   baked into the proxy and would misalign a raw band — the viewport gates
///   this); a non-identity spec is an error, never a silent misalignment;
/// * the grade (exposure/LUT) is shader-side for preview and not applied here.
#[allow(
    clippy::too_many_arguments,
    reason = "flat scalar args keep the frb surface simple; a struct adds a bridge type for no gain"
)]
pub fn bake_roi_band(
    band: Vec<u8>,
    decode_top: u32,
    out_top: u32,
    out_rows: u32,
    full_width: u32,
    full_height: u32,
    spec: PreviewBaseSpec,
    layers: Vec<MaskLayer>,
) -> Result<RgbaImage, String> {
    if spec.flip_h
        || spec.flip_v
        || spec.turns != 0
        || spec.crop_l != 0.0
        || spec.crop_t != 0.0
        || spec.crop_r != 1.0
        || spec.crop_b != 1.0
    {
        return Err(
            "ROI bands require identity geometry; the viewport must gate on crop/rotate/flip"
                .to_string(),
        );
    }

    let full = (full_width as usize, full_height as usize);
    let mut out = spatial::apply_spatial_roi(
        &band,
        full,
        decode_top as usize,
        out_top as usize,
        out_rows as usize,
        spatial_params(&spec),
    )?;

    if !layers.is_empty() {
        let core: Vec<LocalAdjustment> = layers
            .iter()
            .map(|l| LocalAdjustment {
                mask: MaskSpec {
                    kind: l.kind,
                    params: l.mask.clone(),
                },
                params: l.params.to_core(),
            })
            .collect();
        out = mask::apply_local_band(&out, full.0, full.1, out_top as usize, &core);
    }

    Ok(RgbaImage {
        width: full_width,
        height: out_rows,
        rgba: out,
    })
}

/// The engine spatial params carried by a [`PreviewBaseSpec`] (geometry is
/// absent by construction of the ROI path).
fn spatial_params(spec: &PreviewBaseSpec) -> SpatialParams {
    SpatialParams {
        shadows: spec.shadows,
        highlights: spec.highlights,
        clarity: spec.clarity,
        texture: spec.texture,
        sharpen: spec.sharpen,
        denoise_luma: spec.denoise_luma,
        denoise_chroma: spec.denoise_chroma,
        dehaze: spec.dehaze,
        vignette: spec.vignette,
        grain: spec.grain,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::color::ColorParams;
    use crate::api::preview::{preview_base, preview_close, preview_open};

    /// Deterministic gradient with position encoded — any row-offset or halo
    /// mistake changes bytes.
    fn noise(w: usize, h: usize) -> Vec<u8> {
        let mut v = Vec::with_capacity(w * h * 4);
        for y in 0..h {
            for x in 0..w {
                let r = ((x * 37 + y * 17) % 256) as u8;
                let g = ((x * 11 + y * 53) % 256) as u8;
                let b = ((x * 7 + y * 3) % 256) as u8;
                v.extend_from_slice(&[r, g, b, 255]);
            }
        }
        v
    }

    fn identity_spec() -> PreviewBaseSpec {
        PreviewBaseSpec {
            flip_h: false,
            flip_v: false,
            turns: 0,
            crop_l: 0.0,
            crop_t: 0.0,
            crop_r: 1.0,
            crop_b: 1.0,
            shadows: 0.0,
            highlights: 0.0,
            clarity: 0.0,
            texture: 0.0,
            sharpen: 0.0,
            denoise_luma: 0.0,
            denoise_chroma: 0.0,
            dehaze: 0.0,
            vignette: 0.0,
            grain: 0.0,
        }
    }

    /// Spatial + vignette + grain engaged, so every stage is covered.
    fn engaged_spec() -> PreviewBaseSpec {
        PreviewBaseSpec {
            shadows: 0.3,
            highlights: -0.2,
            clarity: 0.4,
            texture: 0.2,
            sharpen: 0.3,
            denoise_luma: 0.2,
            denoise_chroma: 0.3,
            dehaze: 0.1,
            vignette: 0.2,
            grain: 0.1,
            ..identity_spec()
        }
    }

    fn layer() -> MaskLayer {
        MaskLayer {
            kind: crate::mask::MASK_RADIAL,
            mask: vec![0.5, 0.5, 0.4, 0.35, 0.3],
            params: ColorParams {
                exposure: 0.5,
                saturation: 0.3,
                ..Default::default()
            },
        }
    }

    fn rows(buf: &[u8], w: usize, top: usize, count: usize) -> Vec<u8> {
        buf[top * w * 4..(top + count) * w * 4].to_vec()
    }

    #[test]
    fn bake_matches_the_preview_base_chain_with_masks() {
        let (w, h) = (64, 320);
        let src = noise(w, h);
        let halo = roi_halo(engaged_spec(), w as u32, h as u32) as usize;
        let (out_top, out_rows) = (halo + 40, 50);

        // Oracle: the actual preview chain over the full frame.
        let handle = preview_open(src.clone(), w as u32, h as u32);
        let full = preview_base(handle, engaged_spec(), vec![layer()]).expect("preview base");
        preview_close(handle);

        let decode_top = out_top - halo;
        let band = rows(&src, w, decode_top, out_rows + 2 * halo);
        let baked = bake_roi_band(
            band,
            decode_top as u32,
            out_top as u32,
            out_rows as u32,
            w as u32,
            h as u32,
            engaged_spec(),
            vec![layer()],
        )
        .expect("roi bake");
        assert_eq!(baked.width, w as u32);
        assert_eq!(baked.height, out_rows as u32);
        assert_eq!(
            baked.rgba,
            rows(&full.rgba, w, out_top, out_rows),
            "overlay band must be the exact rows the proxy shows"
        );
    }

    #[test]
    fn halo_matches_the_spatial_margin_formula() {
        let halo = roi_halo(engaged_spec(), 64, 320);
        assert_eq!(
            halo as usize,
            spatial::spatial_local_margin(spatial_params(&engaged_spec()), 64, 320)
        );
        assert!(halo > 0, "engaged ops must demand context");
        assert_eq!(roi_halo(identity_spec(), 64, 320), 0, "neutral needs none");
    }

    #[test]
    fn geometry_edits_are_rejected_rather_than_misaligned() {
        let src = noise(16, 32);
        let mut spec = identity_spec();
        spec.flip_h = true;
        let err = bake_roi_band(
            src[..16 * 8 * 4].to_vec(),
            0,
            0,
            8,
            16,
            32,
            spec,
            Vec::new(),
        );
        assert!(err.is_err());
    }

    #[test]
    fn a_short_halo_fails_instead_of_seaming() {
        let (w, h) = (64, 320);
        let src = noise(w, h);
        let halo = roi_halo(engaged_spec(), w as u32, h as u32) as usize;
        assert!(halo > 1, "test needs an engaged margin");
        let out_top = halo + 10;
        let decode_top = out_top - (halo - 1);
        let band = rows(&src, w, decode_top, (halo - 1) + 20);
        let err = bake_roi_band(
            band,
            decode_top as u32,
            out_top as u32,
            20,
            w as u32,
            h as u32,
            engaged_spec(),
            Vec::new(),
        );
        assert!(err.is_err());
    }

    #[test]
    fn neutral_spec_passes_the_source_rows_through() {
        let (w, h) = (32, 64);
        let src = noise(w, h);
        let out = bake_roi_band(
            rows(&src, w, 4, 24),
            4,
            6,
            12,
            w as u32,
            h as u32,
            identity_spec(),
            Vec::new(),
        )
        .expect("neutral bake");
        assert_eq!(out.rgba, rows(&src, w, 6, 12));
    }
}
