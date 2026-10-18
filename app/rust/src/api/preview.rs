//! Rust-resident preview FFI surface (issue #37 spike A).
//!
//! Thin bridge over [`crate::preview`]: the handle store, the fused base
//! pipeline and the resident histogram live in the engine module — only the
//! bridge-visible spec type and the four entry points live here. (The
//! codegen emits bindings for every struct it finds in `crate::api`, private
//! ones included, so the store types must stay outside this module.)
//!
//! Pipeline summary: the decoded proxy is uploaded once via
//! [`preview_open`]; [`preview_base`] fuses geometry → spatial → masks into
//! a single round trip; [`preview_histogram`] bins from the cached base with
//! zero pixel transfers. Grade scrubbing stays LUT-only on the Dart side.
//! Export keeps its own full-parity path via `geometry_apply` (which shares
//! [`crate::preview::crop_opt`], so preview and export cannot drift).
//!
//! Straighten/perspective/skew are deliberately absent from
//! [`PreviewBaseSpec`]: issues #36/#52 warp those live on the GPU, and
//! baking them on the CPU would double-apply the warp.

use crate::api::color::{ColorParams, CurveParams};
use crate::api::decode::RgbaImage;
use crate::api::histogram::Histogram;
use crate::api::mask::MaskLayer;
use crate::api::retouch::{to_engine_patches, ApiRetouchPatch};

/// Everything `preview_base` bakes on the CPU. Perspective/skew/straighten
/// are absent on purpose — they are GPU-warped live (see module docs).
#[derive(Clone, Copy)]
pub struct PreviewBaseSpec {
    pub flip_h: bool,
    pub flip_v: bool,
    /// Quarter turns, clockwise.
    pub turns: u32,
    /// Normalized crop `[l, t, r, b]` in the transformed frame.
    pub crop_l: f32,
    pub crop_t: f32,
    pub crop_r: f32,
    pub crop_b: f32,
    pub shadows: f32,
    pub highlights: f32,
    pub clarity: f32,
    pub texture: f32,
    pub sharpen: f32,
    pub sharpen_radius: f32,
    pub sharpen_detail: f32,
    pub sharpen_masking: f32,
    pub denoise_luma: f32,
    pub denoise_chroma: f32,
    pub dehaze: f32,
    pub vignette: f32,
    pub vignette_midpoint: f32,
    pub vignette_feather: f32,
    pub vignette_roundness: f32,
    pub vignette_highlights: f32,
    pub grain: f32,
    pub grain_size: f32,
    pub grain_roughness: f32,
    pub film_halation: f32,
    pub film_halation_radius: f32,
    pub film_halation_threshold: f32,
    pub film_bloom: f32,
    pub film_bloom_radius: f32,
    pub film_bloom_threshold: f32,
    pub film_dust: f32,
    pub film_scratches: f32,
    pub shader_lab_preset: u32,
    pub shader_param1: f32,
    pub shader_param2: f32,
    pub shader_param3: f32,
    pub remove_chromatic_aberration: bool,
    pub defringe_purple_amount: f32,
    pub defringe_purple_hue_min: f32,
    pub defringe_purple_hue_max: f32,
    pub defringe_green_amount: f32,
    pub defringe_green_hue_min: f32,
    pub defringe_green_hue_max: f32,
    pub profile_corrections: bool,
    pub profile_distortion: f32,
    pub profile_vignetting: f32,
    /// Depth-aware lens blur (stage position mirrors the export pipeline:
    /// geometry → optics → blur → spatial → masks).
    pub blur_enabled: bool,
    /// Aperture blur amount `0..1`.
    pub blur_amount: f32,
    /// Focal depth plane in sharp focus `0..1`.
    pub blur_focal_point: f32,
    /// Depth-of-field range in sharp focus `0..1`.
    pub blur_focal_range: f32,
    /// Bokeh blade shape index (matches Dart `BokehShape.values`).
    pub blur_bokeh_shape: u8,
    /// Specular highlight boost `0..1`.
    pub blur_bokeh_boost: f32,
}

impl PreviewBaseSpec {
    /// Maps the flat blur fields onto the engine's [`crate::blur::LensBlurParams`].
    pub fn blur_params(&self) -> crate::blur::LensBlurParams {
        crate::blur::LensBlurParams::from_fields(
            self.blur_enabled,
            self.blur_amount,
            self.blur_focal_point,
            self.blur_focal_range,
            self.blur_bokeh_shape,
            self.blur_bokeh_boost,
        )
    }
}

/// Uploads a decoded RGBA proxy into the resident store; returns a handle.
///
/// This is the only point where the source pixels cross the bridge — every
/// later bake references the handle instead. `Arc::from(Vec)` reuses the
/// FFI-delivered allocation, so this is O(1).
pub fn preview_open(rgba: Vec<u8>, width: u32, height: u32) -> u64 {
    if crate::validate::validate_rgba(&rgba, width, height).is_err() {
        return 0;
    }
    crate::preview::open(rgba, width, height)
}

/// Decodes a JPEG directly into the resident store; returns a handle.
///
/// Uses `zune-jpeg` SIMD decoding to eliminate the synchronous GPU readback
/// stall and FFI copy of a pre-decoded RGBA buffer.
pub fn preview_open_jpeg(jpeg_bytes: Vec<u8>, max_dim: u32) -> Result<u64, String> {
    crate::preview::open_jpeg(jpeg_bytes, max_dim)
}

/// Retrieves the original decoded source RGBA buffer for a handle.
pub fn preview_get_source_rgba(handle: u64) -> Result<RgbaImage, String> {
    crate::preview::get_source_rgba(handle)
}

/// Drops the resident image for [handle]. Unknown handles are ignored so
/// double-close from Dart teardown is safe.
pub fn preview_close(handle: u64) {
    crate::preview::close(handle);
}

/// Fused base pipeline on the resident source: flip → rotate → normalized
/// crop → spatial pass → mask layers, in one round trip. See
/// [`crate::preview::run_base`] for the locking/Cow details.
pub fn preview_base(
    handle: u64,
    spec: PreviewBaseSpec,
    layers: Vec<MaskLayer>,
    retouch_patches: Vec<ApiRetouchPatch>,
) -> Result<RgbaImage, String> {
    let patches = to_engine_patches(&retouch_patches);
    crate::preview::run_base(handle, &spec, &layers, &patches)
}

/// Bins the **cached base** (after geometry/spatial/masks) through the
/// colour pipeline. No pixels cross the bridge — only params in, four
/// 256-bin `Vec<u32>` channels out. Errors if no base has been baked yet.
pub fn preview_histogram(
    handle: u64,
    params: ColorParams,
    sample_dim: u32,
    curves: CurveParams,
    hsl: Vec<f32>,
) -> Result<Histogram, String> {
    let h = crate::preview::histogram_from_base(handle, params, sample_dim, &curves, &hsl)?;
    Ok(Histogram {
        r: h.r,
        g: h.g,
        b: h.b,
        luma: h.luma,
    })
}

/// Dimensions of the frame a [`preview_render`] just wrote into the bound
/// texture. No pixels cross the bridge in texture mode — only this size.
#[derive(Clone, Copy)]
pub struct RenderedSize {
    pub width: u32,
    pub height: u32,
}

/// Spike B: fuses base + grade and writes the result straight into the
/// platform texture bound via `bindPreviewSurface` (MainActivity). **Zero
/// pixels cross the bridge.** The ungraded base is still cached for
/// [`preview_histogram`], so the histogram keeps its spike-A semantics.
///
/// The grade is baked in Rust (the `FragmentShader` cannot sample a `Texture`
/// widget). Errors when no texture is bound — Dart catches that and falls
/// back to [`preview_base`] (spike A, return-frame + shader).
#[allow(clippy::too_many_arguments)]
pub fn preview_render(
    handle: u64,
    spec: PreviewBaseSpec,
    layers: Vec<MaskLayer>,
    retouch_patches: Vec<ApiRetouchPatch>,
    params: ColorParams,
    curves: CurveParams,
    hsl: Vec<f32>,
    base_changed: bool,
) -> Result<RenderedSize, String> {
    let patches = to_engine_patches(&retouch_patches);
    let (width, height) = crate::preview::render(
        handle,
        &spec,
        &layers,
        &patches,
        &params,
        &curves,
        &hsl,
        base_changed,
    )?;
    Ok(RenderedSize { width, height })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::geometry::geometry_apply;
    use crate::api::optics::optics_apply;
    use crate::api::retouch::retouch_apply;
    use crate::api::spatial::spatial_apply;

    /// Encodes x in R and y in G so positions are checkable.
    fn grid(w: usize, h: usize) -> Vec<u8> {
        let mut v = Vec::with_capacity(w * h * 4);
        for y in 0..h {
            for x in 0..w {
                v.extend_from_slice(&[x as u8, y as u8, 0, 255]);
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
        }
    }

    fn neutral_params() -> ColorParams {
        ColorParams {
            exposure: 0.0,
            ..Default::default()
        }
    }

    fn no_curves() -> CurveParams {
        CurveParams {
            master: vec![],
            red: vec![],
            green: vec![],
            blue: vec![],
        }
    }

    #[test]
    fn open_then_identity_base_returns_the_source() {
        let src = grid(4, 3);
        let h = preview_open(src.clone(), 4, 3);
        let frame = preview_base(h, identity_spec(), Vec::new(), Vec::new()).unwrap();
        assert_eq!((frame.width, frame.height), (4, 3));
        assert_eq!(frame.rgba, src);
        preview_close(h);
    }

    #[test]
    fn fused_base_matches_the_sequential_bridge_chain() {
        // The invariant that keeps preview == export: one fused call must
        // equal geometry_apply → optics_apply → retouch_apply → spatial_apply
        // (with warp params neutral, since the GPU owns those live).
        let src = grid(8, 6);
        let (sh, hi, cl, tx, shn, dl, dc, dh, vg, gr) =
            (0.2, -0.1, 0.3, 0.0, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0);
        let patches = vec![ApiRetouchPatch {
            target_x: 0.7,
            target_y: 0.6,
            source_x: 0.2,
            source_y: 0.3,
            radius: 0.2,
            feather: 0.5,
            opacity: 1.0,
            is_clone: false,
        }];

        let geo = geometry_apply(
            src.clone(),
            8,
            6,
            true,
            false,
            1,
            0.0,
            0.0,
            0.0,
            0.75,
            1.0,
            0.0,
            0.0,
            0.0,
            0.0,
        );
        let opt = optics_apply(
            geo.rgba, geo.width, geo.height, false, 0.0, 0.70, 0.95, 0.0, 0.17, 0.50, true, 1.0,
            1.0,
        );
        let ret = retouch_apply(opt, geo.width, geo.height, patches.clone());
        let seq = spatial_apply(
            ret, geo.width, geo.height, sh, hi, cl, tx, shn, 1.0, 0.25, 0.0, dl, dc, dh, vg, 0.5,
            0.5, 0.0, 0.0, gr, 0.25, 0.5,
        );

        let spec = PreviewBaseSpec {
            flip_h: true,
            flip_v: false,
            turns: 1,
            crop_l: 0.0,
            crop_t: 0.0,
            crop_r: 0.75,
            crop_b: 1.0,
            shadows: sh,
            highlights: hi,
            clarity: cl,
            texture: tx,
            sharpen: shn,
            sharpen_radius: 1.0,
            sharpen_detail: 0.25,
            sharpen_masking: 0.0,
            denoise_luma: dl,
            denoise_chroma: dc,
            dehaze: dh,
            vignette: vg,
            vignette_midpoint: 0.5,
            vignette_feather: 0.5,
            vignette_roundness: 0.0,
            vignette_highlights: 0.0,
            grain: gr,
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
            profile_corrections: true,
            profile_distortion: 1.0,
            profile_vignetting: 1.0,
            blur_enabled: false,
            blur_amount: 0.0,
            blur_focal_point: 0.5,
            blur_focal_range: 0.2,
            blur_bokeh_shape: 0,
            blur_bokeh_boost: 0.0,
        };
        let h = preview_open(src, 8, 6);
        let fused = preview_base(h, spec, Vec::new(), patches).unwrap();
        assert_eq!((fused.width, fused.height), (geo.width, geo.height));
        assert_eq!(fused.rgba, seq);
        preview_close(h);
    }

    #[test]
    fn histogram_bins_from_the_cached_base_without_a_second_upload() {
        let h = preview_open(grid(32, 32), 32, 32);

        // Histogram before any base bake is an explicit error, not silent
        // zero bins — Dart always bakes the base first.
        assert!(preview_histogram(h, neutral_params(), 32, no_curves(), vec![0.0; 24]).is_err());

        // Radial mask brightens only the centre — the histogram must see the
        // masked base, not the raw source.
        let layers = vec![MaskLayer {
            kind: crate::mask::MASK_RADIAL,
            mask: vec![0.5, 0.5, 0.3, 0.3, 0.3],
            params: ColorParams {
                exposure: 2.0,
                ..Default::default()
            },
            inverted: false,
            amount: 1.0,
            ..Default::default()
        }];
        let mut spec = identity_spec();
        spec.shadows = 0.25; // engage spatial so all three stages are covered
        preview_base(h, spec, layers, Vec::new()).unwrap();

        let hist = preview_histogram(h, neutral_params(), 32, no_curves(), vec![0.0; 24]).unwrap();
        assert_eq!(hist.r.len(), 256);
        assert!(hist.r.iter().sum::<u32>() > 0);
        preview_close(h);
    }

    /// The blur slider must reach the baked base: a blur-engaged spec
    /// changes out-of-focus pixels while the sharp focal plane is preserved.
    #[test]
    fn blur_engaged_spec_changes_the_baked_base() {
        let (w, h) = (32, 32);
        let mut src = vec![0u8; w * h * 4];
        for y in 0..h {
            for x in 0..w {
                let i = (y * w + x) * 4;
                let v = if (x + y) % 2 == 0 { 255 } else { 0 };
                src[i] = v;
                src[i + 1] = v;
                src[i + 2] = v;
                src[i + 3] = 255;
            }
        }

        let mut spec = identity_spec();
        spec.blur_enabled = true;
        spec.blur_amount = 1.0;
        spec.blur_focal_point = 0.5;
        spec.blur_focal_range = 0.2;

        let h_handle = preview_open(src.clone(), w as u32, h as u32);
        let frame = preview_base(h_handle, spec, Vec::new(), Vec::new()).unwrap();
        preview_close(h_handle);

        assert_ne!(
            frame.rgba, src,
            "blur-engaged spec must change out-of-focus pixels"
        );
        // Synthetic depth puts the image centre inside the focal plane.
        let center = ((h / 2) * w + w / 2) * 4;
        assert_eq!(
            &frame.rgba[center..center + 4],
            &src[center..center + 4],
            "pixels inside the focal plane must stay sharp"
        );

        // Neutral blur stays byte-identical.
        let neutral = identity_spec();
        let h2 = preview_open(src.clone(), w as u32, h as u32);
        let unchanged = preview_base(h2, neutral, Vec::new(), Vec::new()).unwrap();
        preview_close(h2);
        assert_eq!(unchanged.rgba, src);
    }

    /// The retouch patches must reach the baked base: a clone patch carries
    /// the source strip's colour onto its target while the rest stays put.
    #[test]
    fn retouch_engaged_spec_changes_the_baked_base() {
        let (w, h) = (32, 32);
        let mut src = vec![20u8; w * h * 4];
        for y in 0..h {
            for x in 0..w {
                src[(y * w + x) * 4 + 3] = 255;
            }
        }
        for y in 0..h {
            for x in 4..=12 {
                let i = (y * w + x) * 4;
                src[i] = 0;
                src[i + 1] = 255;
                src[i + 2] = 0;
            }
        }

        let patch = ApiRetouchPatch {
            target_x: 24.0 / (w - 1) as f32,
            target_y: 16.0 / (h - 1) as f32,
            source_x: 8.0 / (w - 1) as f32,
            source_y: 8.0 / (h - 1) as f32,
            radius: 5.0 / 32.0,
            feather: 0.0,
            opacity: 1.0,
            is_clone: true,
        };

        let handle = preview_open(src.clone(), w as u32, h as u32);
        let frame = preview_base(handle, identity_spec(), Vec::new(), vec![patch]).unwrap();
        preview_close(handle);

        assert_ne!(frame.rgba, src, "clone patch must change the baked base");
        let target = ((16 * w) + 24) * 4;
        assert_eq!(
            &frame.rgba[target..target + 3],
            &[0, 255, 0],
            "the target must take the cloned source colour"
        );
        let far = ((4 * w) + 28) * 4;
        assert_eq!(
            &frame.rgba[far..far + 3],
            &src[far..far + 3],
            "pixels outside the patch must stay untouched"
        );
    }

    /// The lens-profile gates must reach the baked base: with the gate on, a
    /// flat frame's corners brighten while the centre holds.
    #[test]
    fn profile_corrections_engaged_changes_the_baked_base() {
        let (w, h) = (33, 33);
        let mut src = vec![100u8; w * h * 4];
        for px in src.as_chunks_mut::<4>().0 {
            px[3] = 255;
        }

        let mut spec = identity_spec();
        spec.profile_corrections = true;
        spec.profile_distortion = 1.0;
        spec.profile_vignetting = 1.0;

        let handle = preview_open(src.clone(), w as u32, h as u32);
        let frame = preview_base(handle, spec, Vec::new(), Vec::new()).unwrap();
        preview_close(handle);

        assert_ne!(
            frame.rgba, src,
            "profile-engaged spec must change the baked base"
        );
        assert!(
            frame.rgba[0] > src[0],
            "the corner must brighten: {} vs {}",
            frame.rgba[0],
            src[0]
        );
        let center = ((h / 2) * w + w / 2) * 4;
        assert_eq!(
            &frame.rgba[center..center + 3],
            &src[center..center + 3],
            "the optical centre must hold"
        );

        let neutral = identity_spec();
        let h2 = preview_open(src.clone(), w as u32, h as u32);
        let unchanged = preview_base(h2, neutral, Vec::new(), Vec::new()).unwrap();
        preview_close(h2);
        assert_eq!(unchanged.rgba, src);
    }

    #[test]
    fn unknown_and_closed_handles_error_instead_of_panicking() {
        assert!(preview_base(9_999, identity_spec(), Vec::new(), Vec::new()).is_err());

        let h = preview_open(grid(2, 2), 2, 2);
        preview_close(h);
        preview_close(h); // double-close from Dart teardown must be safe
        assert!(preview_histogram(h, neutral_params(), 2, no_curves(), vec![0.0; 24]).is_err());
    }

    #[test]
    fn handles_are_independent() {
        let a = preview_open(grid(4, 4), 4, 4);
        let b = preview_open(grid(6, 2), 6, 2);
        assert_ne!(a, b);
        let fa = preview_base(a, identity_spec(), Vec::new(), Vec::new()).unwrap();
        let fb = preview_base(b, identity_spec(), Vec::new(), Vec::new()).unwrap();
        assert_eq!((fa.width, fa.height), (4, 4));
        assert_eq!((fb.width, fb.height), (6, 2));
        preview_close(a);
        // b survives a's close
        assert!(preview_base(b, identity_spec(), Vec::new(), Vec::new()).is_ok());
        preview_close(b);
    }

    #[test]
    fn concurrent_histogram_does_not_deadlock_with_base() {
        // The structural guarantee: preview_base never holds the store lock
        // across pixel math. Hammer both entry points from two threads on
        // overlapping handles; the test only passes if neither blocks
        // forever (a lock-held-math regression deadlocks and times out the
        // test process rather than passing silently).
        use std::sync::{Arc, Barrier};
        let h = preview_open(grid(64, 64), 64, 64);
        let barrier = Arc::new(Barrier::new(2));

        let b_handle = h;
        let b_barrier = Arc::clone(&barrier);
        let baker = std::thread::spawn(move || {
            b_barrier.wait();
            for i in 0..50 {
                let mut spec = identity_spec();
                spec.shadows = (i % 7) as f32 * 0.1;
                preview_base(b_handle, spec, Vec::new(), Vec::new()).unwrap();
            }
        });

        let hist_barrier = Arc::clone(&barrier);
        let hist_thread = std::thread::spawn(move || {
            hist_barrier.wait();
            for _ in 0..50 {
                // Errors are fine (base may not exist yet); panics/hangs are not.
                let _ = preview_histogram(h, neutral_params(), 64, no_curves(), vec![0.0; 24]);
            }
        });

        baker.join().expect("preview_base thread panicked");
        hist_thread
            .join()
            .expect("preview_histogram thread panicked");
        preview_close(h);
    }
}
