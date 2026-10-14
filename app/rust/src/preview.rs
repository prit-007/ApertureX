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
use std::sync::{Arc, LazyLock, Mutex, PoisonError};

use crate::api::color::to_hsl24;
use crate::api::decode::RgbaImage;
use crate::api::mask::MaskLayer;
use crate::api::preview::PreviewBaseSpec;
use crate::geometry;
use crate::histogram;
use crate::mask::{self, LocalAdjustment, MaskSpec};
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
        },
    );
    id
}

/// Drops the resident image for [handle]. Unknown handles are ignored so
/// double-close from Dart teardown is safe.
pub fn close(handle: u64) {
    lock_store().images.remove(&handle);
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

    // 2. Heavy math with no lock held. `Cow::Borrowed` until an op engages,
    //    so the neutral path never copies the source.
    let (mut buf, mut w, mut h): (Cow<'_, [u8]>, u32, u32) =
        (Cow::Borrowed(source.as_ref()), src_w, src_h);

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
        denoise_luma: spec.denoise_luma,
        denoise_chroma: spec.denoise_chroma,
        dehaze: spec.dehaze,
        vignette: spec.vignette,
        grain: spec.grain,
    };
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
            })
            .collect();
        buf = Cow::Owned(mask::apply_local(&buf, w as usize, h as usize, &core));
    }

    let frame = RgbaImage {
        width: w,
        height: h,
        rgba: buf.into_owned(),
    };

    // 3. Re-lock only to cache an Arc of the result for the histogram.
    {
        let mut store = lock_store();
        if let Some(resident) = store.images.get_mut(&handle) {
            resident.base = Some(Arc::new(RgbaImage {
                width: frame.width,
                height: frame.height,
                rgba: frame.rgba.clone(),
            }));
        }
    }

    Ok(frame)
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
    let (cl, ct, cr, cb) = (
        crop_l.clamp(0.0, 1.0),
        crop_t.clamp(0.0, 1.0),
        crop_r.clamp(0.0, 1.0),
        crop_b.clamp(0.0, 1.0),
    );
    if cl == 0.0 && ct == 0.0 && cr == 1.0 && cb == 1.0 {
        return None;
    }
    if cr <= cl || cb <= ct {
        return None;
    }
    let x = (cl * w as f32).round() as usize;
    let y = (ct * h as f32).round() as usize;
    let cw = (((cr - cl) * w as f32).round() as usize).clamp(1, w as usize - x);
    let ch = (((cb - ct) * h as f32).round() as usize).clamp(1, h as usize - y);
    Some((
        geometry::crop(buf, w as usize, h as usize, x, y, cw, ch),
        cw as u32,
        ch as u32,
    ))
}
