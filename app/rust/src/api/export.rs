//! JPEG encode + full-res export API across the `flutter_rust_bridge` boundary.
//!
//! [`encode_jpeg_rgba`] is the pure encode step (the legacy Dart path grades
//! via `grade_rgba` then calls this). [`export_full`] is the P4 replacement: it
//! runs the whole recipe — geometry → banded spatial → masks → grade → optional
//! downscale → JPEG encode — inside Rust in **one** call, so a 24–50 MP export
//! crosses the bridge once instead of five times and never needs several
//! full-size buffers in flight. A cancel token ([`export_cancel_new`] /
//! [`export_cancel_set`]) lets the UI abort a running export between bands.

use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::{Arc, LazyLock, Mutex, PoisonError};

use crate::api::color::{to_hsl24, ColorParams, CurveParams};
use crate::api::mask::MaskLayer;
use crate::export;
use crate::export_pipeline::{self, ExportOutcome, ExportRecipe};
use crate::geometry::{self, GeometrySpec};
use crate::mask::{self, LocalAdjustment};
use crate::optics::OpticsParams;
use crate::spatial::SpatialParams;

/// Encodes an RGBA8 buffer as a JPEG (alpha dropped). [exif] (a full APP1
/// segment from the source, or empty) is injected to preserve metadata.
pub fn encode_jpeg_rgba(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    quality: u8,
    exif: Vec<u8>,
) -> Result<Vec<u8>, String> {
    export::encode_jpeg(&rgba, width, height, quality, &exif)
}

/// Exports raw camera CFA samples into a lossless DNG format with injected XMP sidecar (#79).
pub fn export_raw_dng(raw_bytes: Vec<u8>, xmp: String) -> Result<Vec<u8>, String> {
    crate::raw::export_dng(&raw_bytes, &xmp)
}

/// Everything [`export_full`] bakes, in one bridge struct — geometry, spatial,
/// and the encode knobs. Grade/curves/HSL/layers arrive as their own args so
/// they reuse the existing bridge types.
pub struct ExportSpec {
    // geometry
    pub flip_h: bool,
    pub flip_v: bool,
    /// Quarter-turns clockwise.
    pub turns: u32,
    /// Straighten angle in degrees (0 = off).
    pub angle: f32,
    /// Normalized `[0,1]` crop in the transformed frame.
    pub crop_l: f32,
    pub crop_t: f32,
    pub crop_r: f32,
    pub crop_b: f32,
    pub perspective_x: f32,
    pub perspective_y: f32,
    pub skew_x: f32,
    pub skew_y: f32,
    // spatial
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
    // optics
    pub remove_chromatic_aberration: bool,
    pub defringe_purple_amount: f32,
    pub defringe_purple_hue_min: f32,
    pub defringe_purple_hue_max: f32,
    pub defringe_green_amount: f32,
    pub defringe_green_hue_min: f32,
    pub defringe_green_hue_max: f32,
    // encode
    pub quality: u8,
    /// Longest-side cap for the export (0 = full resolution).
    pub max_dim: u32,
    /// Band height for the banded stages (0 = a 256-row default).
    pub band_rows: u32,
    /// Opaque cancel token from [`export_cancel_new`] (0 = no cancellation).
    pub cancel_token: u64,
}

/// The result of [`export_full`]: JPEG bytes, or a flag when the export was
/// cancelled before it finished encoding.
#[derive(Debug)]
pub struct ExportResult {
    /// True when a cancel token fired — [jpeg] is then empty.
    pub cancelled: bool,
    pub jpeg: Vec<u8>,
}

// --- cancel tokens ---------------------------------------------------------
//
// Same handle-store pattern as the preview module: Dart keeps an opaque `u64`
// and the `Arc<AtomicBool>` lives in Rust, so the export worker thread and the
// UI thread (which calls `export_cancel_set`) share it without a lock across
// pixel math — the flag is only ever polled between bands. Each token also
// carries a progress cell (permille 0–1000) the worker updates between bands
// and the UI polls via `export_progress_get` for a determinate bar.

struct CancelStore {
    /// Starts at 1: token 0 is reserved as the "no cancellation" sentinel.
    next: u64,
    tokens: HashMap<u64, (Arc<AtomicBool>, Arc<AtomicU32>)>,
}

static CANCELS: LazyLock<Mutex<CancelStore>> = LazyLock::new(|| {
    Mutex::new(CancelStore {
        next: 1,
        tokens: HashMap::new(),
    })
});

fn lock_cancels() -> std::sync::MutexGuard<'static, CancelStore> {
    CANCELS.lock().unwrap_or_else(PoisonError::into_inner)
}

/// Creates a cancel token. Pass it to [`export_full`], call
/// [`export_cancel_set`] from the UI to abort, then [`export_cancel_drop`].
pub fn export_cancel_new() -> u64 {
    let mut store = lock_cancels();
    let id = store.next;
    store.next += 1;
    store.tokens.insert(
        id,
        (
            Arc::new(AtomicBool::new(false)),
            Arc::new(AtomicU32::new(0)),
        ),
    );
    id
}

/// Signals the export bound to [token] to abort at its next band boundary.
/// Safe on unknown tokens (a race with [`export_cancel_drop`] is benign).
pub fn export_cancel_set(token: u64) {
    let flag = { lock_cancels().tokens.get(&token).map(|(f, _)| f.clone()) };
    if let Some(f) = flag {
        f.store(true, Ordering::Relaxed);
    }
}

/// Drops [token]. Double-drop and unknown tokens are ignored.
pub fn export_cancel_drop(token: u64) {
    lock_cancels().tokens.remove(&token);
}

/// Reads the progress cell bound to [token] in permille (0–1000). Token 0 and
/// unknown/dropped tokens report 0 — the UI treats that as "no data yet".
pub fn export_progress_get(token: u64) -> u32 {
    let cell = { lock_cancels().tokens.get(&token).map(|(_, p)| p.clone()) };
    match cell {
        Some(p) => p.load(Ordering::Relaxed),
        None => 0,
    }
}

/// Resolves [token] to its shared cancel flag and progress cell (or `None`
/// for token 0 / unknown).
fn cancel_flag(token: u64) -> Option<(Arc<AtomicBool>, Arc<AtomicU32>)> {
    if token == 0 {
        return None;
    }
    lock_cancels().tokens.get(&token).cloned()
}

// --- full export -----------------------------------------------------------

/// Runs the whole export recipe in Rust in one call and returns the JPEG.
///
/// The geometry stage runs full-frame; spatial + masks + grade run one band at a
/// time (bounded memory, seamless — see `export_pipeline`). [spec.cancel_token]
/// is polled between bands, so a cancelled export returns
/// `ExportResult { cancelled: true, .. }` without finishing.
#[allow(clippy::too_many_arguments)]
pub fn export_full(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    spec: ExportSpec,
    layers: Vec<MaskLayer>,
    params: ColorParams,
    curves: CurveParams,
    hsl: Vec<f32>,
    exif: Vec<u8>,
) -> Result<ExportResult, String> {
    let (w, h) = (width as usize, height as usize);
    let expected = w * h * 4;
    if rgba.len() != expected {
        return Err(format!(
            "rgba buffer has {} bytes, expected {expected} for {width}x{height}",
            rgba.len()
        ));
    }

    let recipe = ExportRecipe {
        geometry: GeometrySpec {
            flip_h: spec.flip_h,
            flip_v: spec.flip_v,
            turns: spec.turns,
            angle: spec.angle,
            crop_l: spec.crop_l,
            crop_t: spec.crop_t,
            crop_r: spec.crop_r,
            crop_b: spec.crop_b,
            perspective_x: spec.perspective_x,
            perspective_y: spec.perspective_y,
            skew_x: spec.skew_x,
            skew_y: spec.skew_y,
        },
        optics: OpticsParams {
            remove_chromatic_aberration: spec.remove_chromatic_aberration,
            defringe_purple_amount: spec.defringe_purple_amount,
            defringe_purple_hue_min: spec.defringe_purple_hue_min,
            defringe_purple_hue_max: spec.defringe_purple_hue_max,
            defringe_green_amount: spec.defringe_green_amount,
            defringe_green_hue_min: spec.defringe_green_hue_min,
            defringe_green_hue_max: spec.defringe_green_hue_max,
            profile_corrections: false,
            profile_distortion: 1.0,
            profile_vignetting: 1.0,
        },
        blur: crate::blur::LensBlurParams::default(),
        spatial: SpatialParams {
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
            ..Default::default()
        },
        layers: layers
            .iter()
            .map(|l| LocalAdjustment {
                mask: mask::MaskSpec {
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
            .collect(),
        grade: params.to_core(),
        curves: curves.to_set(),
        hsl: to_hsl24(&hsl),
    };

    let token_parts = cancel_flag(spec.cancel_token);
    let cancel = token_parts.as_ref().map(|(f, _)| f.clone());
    let progress = token_parts.as_ref().map(|(_, p)| p.clone());
    let band_rows = if spec.band_rows == 0 {
        256
    } else {
        spec.band_rows as usize
    };

    let outcome = export_pipeline::run_export_tiled(
        &recipe,
        &rgba,
        w,
        h,
        band_rows,
        cancel.as_deref(),
        progress.as_deref(),
    )?;

    let frame = match outcome {
        ExportOutcome::Cancelled => {
            return Ok(ExportResult {
                cancelled: true,
                jpeg: Vec::new(),
            })
        }
        ExportOutcome::Done(f) => f,
    };

    // Optional longest-side downscale (matches the legacy Dart `exportJpeg`).
    let (rgba, out_w, out_h) = if spec.max_dim > 0 {
        let (d, dw, dh) = geometry::downscale(
            &frame.rgba,
            frame.width as usize,
            frame.height as usize,
            spec.max_dim as usize,
        );
        (d, dw as u32, dh as u32)
    } else {
        (frame.rgba, frame.width, frame.height)
    };

    let jpeg = export::encode_jpeg(&rgba, out_w, out_h, spec.quality, &exif)?;
    // Encode is the last stage; report a finished export as 1000 permille.
    if let Some(p) = progress {
        p.store(1000, Ordering::Relaxed);
    }
    Ok(ExportResult {
        cancelled: false,
        jpeg,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::color::ColorParams;
    use crate::decode;

    fn solid(width: u32, height: u32, r: u8, g: u8, b: u8) -> Vec<u8> {
        let mut v = Vec::with_capacity(width as usize * height as usize * 4);
        for _ in 0..width * height {
            v.extend_from_slice(&[r, g, b, 255]);
        }
        v
    }

    fn spec() -> ExportSpec {
        ExportSpec {
            flip_h: false,
            flip_v: false,
            turns: 0,
            angle: 0.0,
            crop_l: 0.0,
            crop_t: 0.0,
            crop_r: 1.0,
            crop_b: 1.0,
            perspective_x: 0.0,
            perspective_y: 0.0,
            skew_x: 0.0,
            skew_y: 0.0,
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
            remove_chromatic_aberration: false,
            defringe_purple_amount: 0.0,
            defringe_purple_hue_min: 0.70,
            defringe_purple_hue_max: 0.95,
            defringe_green_amount: 0.0,
            defringe_green_hue_min: 0.17,
            defringe_green_hue_max: 0.50,
            quality: 90,
            max_dim: 0,
            band_rows: 16,
            cancel_token: 0,
        }
    }

    fn neutral_curves() -> CurveParams {
        CurveParams {
            master: vec![],
            red: vec![],
            green: vec![],
            blue: vec![],
        }
    }

    #[test]
    fn export_full_produces_a_decodable_jpeg() {
        let src = solid(32, 24, 200, 100, 50);
        let out = export_full(
            src,
            32,
            24,
            spec(),
            Vec::new(),
            ColorParams::default(),
            neutral_curves(),
            vec![0.0; 24],
            Vec::new(),
        )
        .unwrap();
        assert!(!out.cancelled);
        assert_eq!(decode::dimensions(&out.jpeg).unwrap(), (32, 24));
    }

    #[test]
    fn export_full_honours_max_dim() {
        let src = solid(64, 48, 10, 20, 30);
        let mut s = spec();
        s.max_dim = 16;
        let out = export_full(
            src,
            64,
            48,
            s,
            Vec::new(),
            ColorParams::default(),
            neutral_curves(),
            vec![0.0; 24],
            Vec::new(),
        )
        .unwrap();
        let (w, h) = decode::dimensions(&out.jpeg).unwrap();
        assert_eq!(w.max(h), 16, "longest side capped: {w}x{h}");
    }

    #[test]
    fn a_pre_set_token_cancels_the_export() {
        let token = export_cancel_new();
        export_cancel_set(token);
        let src = solid(32, 32, 100, 100, 100);
        let mut s = spec();
        s.cancel_token = token;
        let out = export_full(
            src,
            32,
            32,
            s,
            Vec::new(),
            ColorParams::default(),
            neutral_curves(),
            vec![0.0; 24],
            Vec::new(),
        )
        .unwrap();
        assert!(out.cancelled, "a set token must abort the export");
        assert!(out.jpeg.is_empty());
        export_cancel_drop(token);
    }

    #[test]
    fn a_zero_token_never_cancels() {
        assert!(cancel_flag(0).is_none());
        let token = export_cancel_new();
        assert!(cancel_flag(token).is_some());
        export_cancel_drop(token);
        assert!(
            cancel_flag(token).is_none(),
            "dropped token resolves to None"
        );
    }

    #[test]
    fn progress_starts_at_zero_and_reaches_full_after_export() {
        let token = export_cancel_new();
        assert_eq!(export_progress_get(token), 0);
        let mut s = spec();
        s.cancel_token = token;
        // Tall enough for several bands (band_rows 16 over 128 rows).
        let out = export_full(
            solid(32, 128, 200, 100, 50),
            32,
            128,
            s,
            Vec::new(),
            ColorParams::default(),
            neutral_curves(),
            vec![0.0; 24],
            Vec::new(),
        )
        .unwrap();
        assert!(!out.cancelled);
        assert_eq!(
            export_progress_get(token),
            1000,
            "a finished export reports 1000 permille"
        );
        export_cancel_drop(token);
    }

    #[test]
    fn progress_is_zero_for_unknown_or_dropped_tokens() {
        assert_eq!(export_progress_get(0), 0);
        let token = export_cancel_new();
        export_cancel_drop(token);
        assert_eq!(
            export_progress_get(token),
            0,
            "a dropped token resolves to no progress"
        );
    }

    #[test]
    fn mismatched_buffer_is_an_error() {
        let err = export_full(
            solid(4, 4, 0, 0, 0)[..8].to_vec(),
            4,
            4,
            spec(),
            Vec::new(),
            ColorParams::default(),
            neutral_curves(),
            vec![0.0; 24],
            Vec::new(),
        )
        .unwrap_err();
        assert!(err.contains("expected"), "got: {err}");
    }
}
