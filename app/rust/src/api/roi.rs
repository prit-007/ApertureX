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
                inverted: l.inverted,
                amount: l.amount,
                group_id: l.group_id.clone(),
                join_op: l.join_op,
                group_inverted: l.group_inverted,
                group_amount: l.group_amount,
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

/// Bakes the preview base chain (spatial → mask layers) onto a decoded
/// **rect (tile)** of the **original** frame — the tiled viewport bake (#16),
/// the 2D sibling of [`bake_roi_band`].
///
/// * `rect` holds the pixels `(decode_x, decode_y, decode_w, decode_h)` of
///   the source, with at least [`roi_halo`] context on **all four** sides
///   around `[out_x, out_x + out_w) × [out_y, out_y + out_h)` (except at the
///   image edges);
/// * `spec`'s geometry fields **must be identity** (same contract as the band
///   path — the viewport gates on crop/rotate/flip);
/// * the grade is shader-side for preview and not applied here.
#[allow(
    clippy::too_many_arguments,
    reason = "flat scalar args keep the frb surface simple; a struct adds a bridge type for no gain"
)]
pub fn bake_roi_rect(
    rect: Vec<u8>,
    decode_x: u32,
    decode_y: u32,
    decode_w: u32,
    decode_h: u32,
    out_x: u32,
    out_y: u32,
    out_w: u32,
    out_h: u32,
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
            "ROI rects require identity geometry; the viewport must gate on crop/rotate/flip"
                .to_string(),
        );
    }

    let full = (full_width as usize, full_height as usize);
    let mut out = spatial::apply_spatial_rect(
        &rect,
        full,
        decode_x as usize,
        decode_y as usize,
        decode_w as usize,
        decode_h as usize,
        out_x as usize,
        out_y as usize,
        out_w as usize,
        out_h as usize,
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
                inverted: l.inverted,
                amount: l.amount,
                group_id: l.group_id.clone(),
                join_op: l.join_op,
                group_inverted: l.group_inverted,
                group_amount: l.group_amount,
            })
            .collect();
        out = mask::apply_local_rect(
            &out,
            out_w as usize,
            out_x as usize,
            out_y as usize,
            full.0,
            full.1,
            &core,
        );
    }

    Ok(RgbaImage {
        width: out_w,
        height: out_h,
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
        sharpen_radius: spec.sharpen_radius,
        sharpen_detail: spec.sharpen_detail,
        sharpen_masking: spec.sharpen_masking,
        denoise_luma: spec.denoise_luma,
        denoise_chroma: spec.denoise_chroma,
        dehaze: spec.dehaze,
        vignette: spec.vignette,
        vignette_midpoint: spec.vignette_midpoint,
        vignette_feather: spec.vignette_feather,
        vignette_roundness: spec.vignette_roundness,
        vignette_highlights: spec.vignette_highlights,
        grain: spec.grain,
        grain_size: spec.grain_size,
        grain_roughness: spec.grain_roughness,
        film_halation: spec.film_halation,
        film_halation_radius: spec.film_halation_radius,
        film_halation_threshold: spec.film_halation_threshold,
        film_bloom: spec.film_bloom,
        film_bloom_radius: spec.film_bloom_radius,
        film_bloom_threshold: spec.film_bloom_threshold,
        film_dust: spec.film_dust,
        film_scratches: spec.film_scratches,
        shader_lab_preset: spec.shader_lab_preset,
        shader_param1: spec.shader_param1,
        shader_param2: spec.shader_param2,
        shader_param3: spec.shader_param3,
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
            sharpen_radius: 1.0,
            sharpen_detail: 0.25,
            sharpen_masking: 0.0,
            denoise_luma: 0.0,
            denoise_chroma: 0.0,
            dehaze: 0.0,
            vignette: 0.0,
            vignette_midpoint: 0.5,
            vignette_feather: 0.5,
            vignette_roundness: 0.0,
            vignette_highlights: 0.0,
            grain: 0.0,
            grain_size: 0.25,
            grain_roughness: 0.5,
            film_halation: 0.0,
            film_halation_radius: 0.5,
            film_halation_threshold: 0.8,
            film_bloom: 0.0,
            film_bloom_radius: 0.5,
            film_bloom_threshold: 0.75,
            film_dust: 0.0,
            film_scratches: 0.0,
            shader_lab_preset: 0,
            shader_param1: 0.0,
            shader_param2: 0.0,
            shader_param3: 0.0,
            remove_chromatic_aberration: false,
            defringe_purple_amount: 0.0,
            defringe_purple_hue_min: 0.70,
            defringe_purple_hue_max: 0.95,
            defringe_green_amount: 0.0,
            defringe_green_hue_min: 0.17,
            defringe_green_hue_max: 0.50,
            profile_corrections: false,
            profile_distortion: 1.0,
            profile_vignetting: 1.0,
            blur_enabled: false,
            blur_amount: 0.0,
            blur_focal_point: 0.5,
            blur_focal_range: 0.2,
            blur_bokeh_shape: 0,
            blur_bokeh_boost: 0.0,
            blur_background_blur: false,
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
            inverted: false,
            amount: 1.0,
            ..Default::default()
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
        let full =
            preview_base(handle, engaged_spec(), vec![layer()], Vec::new()).expect("preview base");
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

    /// Extracts the rect `(x, y, rw, rh)` of a `w`-wide image.
    fn rect(src: &[u8], w: usize, x: usize, y: usize, rw: usize, rh: usize) -> Vec<u8> {
        let mut out = Vec::with_capacity(rw * rh * 4);
        for row in 0..rh {
            let start = ((y + row) * w + x) * 4;
            out.extend_from_slice(&src[start..start + rw * 4]);
        }
        out
    }

    /// 2×2 tiles with halo, stitched, must equal the preview_base oracle
    /// byte-for-byte — the seam guarantee for the tiled viewport (#16).
    /// Dehaze is off so the margin (32 px) stays inside the 96×80 frame and
    /// the interior tile edges exercise true partial-halo decoding.
    #[test]
    fn rect_tiles_stitch_to_the_preview_base_chain() {
        let (w, h) = (96, 80);
        let src = noise(w, h);
        let spec = PreviewBaseSpec {
            dehaze: 0.0,
            ..engaged_spec()
        };
        let halo = roi_halo(spec, w as u32, h as u32) as usize;
        assert!(halo > 0, "engaged ops must demand context");

        let handle = preview_open(src.clone(), w as u32, h as u32);
        let full = preview_base(handle, spec, vec![layer()], Vec::new()).expect("preview base");
        preview_close(handle);

        let mut stitched = vec![0u8; w * h * 4];
        for (tx, ty) in [(0usize, 0usize), (48, 0), (0, 40), (48, 40)] {
            let (tw, th) = (48, 40);
            let dx = tx.saturating_sub(halo);
            let dy = ty.saturating_sub(halo);
            let dw = (tx + tw + halo).min(w) - dx;
            let dh = (ty + th + halo).min(h) - dy;
            let baked = bake_roi_rect(
                rect(&src, w, dx, dy, dw, dh),
                dx as u32,
                dy as u32,
                dw as u32,
                dh as u32,
                tx as u32,
                ty as u32,
                tw as u32,
                th as u32,
                w as u32,
                h as u32,
                spec,
                vec![layer()],
            )
            .expect("rect bake");
            assert_eq!(baked.width, tw as u32);
            assert_eq!(baked.height, th as u32);
            for row in 0..th {
                let dst = ((ty + row) * w + tx) * 4;
                let src_i = row * tw * 4;
                stitched[dst..dst + tw * 4].copy_from_slice(&baked.rgba[src_i..src_i + tw * 4]);
            }
        }
        assert_eq!(
            stitched, full.rgba,
            "stitched tiles must equal the full-frame chain"
        );
    }

    #[test]
    fn a_short_side_halo_fails_instead_of_seaming() {
        let (w, h) = (64, 64);
        let src = noise(w, h);
        // Clarity-only keeps the margin small enough to sit inside the image.
        let spec = PreviewBaseSpec {
            clarity: 0.4,
            ..identity_spec()
        };
        let halo = roi_halo(spec, w as u32, h as u32) as usize;
        assert!(halo > 1, "test needs an engaged margin");
        // Interior tile at (32,32): decode starts only halo-1 px to its left,
        // with a full top halo so the left edge is what gets rejected.
        let (tx, ty, tw, th) = (32, 32, 16, 16);
        let dx = tx - (halo - 1);
        let dy = ty - halo;
        let dw = (tx + tw + halo).min(w) - dx;
        let dh = (ty + th + halo).min(h) - dy;
        let err = bake_roi_rect(
            rect(&src, w, dx, dy, dw, dh),
            dx as u32,
            dy as u32,
            dw as u32,
            dh as u32,
            tx as u32,
            ty as u32,
            tw as u32,
            th as u32,
            w as u32,
            h as u32,
            spec,
            Vec::new(),
        );
        assert!(err.is_err(), "short left halo must be rejected");
    }

    #[test]
    fn rect_geometry_edits_are_rejected_rather_than_misaligned() {
        let src = noise(16, 32);
        let mut spec = identity_spec();
        spec.turns = 1;
        let err = bake_roi_rect(
            src[..16 * 8 * 4].to_vec(),
            0,
            0,
            16,
            8,
            0,
            0,
            16,
            8,
            16,
            32,
            spec,
            Vec::new(),
        );
        assert!(err.is_err());
    }
}
