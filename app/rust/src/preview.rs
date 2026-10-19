//! Rust-resident preview buffers (issue #37 spike A, engine half).
//!
//! The preview pipeline used to ship the full RGBA frame across the bridge
//! four times per bake (`applyGeometry` → `applySpatial` → `applyMasks` →
//! `histogramGraded`: 3 uploads + 3 downloads, then a 4th upload for the
//! histogram). With the SSE codec every crossing is a byte-by-byte
//! serialisation plus a decode-side copy, so a 1.3 MP proxy cost ~50 MB of
//! bridge traffic per slider release.
//!
//! This module keeps the decoded proxy **resident in Rust** behind an opaque
//! handle. [`run_base`] fuses geometry → spatial → masks into one call
//! (source never leaves Rust; only the final frame returns once), and
//! [`histogram_from_base`] bins from the cached base with **zero** pixel
//! transfers. Grade scrubbing was already LUT-only; this makes base edits
//! (crop/rotation/spatial/masks) a single round trip too.
//!
//! The FFI surface lives in [`crate::api::preview`]; this module holds the
//! store and pipeline so the bridge codegen never sees the private types.
//!
//! Concurrency: the store lock is only ever held for `Arc` cloning — never
//! across pixel math. The source and the cached base are `Arc`'d, so a
//! concurrent [`histogram_from_base`] never blocks behind a running
//! [`run_base`], and the common path allocates nothing per tick (the
//! pipeline works on borrowed slices via `Cow`; only engaged ops allocate).
//!
//! Scope: like the Dart `_baseKey` this mirrors, the CPU bake covers
//! flip/rotate/crop + spatial + masks only. Straighten/perspective/skew are
//! live-warped on the GPU with a `Matrix4` (issues #36/#52) — baking them
//! here too would double-apply the warp. Export bakes the full
//! `GeometrySpec` independently via `geometry_apply`, which shares
//! [`crop_opt`] with this module so the two paths cannot drift.
//!
//! Flutter `Texture` delivery (update-in-place, no return frame at all) is
//! spike B and needs device-side `TextureRegistry` plumbing — the handle
//! returned here is the seam it will plug into.

use std::borrow::Cow;
use std::collections::HashMap;
use std::ffi::c_void;
use std::sync::{Arc, LazyLock, Mutex, PoisonError};
use zune_jpeg::JpegDecoder;

use crate::api::color::{to_hsl24, ColorParams, CurveParams};
use crate::api::decode::RgbaImage;
use crate::api::mask::MaskLayer;
use crate::api::preview::PreviewBaseSpec;
use crate::color;
use crate::geometry;
use crate::histogram;
use crate::mask::{self, LocalAdjustment, MaskSpec};
use crate::optics::{self, OpticsParams};
use crate::retouch::RetouchPatch;
use crate::spatial::{self, SpatialParams};

/// Preview images resident in Rust, keyed by the handle handed to Dart.
#[derive(Default)]
struct Store {
    next: u64,
    images: HashMap<u64, Resident>,
}

struct Resident {
    /// Shared so [`run_base`] can borrow the pixels after dropping the
    /// store lock (cloning the `Arc` is a pointer copy, not an 8 MB memcpy).
    source: Arc<[u8]>,
    width: u32,
    height: u32,
    /// Last `run_base` output — the histogram bins from this, never from
    /// the raw source, so the drawer reflects geometry + spatial + masks.
    base: Option<Arc<RgbaImage>>,
    /// Cached AI depth map for lens blur subject protection (width*height
    /// f32 plane in [0.0, 1.0], lower = closer). Set via
    /// [`crate::api::preview::preview_set_depth_map`].
    depth_map: Option<Vec<f32>>,
    /// Spike B: platform window backing a Flutter `Texture` (an
    /// `ANativeWindow*` on Android, as `usize`). 0 = unbound; unbound
    /// handles use the return-frame path instead.
    window: usize,
}

static STORE: LazyLock<Mutex<Store>> = LazyLock::new(|| Mutex::new(Store::default()));

fn lock_store() -> std::sync::MutexGuard<'static, Store> {
    // A panic inside one call must not brick every later call.
    STORE.lock().unwrap_or_else(PoisonError::into_inner)
}

/// Uploads decoded RGBA pixels into the resident store; returns a handle.
///
/// `Arc::from(Vec)` reuses the FFI-delivered allocation, so this is O(1).
pub fn open(rgba: Vec<u8>, width: u32, height: u32) -> u64 {
    let mut store = lock_store();
    let id = store.next;
    store.next += 1;
    store.images.insert(
        id,
        Resident {
            source: Arc::from(rgba),
            width,
            height,
            base: None,
            depth_map: None,
            window: 0,
        },
    );
    id
}

pub fn get_source_rgba(handle: u64) -> Result<RgbaImage, String> {
    let store = lock_store();
    let resident = store
        .images
        .get(&handle)
        .ok_or_else(|| format!("unknown preview handle {handle}"))?;

    Ok(RgbaImage {
        width: resident.width,
        height: resident.height,
        rgba: resident.source.to_vec(),
    })
}

/// Decodes a JPEG into a resident proxy.
pub fn open_jpeg(jpeg_bytes: Vec<u8>, max_dim: u32) -> Result<u64, String> {
    let mut decoder = JpegDecoder::new(std::io::Cursor::new(jpeg_bytes));
    decoder
        .decode_headers()
        .map_err(|e| format!("JPEG headers failed: {e}"))?;

    let (width, height) = decoder
        .dimensions()
        .ok_or_else(|| "JPEG dimensions failed".to_string())?;

    let scale = (max_dim as f32 / width.max(height) as f32).min(1.0);
    let target_w = (width as f32 * scale) as u32;
    let target_h = (height as f32 * scale) as u32;

    let rgba = decoder
        .decode()
        .map_err(|e| format!("JPEG decode failed: {e}"))?;

    let mut rgba_buffer = Vec::with_capacity(target_w as usize * target_h as usize * 4);

    for y in 0..target_h {
        let src_y = (y as f32 / scale) as usize;
        if src_y >= height {
            break;
        }
        for x in 0..target_w {
            let src_x = (x as f32 / scale) as usize;
            if src_x >= width {
                continue;
            }

            let idx = (src_y * width + src_x) * 3;
            if idx + 2 >= rgba.len() {
                continue;
            }

            rgba_buffer.push(rgba[idx]); // R
            rgba_buffer.push(rgba[idx + 1]); // G
            rgba_buffer.push(rgba[idx + 2]); // B
            rgba_buffer.push(255); // A
        }
    }

    Ok(open(rgba_buffer, target_w, target_h))
}

/// Drops the resident image for [handle]. Unknown handles are ignored so
/// double-close from Dart teardown is safe.
pub fn close(handle: u64) {
    let window = {
        let mut store = lock_store();
        store.images.remove(&handle).map(|r| r.window)
    };
    // Release outside the lock — ANativeWindow_release may block on the compositor.
    if let Some(w) = window.filter(|w| *w != 0) {
        anative_window::release(w);
    }
}

/// Stores an AI-computed depth map for [handle]. The depth map is a
/// `width * height` plane of `f32` values in `[0.0, 1.0]` where lower =
/// closer (more in focus). Used by the lens blur stage to protect subjects.
pub fn set_depth_map(handle: u64, depth_map: Vec<f32>) -> Result<(), String> {
    let mut store = lock_store();
    let resident = store
        .images
        .get_mut(&handle)
        .ok_or_else(|| format!("unknown preview handle {handle}"))?;
    resident.depth_map = Some(depth_map);
    Ok(())
}

/// Binds a platform window (spike B) to [handle]: `render` will write its
/// frames there instead of returning them across the bridge.
///
/// [window_ptr] is an `ANativeWindow*` obtained by the platform via
/// `ANativeWindow_fromSurface` (Android only — other targets always error,
/// and Dart falls back to the return-frame path).
pub fn bind_window(handle: u64, window_ptr: i64) -> Result<(), String> {
    if window_ptr == 0 {
        return Err("preview_bind_window: null window pointer".into());
    }
    let previous = {
        let mut store = lock_store();
        let resident = store
            .images
            .get_mut(&handle)
            .ok_or_else(|| format!("unknown preview handle {handle}"))?;
        std::mem::replace(&mut resident.window, window_ptr as usize)
    };
    if previous != 0 {
        anative_window::release(previous);
    }
    Ok(())
}

/// Fused base (+ optional grade) baked straight into the bound platform
/// window — **zero pixels cross the bridge** (spike B). The pre-grade frame
/// is still cached for [`histogram_from_base`], so the histogram keeps its
/// spike-A semantics.
///
/// Errors when no window is bound; Dart catches that and uses the
/// return-frame path ([`run_base`]) instead.
#[allow(clippy::too_many_arguments)]
pub fn render(
    handle: u64,
    spec: &PreviewBaseSpec,
    layers: &[MaskLayer],
    patches: &[RetouchPatch],
    params: &ColorParams,
    curves: &CurveParams,
    hsl: &[f32],
    base_changed: bool,
) -> Result<(u32, u32), String> {
    // 1. Borrow source + window under the lock; drop it before any math.
    let (source, src_w, src_h, window) = {
        let store = lock_store();
        let resident = store
            .images
            .get(&handle)
            .ok_or_else(|| format!("unknown preview handle {handle}"))?;
        if resident.window == 0 {
            return Err(format!(
                "preview handle {handle} has no bound texture; \
                 use preview_base (return-frame path) or bind a window first"
            ));
        }
        (
            Arc::clone(&resident.source),
            resident.width,
            resident.height,
            resident.window,
        )
    };

    // 2. Resolve the cache when this is a grade-only tick.
    let cached = if base_changed {
        None
    } else {
        let store = lock_store();
        store.images.get(&handle).and_then(|r| r.base.clone())
    };

    // 3a. Neutral grade + cached base: write straight from the shared Arc —
    //     no copy, no bake.
    if let Some(base) = &cached {
        if grade_is_neutral(params, curves, hsl) {
            anative_window::write_rgba(window, &base.rgba, base.width, base.height)?;
            return Ok((base.width, base.height));
        }
    }

    // 3b. Otherwise own the frame: clone the cache, or bake + cache it.
    let mut frame = match cached {
        Some(base) => (*base).clone(),
        None => {
            let fb = bake_base(handle, &source, src_w, src_h, spec, layers, patches);
            cache_base(handle, &fb);
            fb
        }
    };

    // 4. Grade in place (skipped when neutral).
    if !grade_is_neutral(params, curves, hsl) {
        let p = params.to_core();
        let set = curves.to_set();
        let hsl24 = to_hsl24(hsl);
        for px in frame.rgba.as_chunks_mut::<4>().0 {
            let c = color::grade_pixel_c(
                px[0] as f32 / 255.0,
                px[1] as f32 / 255.0,
                px[2] as f32 / 255.0,
                p,
                Some(&set),
                &hsl24,
            );
            px[0] = (c[0] * 255.0 + 0.5) as u8;
            px[1] = (c[1] * 255.0 + 0.5) as u8;
            px[2] = (c[2] * 255.0 + 0.5) as u8;
        }
    }

    // 5. Straight into the platform window.
    anative_window::write_rgba(window, &frame.rgba, frame.width, frame.height)?;

    Ok((frame.width, frame.height))
}

/// True when the grade contributes nothing, so [`render`] can skip it.
fn grade_is_neutral(params: &ColorParams, curves: &CurveParams, hsl: &[f32]) -> bool {
    params.is_neutral()
        && curves.master.is_empty()
        && curves.red.is_empty()
        && curves.green.is_empty()
        && curves.blue.is_empty()
        && hsl.iter().all(|v| *v == 0.0)
}

/// Fused base pipeline on the resident source: flip → rotate → normalized
/// crop → spatial pass → mask layers.
///
/// The store lock is taken only to `Arc::clone` the source (and again at the
/// end to cache the result); all pixel work runs on the caller's thread with
/// no lock held, so a concurrent [`histogram_from_base`] is never starved.
///
/// Returns the baked frame — Dart still needs one copy to build its
/// `ui.Image` until spike B's Texture delivery lands. Engaged ops allocate
/// their output as before; the fully-neutral path clones exactly once (for
/// the return value), never the per-stage clone storm of the old chain.
pub fn run_base(
    handle: u64,
    spec: &PreviewBaseSpec,
    layers: &[MaskLayer],
    patches: &[RetouchPatch],
) -> Result<RgbaImage, String> {
    // 1. Borrow the source under the lock; drop the lock before any math.
    let (source, src_w, src_h) = {
        let store = lock_store();
        let resident = store
            .images
            .get(&handle)
            .ok_or_else(|| format!("unknown preview handle {handle}"))?;
        (
            Arc::clone(&resident.source),
            resident.width,
            resident.height,
        )
    };

    // 2. Heavy math with no lock held.
    let frame = bake_base(handle, &source, src_w, src_h, spec, layers, patches);

    // 3. Re-lock only to cache an Arc of the result for the histogram.
    cache_base(handle, &frame);

    Ok(frame)
}

/// The fused pipeline proper: flip → rotate → normalized crop → spatial →
/// masks, on borrowed slices (`Cow::Borrowed` until an op engages, so the
/// neutral path never copies the source). Shared by [`run_base`] and
/// [`render`] so the texture and return-frame paths cannot drift.
fn bake_base(
    handle: u64,
    source: &[u8],
    src_w: u32,
    src_h: u32,
    spec: &PreviewBaseSpec,
    layers: &[MaskLayer],
    patches: &[RetouchPatch],
) -> RgbaImage {
    let (mut buf, mut w, mut h): (Cow<'_, [u8]>, u32, u32) = (Cow::Borrowed(source), src_w, src_h);

    if spec.flip_h {
        buf = Cow::Owned(geometry::flip_h(&buf, w as usize, h as usize));
    }
    if spec.flip_v {
        buf = Cow::Owned(geometry::flip_v(&buf, w as usize, h as usize));
    }
    if !spec.turns.is_multiple_of(4) {
        let (b, nw, nh) = geometry::rotate_quarter(&buf, w as usize, h as usize, spec.turns);
        buf = Cow::Owned(b);
        w = nw as u32;
        h = nh as u32;
    }
    if let Some((b, cw, ch)) = crop_opt(
        &buf,
        w,
        h,
        spec.crop_l,
        spec.crop_t,
        spec.crop_r,
        spec.crop_b,
    ) {
        buf = Cow::Owned(b);
        w = cw;
        h = ch;
    }

    let spatial_params = SpatialParams {
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
    };
    let optics_params = OpticsParams {
        remove_chromatic_aberration: spec.remove_chromatic_aberration,
        defringe_purple_amount: spec.defringe_purple_amount,
        defringe_purple_hue_min: spec.defringe_purple_hue_min,
        defringe_purple_hue_max: spec.defringe_purple_hue_max,
        defringe_green_amount: spec.defringe_green_amount,
        defringe_green_hue_min: spec.defringe_green_hue_min,
        defringe_green_hue_max: spec.defringe_green_hue_max,
        profile_corrections: spec.profile_corrections,
        profile_distortion: spec.profile_distortion,
        profile_vignetting: spec.profile_vignetting,
    };
    if !optics_params.is_neutral() {
        buf = Cow::Owned(optics::apply_optics(
            &buf,
            w as usize,
            h as usize,
            optics_params,
        ));
    }
    if !patches.is_empty() {
        let buf = buf.to_mut();
        for patch in patches {
            crate::retouch::apply_patch(buf, w as usize, h as usize, patch);
        }
    }
    // Depth-aware lens blur sits at the same stage as the export pipeline
    // (geometry → optics → blur → spatial → masks) so preview == export.
    let blur_params = spec.blur_params();
    if !blur_params.is_neutral() {
        // Retrieve cached AI depth map (if any) so subjects stay sharp while
        // background blurs. Falls back to None → synthetic depth gradient.
        let depth_map = {
            let store = lock_store();
            store
                .images
                .get(&handle)
                .and_then(|r| r.depth_map.as_ref())
                .cloned()
        };
        buf = Cow::Owned(crate::blur::apply_lens_blur(
            &buf,
            w as usize,
            h as usize,
            blur_params,
            depth_map.as_deref(),
            36,
        ));
    }
    // apply_spatial clones on the neutral path — skip it entirely.
    if !spatial_params.is_neutral() {
        buf = Cow::Owned(spatial::apply_spatial(
            &buf,
            w as usize,
            h as usize,
            spatial_params,
        ));
    }

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
        buf = Cow::Owned(mask::apply_local(&buf, w as usize, h as usize, &core));
    }

    RgbaImage {
        width: w,
        height: h,
        rgba: buf.into_owned(),
    }
}

/// Stores an Arc of [frame] as the histogram source for [handle]. A missing
/// handle (closed mid-bake) is fine — the result is simply dropped.
fn cache_base(handle: u64, frame: &RgbaImage) {
    let mut store = lock_store();
    if let Some(resident) = store.images.get_mut(&handle) {
        resident.base = Some(Arc::new(RgbaImage {
            width: frame.width,
            height: frame.height,
            rgba: frame.rgba.clone(),
        }));
    }
}

/// Bins the **cached base** (after geometry/spatial/masks) through the
/// colour pipeline. No pixels cross the bridge — only params in, four
/// 256-bin `Vec<u32>` channels out. The base `Arc` is cloned and the lock
/// dropped before binning, so this runs concurrently with a later
/// [`run_base`] without waiting on it.
pub fn histogram_from_base(
    handle: u64,
    params: crate::api::color::ColorParams,
    sample_dim: u32,
    curves: &crate::api::color::CurveParams,
    hsl: &[f32],
) -> Result<histogram::Histogram, String> {
    let base = {
        let store = lock_store();
        let resident = store
            .images
            .get(&handle)
            .ok_or_else(|| format!("unknown preview handle {handle}"))?;
        let base = resident.base.as_ref().ok_or_else(|| {
            format!("preview handle {handle} has no base; call preview_base first")
        })?;
        Arc::clone(base)
    };

    let set = curves.to_set();
    Ok(histogram::histogram_graded(
        &base.rgba,
        base.width,
        base.height,
        params.to_core(),
        sample_dim,
        Some(&set),
        &to_hsl24(hsl),
    ))
}

/// Normalized `[0,1]` crop shared by [`run_base`] and `geometry_apply`.
///
/// Returns `None` when the crop is the identity (or degenerate) so callers
/// keep their existing buffer instead of paying a full-frame copy.
pub fn crop_opt(
    buf: &[u8],
    w: u32,
    h: u32,
    crop_l: f32,
    crop_t: f32,
    crop_r: f32,
    crop_b: f32,
) -> Option<(Vec<u8>, u32, u32)> {
    geometry::crop_normalized(buf, w as usize, h as usize, crop_l, crop_t, crop_r, crop_b)
        .map(|(b, cw, ch)| (b, cw as u32, ch as u32))
}

// --- platform window (spike B) --------------------------------------------
//
// Flutter's `FragmentShader.setImageSampler` accepts only a `ui.Image`, never
// a `Texture` widget, so a texture-based preview must carry the **graded**
// frame — the grade is baked in Rust (LUT) before the write. This module owns
// the `ANativeWindow` write path (Android) and a stub for every other target
// (which simply errors, so Dart keeps the spike-A return-frame fallback).

/// Opaque NDK handle; only used behind a pointer.
#[repr(C)]
#[cfg_attr(not(target_os = "android"), allow(dead_code))]
pub struct ANativeWindow {
    _private: [u8; 0],
}

/// NDK `ANativeWindow_Buffer` (android/window.h). Defined on every target so
/// the layout test below can run in host CI — a wrong offset here makes
/// `bits` read `height | stride << 32` and segfaults on the first frame.
#[repr(C)]
#[cfg_attr(not(target_os = "android"), allow(dead_code))]
pub struct ANativeWindowBuffer {
    pub width: i32,
    pub height: i32,
    pub stride: i32,
    pub format: i32,
    pub bits: *mut c_void,
    pub reserved: [u32; 6],
}

#[cfg(test)]
mod anative_window_buffer_layout {
    use super::ANativeWindowBuffer;
    use std::mem::{align_of, offset_of, size_of};

    #[test]
    fn matches_ndk_anative_window_buffer() {
        assert_eq!(size_of::<ANativeWindowBuffer>(), 48);
        assert_eq!(align_of::<ANativeWindowBuffer>(), 8);
        assert_eq!(offset_of!(ANativeWindowBuffer, width), 0);
        assert_eq!(offset_of!(ANativeWindowBuffer, height), 4);
        assert_eq!(offset_of!(ANativeWindowBuffer, stride), 8);
        assert_eq!(offset_of!(ANativeWindowBuffer, format), 12);
        assert_eq!(offset_of!(ANativeWindowBuffer, bits), 16);
    }
}

#[cfg(test)]
mod open_jpeg_tests {
    use super::*;
    use jpeg_encoder::Encoder;

    /// Encodes a solid-color RGB image to JPEG bytes.
    fn encode_jpeg_rgb(w: u16, h: u16, rgb: [u8; 3]) -> Vec<u8> {
        let mut pixels = Vec::with_capacity((w * h * 3) as usize);
        for _ in 0..(w as usize * h as usize) {
            pixels.extend_from_slice(&rgb);
        }
        let mut buf = Vec::new();
        let encoder = Encoder::new(&mut buf, 90);
        encoder
            .encode(&pixels, w, h, jpeg_encoder::ColorType::Rgb)
            .unwrap();
        buf
    }

    #[test]
    fn open_jpeg_decodes_into_resident_proxy() {
        let jpeg = encode_jpeg_rgb(2, 2, [128, 64, 32]);
        let h = open_jpeg(jpeg.clone(), 1440).unwrap();
        let src = get_source_rgba(h).unwrap();
        assert_eq!((src.width, src.height), (2, 2));
        assert_eq!(src.rgba.len(), 16);
        for (i, chunk) in src.rgba.as_chunks::<4>().0.iter().enumerate() {
            assert!(
                chunk[0].abs_diff(128) <= 4
                    && chunk[1].abs_diff(64) <= 4
                    && chunk[2].abs_diff(32) <= 4,
                "pixel {i} must approximate encoded RGB: {:?}",
                chunk
            );
            assert_eq!(chunk[3], 255, "pixel {i} alpha must be opaque");
        }
        close(h);
    }

    #[test]
    fn open_jpeg_respects_max_dim_downscale() {
        let jpeg = encode_jpeg_rgb(8, 8, [200, 100, 50]);
        let h = open_jpeg(jpeg, 2).unwrap();
        let src = get_source_rgba(h).unwrap();
        assert_eq!((src.width, src.height), (2, 2));
        close(h);
    }

    #[test]
    fn open_jpeg_invalid_bytes_returns_error() {
        let result = open_jpeg(vec![0x00, 0x01, 0x02], 1440);
        assert!(
            result.is_err(),
            "invalid JPEG bytes must error, got {:?}",
            result
        );
    }
}

#[cfg(target_os = "android")]
mod anative_window {
    use super::{ANativeWindow, ANativeWindowBuffer};
    use std::ffi::c_void;

    /// `WINDOW_FORMAT_RGBA_8888` from the NDK pixel-format enum.
    const WINDOW_FORMAT_RGBA_8888: i32 = 1;

    #[link(name = "android")]
    extern "C" {
        fn ANativeWindow_fromSurface(env: *mut c_void, surface: *mut c_void) -> *mut ANativeWindow;
        fn ANativeWindow_release(window: *mut ANativeWindow);
        fn ANativeWindow_setBuffersGeometry(
            window: *mut ANativeWindow,
            width: i32,
            height: i32,
            format: i32,
        ) -> i32;
        /// Fills `out_buffer` **in place** (`ANativeWindow_Buffer*`, exactly
        /// like the NDK header) — it is NOT a pointer-to-pointer. Declaring it
        /// as `*mut *mut` makes the NDK scribble the 48-byte struct over the
        /// caller's 8-byte stack slot (width/height reinterpreting as a
        /// pointer, stride/format/bits/reserved smashing the frame), which
        /// segfaults on `(*buffer).bits` at the first lock.
        fn ANativeWindow_lock(
            window: *mut ANativeWindow,
            out_buffer: *mut ANativeWindowBuffer,
            in_out_dirty: *mut c_void,
        ) -> i32;
        fn ANativeWindow_unlockAndPost(window: *mut ANativeWindow) -> i32;
    }

    /// Wraps a Java `Surface` (received via JNI) in a refcounted
    /// `ANativeWindow*`. The caller owns the returned window.
    pub fn from_surface(env: *mut c_void, surface: *mut c_void) -> usize {
        if surface.is_null() {
            return 0;
        }
        unsafe { ANativeWindow_fromSurface(env, surface) as usize }
    }

    /// Releases a window obtained from [`from_surface`]. Safe on 0.
    pub fn release(window: usize) {
        if window == 0 {
            return;
        }
        unsafe { ANativeWindow_release(window as *mut ANativeWindow) };
    }

    /// Copies an RGBA frame into the window's back buffer and posts it, so
    /// Flutter's texture registry picks it up on the next vsync.
    pub fn write_rgba(window: usize, rgba: &[u8], width: u32, height: u32) -> Result<(), String> {
        if window == 0 {
            return Err("write_rgba: null window".into());
        }
        let needed = (width as usize)
            .checked_mul(height as usize)
            .and_then(|px| px.checked_mul(4))
            .ok_or_else(|| "write_rgba: frame dimensions overflow".to_string())?;
        if rgba.len() < needed {
            return Err(format!(
                "write_rgba: rgba buffer too small ({} < {needed} for {width}x{height})",
                rgba.len()
            ));
        }
        let win = window as *mut ANativeWindow;
        unsafe {
            // Keep the buffer geometry in sync — crop/rotate change dims.
            let geo = ANativeWindow_setBuffersGeometry(
                win,
                width as i32,
                height as i32,
                WINDOW_FORMAT_RGBA_8888,
            );
            if geo != 0 {
                return Err(format!("ANativeWindow_setBuffersGeometry failed: {geo}"));
            }

            let mut buffer = std::mem::MaybeUninit::<ANativeWindowBuffer>::uninit();
            let locked = ANativeWindow_lock(win, buffer.as_mut_ptr(), std::ptr::null_mut());
            if locked != 0 {
                return Err(format!("ANativeWindow_lock failed: {locked}"));
            }
            let buffer = buffer.assume_init();

            let bits = buffer.bits as *mut u8;
            let stride = buffer.stride.max(0) as usize;
            if bits.is_null() {
                ANativeWindow_unlockAndPost(win);
                return Err("ANativeWindow_lock returned a null buffer".into());
            }
            // The buffer may come back smaller or more padded than asked;
            // never write past it, and never read past the source frame.
            let buf_w = buffer.width.max(0) as usize;
            let buf_h = buffer.height.max(0) as usize;
            if stride < width as usize || buf_w < width as usize || buf_h < height as usize {
                ANativeWindow_unlockAndPost(win);
                return Err(format!(
                    "window buffer too small: {buf_w}x{buf_h} stride {stride} for {width}x{height} frame"
                ));
            }
            // The buffer stride may be padded past width*4; copy row by row.
            let row_bytes = width as usize * 4;
            for y in 0..height as usize {
                let src = &rgba[y * row_bytes..][..row_bytes];
                let dst = std::slice::from_raw_parts_mut(bits.add(y * stride * 4), row_bytes);
                dst.copy_from_slice(src);
            }
            ANativeWindow_unlockAndPost(win);
        }
        Ok(())
    }
}

/// Non-Android targets have no `ANativeWindow`; every write errors so Dart
/// keeps the return-frame fallback (spike A). The JNI entry point is
/// Android-only, so `from_surface` is never referenced here.
#[cfg(not(target_os = "android"))]
mod anative_window {
    pub fn release(_window: usize) {}

    pub fn write_rgba(
        _window: usize,
        _rgba: &[u8],
        _width: u32,
        _height: u32,
    ) -> Result<(), String> {
        Err("preview textures are Android-only (spike B); use preview_base".into())
    }
}

/// JNI entry point invoked by `MainActivity.bindPreviewSurface`. Wraps the
/// Java `Surface` in an `ANativeWindow` and binds it to the preview [handle].
/// Returns the window pointer (0 on failure) so the Kotlin side can log it.
#[cfg(target_os = "android")]
#[no_mangle]
pub extern "system" fn Java_com_devparadise_aperturex_MainActivity_bindPreviewSurface(
    env: *mut std::ffi::c_void,
    _this: *mut std::ffi::c_void,
    surface: *mut std::ffi::c_void,
    handle: i64,
) -> i64 {
    let window = anative_window::from_surface(env, surface);
    if window == 0 {
        return 0;
    }
    match bind_window(handle as u64, window as i64) {
        Ok(()) => window as i64,
        Err(_) => {
            anative_window::release(window);
            0
        }
    }
}
