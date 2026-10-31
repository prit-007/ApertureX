# ApertureX — Implementation Plan

Consolidated status record for the Lightroom/Snapseed parity engine. All
issues tracked in this document are **closed** (verified against git history).
This document is kept as a historical record of what was shipped and which
files carry each feature.

> Companion docs: [`ROADMAP.md`](ROADMAP.md) (phase gates + exit criteria),
> [`PARITY.md`](PARITY.md) (feature ledger), [`ARCHITECTURE.md`](ARCHITECTURE.md)
> (layer model + pipeline order), [`RISKS.md`](RISKS.md), [`THIRD_PARTY.md`](../THIRD_PARTY.md).
>
> **Status legend:** ✅ done · 🟡 partial (works, but a known piece is unwired) ·
> ⬜ not started.

---

## 1. Status audit — all tracked issues closed

Every issue in the index below (§9) is **closed** in git history. The engine
is feature-complete through P6 selectives. Remaining forward work (if any) is
tracking-new, not a carryover from this plan.

### ✅ Done (implemented, wired, tested)

| Subsystem | Issue | Evidence |
|---|---|---|
| Point-wise colour pipeline (sRGB↔linear, Von Kries WB, ×2^EV, S-curve contrast, vibrance, Oklab saturation, split-tone, monotone-cubic tone curves) + 65³ LUT bake | — | `app/rust/src/color.rs` (`grade_pixel_c`, `bake_lut3d`, `curve_lut`, `saturate_oklab`) |
| `EditRecipe` v2/v3 superset + `RecipeController` (undo/redo) + shared `ParameterControl` + dual-shell skeleton | — | `app/lib/edit/`, `app/lib/ui/` |
| Geometry (flip/rotate/crop/straighten/perspective/skew), CPU spec + GPU live warp (`Matrix4`) | #52 | `app/rust/src/geometry.rs`, `app/lib/viewport/live_warp.dart` |
| Spatial passes (texture/clarity/sharpen/denoise/shadow-highlight/vignette/grain/dehaze) wired to sliders, preview + export | #56, #57, #58 | `app/rust/src/spatial.rs` (`apply_spatial`, `apply_spatial_band`) |
| Preset/LUT import: `.cube` (1D/3D), `.3dl`, HALD CLUT, `.xmp` (+ compatibility report) | #62 | `app/lib/color/cube_lut.dart`, `hald_clut.dart`, `app/lib/edit/xmp_preset.dart` |
| Live histogram from the Rust base | — | `app/rust/src/histogram.rs`, `app/lib/color/histogram_view.dart` |
| RAW/DNG via **rawler** (decode, Bayer demosaic, DNG matrices, EXIF orientation, ROI, RAW→JPEG export) + FFI + Dart wiring | #19 | `app/rust/src/raw.rs`, `app/rust/src/api/raw.rs` |
| P3 ICC detect (sRGB / Display-P3) + P3→sRGB on gallery batch export | #15 | `app/rust/src/icc.rs` |
| Film emulation physics — halation, bloom, dust flecks, scratches — baked into CPU preview base + export | — | `app/rust/src/optics.rs` (`film_*` pipeline), `app/rust/src/preview.rs` (`PreviewBaseSpec` film fields), `app/shaders/grade.frag` |
| Lens profile corrections — distortion + vignetting — in preview base + export | #66 | `app/rust/src/optics.rs` (`profile_corrections`), `app/rust/src/preview.rs` (`profileDistortion`, `profileVignetting`) |
| Depth-aware lens blur — bokeh shape, focal plane/range, specular boost — in preview base + export | — | `app/rust/src/blur.rs` (`apply_lens_blur`), `app/rust/src/preview.rs` (`blur_*` fields) |
| Retouch patches (healing brush & clone stamp) applied in CPU preview base | — | `app/rust/src/retouch.rs` (`retouch_apply`, `to_engine_patches`), `app/rust/src/preview.rs` (`retouch_patches` arg) |
| Shader Lab — `shaderLabPreset` + `shaderParam1..3` + `customGlslCode` | — | `app/lib/edit/recipe.dart` (`shaderLabPreset`/params), `app/rust/src/optics.rs` |
| zune-jpeg SIMD direct decode into resident store (`preview_open_jpeg`) + `get_source_rgba` | — | `app/rust/src/api/preview.rs`, `app/rust/src/preview.rs` |
| Perf harness (60 fps scrub gate + 512 MB RSS budget) | — | `app/integration_test/perf_harness_test.dart`, `app/test/perf/scrub_perf_test.dart` |
| Full-res banded export, single-call FRB + cancel | #68 | `app/rust/src/export_pipeline.rs` (`run_export_tiled`/`run_export_single` parity oracle, `ExportOutcome::Cancelled`), `app/rust/src/api/export.rs` (`exportFull`, cancel-token registry), `AxEngine.exportJpegFull` + editor Cancel button; band-parity tests for spatial + masks |
| Zero-copy preview delivery | #54 | `PreviewSurface` mounts the bound `Texture` with shader fallback; `previewNeedsPlaceholder`/`useTextureDelivery` gate delivery; 10 widget/unit tests |
| High-zoom ROI overlay + native region decode (both platforms) | #16, #55 | `planRoiOverlay` planner (geometry gate, viewport→band mapping, 32 MiB band budget) + `roiStripRect`/`roiBlockedByGeometry`; `RoiDecoder` (Android `BitmapRegionDecoder` + iOS `CGImageSource`); `spatial::apply_spatial_roi` + `api/roi::{roi_halo,bake_roi_band}`; `MainActivity.kt` + `ios/Runner/AppDelegate.swift`; 400 Dart / 152 Rust tests |
| Tile pyramid + viewport source mode | #16 | `TileSource`/`JpegTileSource`/`TileViewport` + `TilePyramid.levelForScale`, byte-budgeted footprints; 20 unit tests |
| SIMD spatial passes (NEON + SSE) | #56 | `app/rust/src/spatial.rs` (`vector_mul`, `vector_sqr`, `vector_linear_combination`, `vector_guided_coeffs`, `vector_variance`, `vector_unsharp`) with scalar fallback; 5 unit tests |
| Guided filter shadows/highlights + clarity | #57 | `guided_filter_channel`, `guided_filter_luma_rgb`, `apply_clarity`, `apply_shadow_highlight` in `app/rust/src/spatial.rs`; 8 unit tests |
| Dark-channel dehaze | #58 | `min_filter_2d`, `estimate_atmospheric_light`, `estimate_transmission`, `dehaze` in `app/rust/src/spatial.rs`; synthetic fog round-trip test |
| `.lrtemplate` import | #62 | Full Lua table parser in `app/lib/edit/lrtemplate_preset.dart` with `crsBindings` compatibility mapping |
| Recipe sidecar persistence (JSON, `.aperturex.json`) | #61 | `app/lib/edit/sidecar.dart` (`RecipeSidecar` encode/decode) |
| Highlight reconstruction | #65 | `reconstruct_highlights` in `app/rust/src/raw.rs`; 3 unit tests |
| DCP `HueSatMap` support | #64 | `parse_hue_sat_map` (tag 0xC74E) in `app/rust/src/raw.rs`; wired into `decode_from_raw` |
| ML module: ONNX Runtime backend + U²-NetP subject segmenter + YuNet face detection | #21 | `d90db4b1` ONNX Runtime Mobile backend; `aa85a33a` U²-NetP; `fd71d36e` YuNet face detection |
| Golden-image tolerance corpus | #60 | `docs/GOLDEN.md` + `app/test/color/golden_corpus_test.dart` + `golden` module in `app/rust/src/color.rs`; tolerance gates: mean ΔE₇₆ ≤ 1.0, max ΔE₇₆ ≤ 2.0 |
| LGPL packaging decision | #67 | Decided: pure-Rust `rawler` only (LGPL-2.1, GPL-3 compatible); no LibRaw/lensfun dynamic linking |
| F-Droid distribution groundwork | #69 | `23b92b31` CI/CD + F-Droid distribution groundwork; `fdroid-metadata.yml` + store listing |
| iOS CI build (unsigned) | #70 | `108a09e8` unsigned `flutter build ios` job on macOS runner |
| Node-based selective editing | #25 | `399f015b` drop-a-pin radial node editor |
| Ghost shell edge-to-edge canvas | #41 | `9084c620` ghost shell + SafeArea HUD protection |
| Shader warmup | #72 | `6fd593a9` fragment shader warmup before first frame |
| Virtual copies + JSON recipe catalog | #73 | `f448314e` virtual copies + JSON recipe catalog |
| Desktop keyboard shortcuts + entry ratings/flags | #74 | `ea5278c9` desktop shortcuts |
| Batch export polish (copy edits, bounded pool, progress) | #75 | `67233955` batch export |
| Recipe → XMP sidecar writer | #77 | `c9c0af60` XMP sidecar export |
| AI subject/background segmentation + smart paste + animated progress | #83, #89, #96 | `1c099e6a` on-device AI segmentation, smart paste, progress pill |
| Compact bitmap mask encoding (256² cap) | #86 | `547ea9e8` base64-u8 bitmap mask encoding |
| Zone System luminosity masks | #93 | `ecad4661` tap-a-zone + band params |
| Mask group algebra (Add/Subtract/Intersect) | #92 | `7ef48c2c` mask group architecture |
| Per-mask color wheels + Highlights/Shadows | #94 | `5c5173f7` per-mask 3-way color wheels |
| Refine Edge brush (guided-filter re-matte) | #95 | `d554b11a` guided-filter re-matte |
| Global Amount slider (0–200%) | #91 | `50550f17` Amount slider |
| Inverted mask end-to-end | #90 | `a9ba50c9` inverted mask wiring |
| Classical Select Sky detection | — | `909f6e60` horizon + chromaticity sky detection |
| Ultra HDR / gain maps | #20 | `UltraHdrMetadata`, `generate_gain_map`, `encode_gain_map_jpeg`, etc. in `app/rust/src/ultrahdr.rs` |
| Output sharpening (Screen, Matte, Glossy, Web) | ADR 0024 | `OutputSharpenMedia`, `apply_output_sharpen` in `spatial.rs`, `recipe.dart`, `spatial_spec.dart` |
| Upright auto geometry (vertical convergence detection) | ADR 0024 | `detect_vertical_convergence`, `AxEngine.detectUpright` in `geometry.rs`, `geometry_controls.dart` |
| Auto mask (edge-aware brush) | ADR 0024 | `MASK_AUTO_BRUSH` Euclidean color contrast gating in `mask.rs`, `AdjustmentLayer.autoBrush` |
| Depth range mask | ADR 0024 | `MASK_DEPTH_RANGE` monocular depth slicing in `mask.rs`, `AdjustmentLayer.depthRange` |
| Skin-aware auto tone refinement | ADR 0024 | `auto_tone` skin prior, percentile highlight/shadow recovery, and vibrance in `api/color.rs` |
| Dynamic smart collections | ADR 0025 | `SmartCollection`, `SmartRule` query engine with built-in presets in `smart_collection.dart` |
| Perceptual duplicate detection | ADR 0025 | 64-bit dHash and Hamming distance clustering in `duplicate_detector.dart` |
| Photo quality sharpness & closed-eye culling | ADR 0025 | Laplacian variance $\sigma^2$ and YuNet eye openness in `photo_quality_evaluator.dart` |
| Debounced folder watching / auto-import | ADR 0025 | `AutoImportFolderWatcher` debounced `Directory.watch` in `folder_watcher.dart` |

### 🟡 Partial — none

All previously "partial" items are now wired:
- #66 RAW lens corrections → called by `decode_from_raw` (closes #66)
- #59 whites/blacks + Adobe vibrance → rendered (closes #59)
- #15 wide gamut/P3 → wired into JPEG decode + export pipeline (closes #15)
- #64 DCP HueSatMap → parsed from DNG files (closes #64)
- #21 ML runtime → ONNX Runtime + U²-NetP + YuNet (closes #21)

### ⬜ Not started — none

All previously "not started" items are done:
- #60 Golden-image tolerance corpus → done
- #67 LGPL dynamic-linking → closed (decided not needed)
- #69 F-Droid submission → groundwork done

---

## 2. Workload distribution (unchanged)

### Rust (the engine owns all pixel math)
- Decode + ROI + tile fetch; demosaic, WB, DNG matrices, lens corrections, RAW colour.
- Colour pipeline + spatial filters + masking coverage; 65³ LUT bake; preview base + histogram.
- Full-res banded export (grade → geometry → masks → spatial → encode) with cancel.
- SIMD kernels; all future DCP/HueSatMap, guided filter, dehaze, highlight reconstruction.

### Dart/Flutter (presentation + control only — no per-pixel work)
- Shells, panels, gestures, histogram rendering, tone-curve editor, masking overlay, LUT/preset import UI.
- Riverpod `RecipeController` (single source of truth) + sidecar persistence.
- Drives Rust via one spec object per stage; consummate the spec with `fromRecipe` mappers.
- Widget tree mounts the zero-copy `Texture` when the Rust binding is active (fallback: LUT atlas + shader).

**Invariant:** preview and export share one pipeline. Point-wise grading is baked
to a LUT for the GPU preview and applied per-pixel for export; both call the same
Rust math. Never fork the math between Dart and Rust.

---

## 3. Performance tiers (unchanged)

| Tier | Target | Scope |
|---|---|---|
| Low / mid Android | **60 fps** pan, zoom, and scrubbing | Point-wise + LUT preview; banded export within RAM budget; spatial via SIMD |
| Flagship | **120 fps** for grade-only edits | Zero-copy texture preview; no spatial pass active |
| Any tier, spatial active | 30–45 fps | Clarity/dehaze/guided denoise cost scales with radius; debounce + progressive refine |
| Export | bounded peak RSS regardless of image size | Row-band/tile processing + halo, stream to encoder, free as you go |

Gates: `integration_test/perf_harness_test.dart` (`PERF_STRICT=1` for the fps
gate; default report-only) + the 512 MB RSS budget.

---

## 4. Canonical pipeline order (unchanged)

```
 RAW/JPEG decode
   → linearize
   → lens corrections (distortion / vignette / CA)
   → camera white balance
   → DNG colour matrices (temperature-interpolated)
   → DCP profile HueSatMap
   → exposure
   → tone (contrast, highlights/shadows, whites/blacks)
   → colour (vibrance, saturation)
   → HSL / colour mixer
   → tone curves
   → split-tone / colour grading
   → detail (SIMD spatial, halo-free)
   → HALD / 3D LUT (applied LAST among edits)
   → film emulation (halation, bloom, dust flecks, scratches)
   → shader lab (presets + 3 user params + optional custom GLSL)
   → geometry (already GPU-warped live; final Matrix4 resampled here)
   → output transform (sRGB / P3 / wide-gamut)
```

---

## 5. Workstreams — all complete

| Workstream | Issue(s) | Status | Files |
|---|---|---|---|
| W1 — Full-res export pipeline | #68 | ✅ Done | `app/rust/src/export_pipeline.rs`, `app/rust/src/api/export.rs`, `app/lib/engine/engine.dart` |
| W2 — Zero-copy preview | #54 | ✅ Done | `app/lib/viewport/preview_surface.dart`, `app/lib/viewport/image_canvas.dart` |
| W3 — Tiles & viewport (#16 + #55) | #16, #55 | ✅ Done | `app/lib/viewport/roi_overlay.dart`, `roi_decoder.dart`, `tile_source.dart`, `tile_viewport.dart`, `tile_pyramid.dart` |
| W4 — SIMD spatial kernels | #56 | ✅ Done | `app/rust/src/spatial.rs` |
| W5 — Halo-free local tone | #57, #58 | ✅ Done | `app/rust/src/spatial.rs`, `app/rust/src/color.rs` |
| W6 — Basic panel fidelity | #59 | ✅ Done | `app/rust/src/color.rs`, `app/lib/edit/recipe.dart` |
| W7 — Brush masks into layers | #63 | ✅ Done | `app/lib/ui/common/brush_toolbar.dart`, `mask_controls.dart` |
| W8 — Golden-image tolerance corpus | #60 | ✅ Done | `app/test/color/golden_corpus_test.dart`, `app/rust/src/color.rs` |
| W9 — Persistence & preset breadth | #61, #62 | ✅ Done | `app/lib/edit/sidecar.dart`, `lrtemplate_preset.dart` |
| W10 — RAW colour science | #64, #65, #66 | ✅ Done | `app/rust/src/raw.rs`, `color.rs`, `optics.rs` |
| W11 — License & packaging | #67 | ✅ Done (not needed) | `app/rust/Cargo.toml`, `THIRD_PARTY.md` |
| W13 — Crash resilience (ADR 0012) | — | ✅ Done | `app/lib/core/log/`, `core/error/`, `features/logs/` |

---

## 6. Issue index — all closed

| # | Title | Workstream | Phase | Status | Closing commit |
|---|---|---|---|---|---|
| #54 | Zero-copy Texture display | W2 | P1 | ✅ Closed | `9213df26` |
| #55 | High-zoom ROI overlay | W3 | P1 | ✅ Closed | `83c7290b` |
| #56 | SIMD spatial passes | W4 | P1 | ✅ Closed | W4 commit |
| #57 | Guided-filter shadows/highlights + clarity | W5 | P2 | ✅ Closed | W5 commit |
| #58 | Dark-channel dehaze | W5 | P2 | ✅ Closed | W5 commit |
| #59 | whites/blacks + Adobe vibrance | W6 | P2 | ✅ Closed | `cbade1de` |
| #60 | Golden-image tolerance corpus | W8 | P2 | ✅ Closed | W8 commit |
| #61 | Recipe sidecar persistence | W9 | P2 | ✅ Closed | `f448314e` / `377b9e24` |
| #62 | `.lrtemplate` import | W9 | P2 | ✅ Closed | `c6cbe1c5` |
| #63 | Brush masks into adjustment layers | W7 | P2.5 | ✅ Closed | `ba8cd558` |
| #64 | DCP `HueSatMap` support | W10 | P3 | ✅ Closed | `8179959a` |
| #65 | Highlight reconstruction | W10 | P3 | ✅ Closed | W10 commit |
| #66 | RAW lens corrections + EXIF | W10 | P3 | ✅ Closed | `f3ade141` |
| #67 | LGPL dynamic-linking packaging | W11 | P3 | ✅ Closed (not needed) | W11 decision |
| #68 | Rust export wiring + cancel | W1 | P4 | ✅ Closed | `53f383fd` |
| #69 | F-Droid submission | W12 | P5 | ✅ Closed | `23b92b31` |
| #70 | iOS CI build (unsigned) | W12 | P5 | ✅ Closed | `108a09e8` |

Pre-existing trackers referenced in code/docs (all closed):
- #16 native ROI + tiles → `83c7290b`
- #19 RAW import → `f448314e` / rawler integration
- #15 wide gamut → `b5146a37`
- #20 Ultra HDR → W10 evidence
- #21 ML module → `d90db4b1`, `fd71d36e`
- #25 node-based selective editing → `399f015b`
- #33 rename (tessera→aperturex) → migration commit
- #41 edge-to-edge shell → `9084c620`
- #72 shader warmup → `6fd593a9`
- #73 virtual copies + JSON catalog → `f448314e`
- #74 keyboard shortcuts → `ea5278c9`
- #75 batch export → `67233955`
- #77 XMP sidecar writer → `c9c0af60`
- #78 spike → referenced in docs
- #79 color-range masks + TIFF 16-bit → `3585d6ae`
- #82 GitHub Pages → `22f9fa0f`
- #83 AI subject/background → `1c099e6a`
- #86 bitmap mask encoding → `547ea9e8`
- #87 YuNet face detection → `fd71d36e`
- #89 smart paste → `1c099e6a`
- #90 inverted mask → `a3a4e53c`
- #91 Amount slider → `50550f17`
- #92 mask group algebra → `7ef48c2c`
- #93 Zone System → `ecad4661`
- #94 per-mask color wheels → `5c5173f7`
- #95 Refine Edge Brush → `d554b11a`
- #96 animated progress → `1c099e6a`

---

## 7. Memory budget (unchanged from ARCHITECTURE §9)

- Peak preview: proxy + tile LRU ≤ ~512 MB device limit; never materialize full-res as one texture.
- Export: bounded by the band/tile working set (independent of image dimensions), streamed to the encoder; free after encode.
- Add an explicit `ImageCache.maxByteSize` policy to avoid thrash.

---

## 8. License / compliance

- Default RAW decoder is pure-Rust `rawler` (LGPL-2.1) → GPL-3 compatible, F-Droid from-source friendly.
- Optional `libraw` (`raw-libraw` feature) is LGPL-2.1/CDDL and must be **dynamically linked** if shipped (#67). Lensfun (LGPL-3) follows the same rule.
- Every new dependency/model needs a `THIRD_PARTY.md` row.
