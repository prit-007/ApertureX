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
use crate::api::retouch::{to_engine_patches, ApiRetouchPatch};
use crate::export;
use crate::export_pipeline::{self, ExportOutcome, ExportRecipe};
use crate::geometry::{self, GeometrySpec};
use crate::mask::{self, LocalAdjustment};
use crate::optics::OpticsParams;
use crate::spatial::SpatialParams;
use crate::watermark::{MuseumFrameTheme, WatermarkAnchor, WatermarkSpec};

/// Encodes an RGBA8 buffer as a JPEG (alpha dropped). [exif] (a full APP1
/// segment from the source, or empty) is injected to preserve metadata.
pub fn encode_jpeg_rgba(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    quality: u8,
    exif: Vec<u8>,
) -> Result<Vec<u8>, String> {
    crate::validate::validate_rgba(&rgba, width, height)?;
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
    // optics
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
    // depth-aware lens blur (applies after optics, before spatial — the same
    // stage position as the preview bake, so preview == export)
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
    /// When true, applies background-only blur (subject stays sharp).
    pub blur_background_blur: bool,
    // encode
    pub quality: u8,
    /// Longest-side cap for the export (0 = full resolution).
    pub max_dim: u32,
    /// Band height for the banded stages (0 = a 256-row default).
    pub band_rows: u32,
    /// Opaque cancel token from [`export_cancel_new`] (0 = no cancellation).
    pub cancel_token: u64,
    /// Target color space: 0 = sRGB, 1 = Display-P3 (wide color gamut).
    pub color_space: u32,
    /// Ultra HDR (ISO 21496-1) gain map generation and packaging.
    pub ultra_hdr: bool,
    /// HDR headroom in EV stops (e.g. 2.0 = 400% brightness boost).
    pub hdr_headroom: f32,
}

impl ExportSpec {
    /// Maps the flat blur fields onto the engine's [`crate::blur::LensBlurParams`].
    pub fn blur_params(&self) -> crate::blur::LensBlurParams {
        crate::blur::LensBlurParams::from_fields(
            self.blur_enabled,
            self.blur_amount,
            self.blur_focal_point,
            self.blur_focal_range,
            self.blur_bokeh_shape,
            self.blur_bokeh_boost,
            self.blur_background_blur,
        )
    }

    /// Maps the flat optics fields onto the engine's [`OpticsParams`], with the
    /// profile scales forwarded verbatim (1.0 = authored-profile neutral).
    pub(crate) fn optics_params(&self) -> OpticsParams {
        OpticsParams {
            remove_chromatic_aberration: self.remove_chromatic_aberration,
            defringe_purple_amount: self.defringe_purple_amount,
            defringe_purple_hue_min: self.defringe_purple_hue_min,
            defringe_purple_hue_max: self.defringe_purple_hue_max,
            defringe_green_amount: self.defringe_green_amount,
            defringe_green_hue_min: self.defringe_green_hue_min,
            defringe_green_hue_max: self.defringe_green_hue_max,
            profile_corrections: self.profile_corrections,
            profile_distortion: self.profile_distortion,
            profile_vignetting: self.profile_vignetting,
        }
    }
}

/// The result of [`export_full`]: JPEG bytes, or a flag when the export was
/// cancelled before it finished encoding.
#[derive(Debug)]
pub struct ExportResult {
    /// True when a cancel token fired — [jpeg] is then empty.
    pub cancelled: bool,
    pub jpeg: Vec<u8>,
}

/// Specifications for watermark, signature, museum frame, and FOSS badge.
#[derive(Debug, Clone, Default)]
pub struct ExportBrandingSpec {
    pub enable_museum_frame: bool,
    /// 0 = StudioWhite, 1 = MatteDark, 2 = WarmGallery
    pub frame_theme: u8,
    pub exif_line1: String,
    pub exif_line2: String,
    pub enable_signature: bool,
    pub signature_text: String,
    /// 0..8 corresponding to 9-point grid
    pub signature_anchor: u8,
    pub signature_opacity: f32,
    pub signature_size_pct: f32,
    pub enable_logo: bool,
    pub logo_bytes: Vec<u8>,
    pub logo_anchor: u8,
    pub logo_opacity: f32,
    pub logo_scale_pct: f32,
    pub enable_foss_badge: bool,
}

impl ExportBrandingSpec {
    pub fn to_core(&self) -> WatermarkSpec {
        let theme = match self.frame_theme {
            1 => MuseumFrameTheme::MatteDark,
            2 => MuseumFrameTheme::WarmGallery,
            _ => MuseumFrameTheme::StudioWhite,
        };
        let anchor_from_u8 = |val: u8| match val {
            0 => WatermarkAnchor::TopLeft,
            1 => WatermarkAnchor::TopCenter,
            2 => WatermarkAnchor::TopRight,
            3 => WatermarkAnchor::CenterLeft,
            4 => WatermarkAnchor::Center,
            5 => WatermarkAnchor::CenterRight,
            6 => WatermarkAnchor::BottomLeft,
            7 => WatermarkAnchor::BottomCenter,
            _ => WatermarkAnchor::BottomRight,
        };
        WatermarkSpec {
            enable_museum_frame: self.enable_museum_frame,
            frame_theme: theme,
            exif_line1: self.exif_line1.clone(),
            exif_line2: self.exif_line2.clone(),
            enable_signature: self.enable_signature,
            signature_text: self.signature_text.clone(),
            signature_anchor: anchor_from_u8(self.signature_anchor),
            signature_opacity: self.signature_opacity,
            signature_size_pct: self.signature_size_pct,
            enable_logo: self.enable_logo,
            logo_bytes: self.logo_bytes.clone(),
            logo_anchor: anchor_from_u8(self.logo_anchor),
            logo_opacity: self.logo_opacity,
            logo_scale_pct: self.logo_scale_pct,
            enable_foss_badge: self.enable_foss_badge,
        }
    }
}

/// Specifications for C2PA cryptographic provenance signing.
#[derive(Debug, Clone, Default)]
pub struct C2paExportSpec {
    pub enable_c2pa: bool,
    pub device_private_key: Vec<u8>,
    pub recipe_json: String,
    pub exif_summary: String,
}

/// Branded RGBA frame result for live mini-preview rendering.
#[derive(Debug)]
pub struct BrandedFrame {
    pub rgba: Vec<u8>,
    pub width: u32,
    pub height: u32,
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
/// Renders a live mini-preview of the branding (museum frame, signature, logo, badge)
/// on an RGBA buffer.
pub fn render_branding_preview(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    branding: ExportBrandingSpec,
) -> Result<BrandedFrame, String> {
    let core_spec = branding.to_core();
    let (out_rgba, out_w, out_h) =
        crate::watermark::process_branding_pipeline(&rgba, width, height, &core_spec);
    Ok(BrandedFrame {
        rgba: out_rgba,
        width: out_w,
        height: out_h,
    })
}

/// Runs the complete export recipe in Rust, applies optional branding (Museum Frame,
/// Photographer Signature, FOSS Badge), encodes JPEG, and embeds C2PA Content Credentials.
#[allow(clippy::too_many_arguments)]
pub fn export_full_with_branding(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    spec: ExportSpec,
    layers: Vec<MaskLayer>,
    retouch_patches: Vec<ApiRetouchPatch>,
    params: ColorParams,
    curves: CurveParams,
    hsl: Vec<f32>,
    exif: Vec<u8>,
    branding: ExportBrandingSpec,
    c2pa: C2paExportSpec,
) -> Result<ExportResult, String> {
    crate::validate::validate_rgba(&rgba, width, height)?;
    let (w, h) = (width as usize, height as usize);

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
        optics: spec.optics_params(),
        retouch: to_engine_patches(&retouch_patches),
        blur: spec.blur_params(),
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

    // Process custom branding & watermarking (Museum Frame, Signature, FOSS Badge)
    let core_branding = branding.to_core();
    let (mut branded_rgba, final_w, final_h) =
        crate::watermark::process_branding_pipeline(&rgba, out_w, out_h, &core_branding);

    let is_p3 = spec.color_space == 1;
    if is_p3 {
        branded_rgba = crate::icc::srgb_to_p3(&branded_rgba, final_w as usize, final_h as usize);
    }

    let mut jpeg = if spec.ultra_hdr {
        let meta = crate::ultrahdr::UltraHdrMetadata {
            gain_map_max: if spec.hdr_headroom > 0.0 {
                spec.hdr_headroom
            } else {
                2.0
            },
            ..Default::default()
        };
        crate::ultrahdr::encode_ultra_hdr_jpeg(
            &branded_rgba,
            final_w as usize,
            final_h as usize,
            spec.quality,
            85,
            &exif,
            &meta,
            None,
        )?
    } else {
        export::encode_jpeg(&branded_rgba, final_w, final_h, spec.quality, &exif)?
    };

    if is_p3 {
        let p3_seg = crate::icc::make_p3_app2_segment();
        jpeg = crate::exif::inject_app1(jpeg, &p3_seg);
    }

    // If C2PA is requested, sign claims and inject JUMBF APP11
    if c2pa.enable_c2pa && !c2pa.device_private_key.is_empty() {
        let pixel_hash_hex = crate::sha256::sha256_hex(&branded_rgba);
        let recipe_hash = crate::sha256::sha256_hex(c2pa.recipe_json.as_bytes());
        let (priv_key, key_id) = crate::c2pa::generate_device_key(&c2pa.device_private_key);
        let pk_hex = crate::c2pa::public_key_hex_from_seed(&priv_key);

        let actions = ["c2pa.opened", "c2pa.color_adjustments"];
        let claim = crate::c2pa::build_c2pa_claim(
            &pixel_hash_hex,
            None,
            &actions,
            &c2pa.exif_summary,
            &recipe_hash,
            &key_id,
            &pk_hex,
        );
        let sig_hex = crate::c2pa::sign_c2pa_claim(&claim, &priv_key);
        let manifest = crate::c2pa::create_c2pa_manifest(&claim, &sig_hex, &key_id, &pk_hex);
        jpeg = crate::c2pa::inject_c2pa_app11(jpeg, &manifest);
    }

    // Encode is the last stage; report a finished export as 1000 permille.
    if let Some(p) = progress {
        p.store(1000, Ordering::Relaxed);
    }
    Ok(ExportResult {
        cancelled: false,
        jpeg,
    })
}

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
    retouch_patches: Vec<ApiRetouchPatch>,
    params: ColorParams,
    curves: CurveParams,
    hsl: Vec<f32>,
    exif: Vec<u8>,
) -> Result<ExportResult, String> {
    export_full_with_branding(
        rgba,
        width,
        height,
        spec,
        layers,
        retouch_patches,
        params,
        curves,
        hsl,
        exif,
        ExportBrandingSpec::default(),
        C2paExportSpec::default(),
    )
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
            quality: 90,
            max_dim: 0,
            band_rows: 16,
            cancel_token: 0,
            color_space: 0,
            ultra_hdr: false,
            hdr_headroom: 2.0,
        }
    }

    /// The export bridge struct's blur fields must land in the engine
    /// params — the previous wiring hardcoded `LensBlurParams::default()`,
    /// so the blur slider never reached the exported JPEG.
    #[test]
    fn export_spec_blur_fields_map_to_engine_params() {
        let mut s = spec();
        assert!(s.blur_params().is_neutral(), "default blur must stay off");

        s.blur_enabled = true;
        s.blur_amount = 0.5;
        s.blur_focal_point = 0.3;
        s.blur_focal_range = 0.25;
        s.blur_bokeh_shape = 2; // hexagon
        s.blur_bokeh_boost = 0.4;
        let p = s.blur_params();
        assert_eq!(
            p,
            crate::blur::LensBlurParams {
                enabled: true,
                amount: 0.5,
                focal_point: 0.3,
                focal_range: 0.25,
                bokeh_shape: crate::blur::BokehShape::Hexagon,
                bokeh_boost: 0.4,
                background_blur: false,
            }
        );
    }

    /// The export bridge struct's profile fields must land in the engine
    /// params — the previous wiring hardcoded the gate off and neutral scales.
    #[test]
    fn export_spec_profile_fields_map_to_engine_params() {
        let mut s = spec();
        assert_eq!(
            s.optics_params(),
            OpticsParams::default(),
            "default profile must stay off"
        );

        s.profile_corrections = true;
        s.profile_distortion = 1.4;
        s.profile_vignetting = 0.6;
        assert_eq!(
            s.optics_params(),
            OpticsParams {
                profile_corrections: true,
                profile_distortion: 1.4,
                profile_vignetting: 0.6,
                ..Default::default()
            },
            "profile fields must forward verbatim (1.0 = authored-profile neutral)"
        );
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

    /// A clone patch must reach the exported pixels: the dark target region
    /// takes the bright source colour, the untouched baseline does not.
    #[test]
    fn retouch_patches_reach_the_exported_pixels() {
        let (w, h) = (48u32, 32u32);
        let mut src = solid(w, h, 40, 40, 40);
        for y in 10..=22 {
            for x in 6..=18 {
                let i = ((y * w + x) * 4) as usize;
                src[i] = 0;
                src[i + 1] = 200;
                src[i + 2] = 0;
            }
        }
        let patch = ApiRetouchPatch {
            target_x: 36.0 / (w - 1) as f32,
            target_y: 16.0 / (h - 1) as f32,
            source_x: 12.0 / (w - 1) as f32,
            source_y: 16.0 / (h - 1) as f32,
            radius: 6.0 / 32.0,
            feather: 0.0,
            opacity: 1.0,
            is_clone: true,
        };

        let run = |patches: Vec<ApiRetouchPatch>| {
            export_full(
                src.clone(),
                w,
                h,
                spec(),
                Vec::new(),
                patches,
                ColorParams::default(),
                neutral_curves(),
                vec![0.0; 24],
                Vec::new(),
            )
            .unwrap()
        };
        let patched = decode::decode_rgba(&run(vec![patch]).jpeg).unwrap();
        let baseline = decode::decode_rgba(&run(Vec::new()).jpeg).unwrap();

        fn mean_green(img: &decode::DecodedImage, cx: usize, cy: usize) -> f32 {
            let (mut sum, mut n) = (0u32, 0u32);
            for y in cy - 4..=cy + 4 {
                for x in cx - 4..=cx + 4 {
                    sum += img.rgba[(y * img.width + x) * 4 + 1] as u32;
                    n += 1;
                }
            }
            sum as f32 / n as f32
        }

        let patched_g = mean_green(&patched, 36, 16);
        let baseline_g = mean_green(&baseline, 36, 16);
        assert!(
            patched_g > 150.0,
            "the target region must carry the cloned source colour: {patched_g}"
        );
        assert!(
            baseline_g < 80.0,
            "without patches the target region stays dark: {baseline_g}"
        );
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
            Vec::new(),
            ColorParams::default(),
            neutral_curves(),
            vec![0.0; 24],
            Vec::new(),
        )
        .unwrap_err();
        assert!(err.contains("expected"), "got: {err}");
    }

    #[test]
    fn export_full_with_display_p3_embeds_icc_profile() {
        let mut s = spec();
        s.color_space = 1; // Display-P3
        let res = export_full(
            solid(8, 8, 200, 100, 50),
            8,
            8,
            s,
            Vec::new(),
            Vec::new(),
            ColorParams::default(),
            neutral_curves(),
            vec![0.0; 24],
            Vec::new(),
        )
        .unwrap();

        assert!(!res.cancelled);
        assert_eq!(
            crate::icc::detect_colorspace(&res.jpeg),
            crate::icc::CS_DISPLAY_P3
        );
    }

    #[test]
    fn export_full_with_ultra_hdr_embeds_gain_map_and_xmp() {
        let mut s = spec();
        s.ultra_hdr = true;
        s.hdr_headroom = 2.5;
        let res = export_full(
            solid(16, 16, 220, 180, 120),
            16,
            16,
            s,
            Vec::new(),
            Vec::new(),
            ColorParams::default(),
            neutral_curves(),
            vec![0.0; 24],
            Vec::new(),
        )
        .unwrap();

        assert!(!res.cancelled);
        let (gain_map, meta) = crate::ultrahdr::extract_gain_map(&res.jpeg)
            .expect("must contain secondary gain map and XMP metadata");
        assert!(!gain_map.is_empty());
        assert!((meta.gain_map_max - 2.5).abs() < 1e-4);
    }
}
