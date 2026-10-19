# ApertureX — Implementation Plan

Consolidated, evidence-based status and forward plan for the Lightroom/Snapseed
parity engine: tile-based rendering, ROI decoding, full-res export, colour
science, and the 60/120 fps pipeline. This is the **single index** that maps
remaining work to exact files and to the GitHub issues that carry it.

> Companion docs: [`ROADMAP.md`](ROADMAP.md) (phase gates + exit criteria),
> [`PARITY.md`](PARITY.md) (feature ledger), [`ARCHITECTURE.md`](ARCHITECTURE.md)
> (layer model + pipeline order), [`RISKS.md`](RISKS.md), [`THIRD_PARTY.md`](../THIRD_PARTY.md).
>
> **Status legend:** ✅ done · 🟡 partial (works, but a known piece is unwired) ·
> ⬜ not started.

---

## 1. Honest status audit

Verified against the tree with the P4 export wiring present (`export_pipeline.rs`
+ `api/export.rs` FFI + regenerated bindings; `spatial.rs`/`geometry.rs`/
`mask.rs`/`preview.rs`/`lib.rs` updated). Grouped by subsystem.

### ✅ Done (implemented, wired, tested)

| Subsystem | Evidence |
|---|---|
| Point-wise colour pipeline (sRGB↔linear, Von Kries WB, ×2^EV, S-curve contrast, vibrance, Oklab saturation, split-tone, monotone-cubic tone curves) + 65³ LUT bake | `app/rust/src/color.rs` (`grade_pixel_c`, `bake_lut3d`, `curve_lut`, `saturate_oklab`) |
| `EditRecipe` v2/v3 superset + `RecipeController` (undo/redo) + shared `ParameterControl` + dual-shell skeleton | `app/lib/edit/`, `app/lib/ui/` |
| Geometry (flip/rotate/crop/straighten/perspective/skew), CPU spec + GPU live warp (`Matrix4`) | `app/rust/src/geometry.rs`, `app/lib/viewport/live_warp.dart` |
| Spatial passes (texture/clarity/sharpen/denoise/shadow-highlight/vignette/grain/dehaze) wired to sliders, preview + export | `app/rust/src/spatial.rs` (`apply_spatial`, `apply_spatial_band`) |
| Preset/LUT import: `.cube` (1D/3D), `.3dl`, HALD CLUT, `.xmp` (+ compatibility report) | `app/lib/color/cube_lut.dart`, `hald_clut.dart`, `app/lib/edit/xmp_preset.dart` |
| Live histogram from the Rust base | `app/rust/src/histogram.rs`, `app/lib/color/histogram_view.dart` |
| RAW/DNG via **rawler** (decode, Bayer demosaic, DNG matrices, EXIF orientation, ROI, RAW→JPEG export) + FFI + Dart wiring | `app/rust/src/raw.rs`, `app/rust/src/api/raw.rs` |
| P3 ICC detect (sRGB / Display-P3) + P3→sRGB on gallery batch export | `app/rust/src/icc.rs` |
| Film emulation physics — halation, bloom, dust flecks, scratches — baked into CPU preview base + export | `app/rust/src/optics.rs` (`film_*` pipeline), `app/rust/src/preview.rs` (`PreviewBaseSpec` film fields), `app/shaders/grade.frag` |
| Lens profile corrections — distortion + vignetting — in preview base + export | `app/rust/src/optics.rs` (`profile_corrections`), `app/rust/src/preview.rs` (`profileDistortion`, `profileVignetting`) |
| Depth-aware lens blur — bokeh shape, focal plane/range, specular boost — in preview base + export | `app/rust/src/blur.rs` (`apply_lens_blur`), `app/rust/src/preview.rs` (`blur_*` fields) |
| Retouch patches (healing brush & clone stamp) applied in CPU preview base | `app/rust/src/retouch.rs` (`retouch_apply`, `to_engine_patches`), `app/rust/src/preview.rs` (`retouch_patches` arg) |
| Shader Lab — `shaderLabPreset` + `shaderParam1..3` + `customGlslCode` | `app/lib/edit/recipe.dart` (`shaderLabPreset`/params), `app/rust/src/optics.rs` |
| zune-jpeg SIMD direct decode into resident store (`preview_open_jpeg`) + `get_source_rgba` | `app/rust/src/api/preview.rs`, `app/rust/src/preview.rs` |
| Perf harness (60 fps scrub gate + 512 MB RSS budget) | `app/integration_test/perf_harness_test.dart`, `app/test/perf/scrub_perf_test.dart` |
| Full-res banded export, single-call FRB + cancel (#68 wiring) | `app/rust/src/export_pipeline.rs` (`run_export_tiled`/`run_export_single` parity oracle, `ExportOutcome::Cancelled`), `app/rust/src/api/export.rs` (`exportFull`, cancel-token registry), `AxEngine.exportJpegFull` + editor Cancel button; band-parity tests for spatial + masks |
| Zero-copy preview delivery, Android (#54) | `PreviewSurface` mounts the bound `Texture` with shader fallback; `previewNeedsPlaceholder`/`useTextureDelivery` gate delivery; 10 widget/unit tests |
| High-zoom ROI overlay + native region decode, Android (#55, #16 part) | `planRoiOverlay` planner (geometry gate, viewport→band mapping, 32 MiB band budget) + `roiStripRect`/`roiBlockedByGeometry`; `RoiDecoder` (native `aperturex/roi_decode` channel when full RGBA > 64 MiB, Rust `decodeJpegRoi` fallback); `spatial::apply_spatial_roi` + `api/roi::{roi_halo,bake_roi_band}` (halo context, geometry-identity guard, parity vs `preview_base`); `MainActivity.kt` `BitmapRegionDecoder`; canvas wiring (debounced `_runRoi`, token-guarded, shader-path strip). 400 Dart / 152 Rust tests |
| iOS `CGImageSource` ROI channel + tile pyramid wiring (#16 part) | `AppDelegate.swift` registers `aperturex/roi_decode` (lazy `CGImageSource` crop + flipped `CGBitmapContext` → top-origin RGBA, serial decode queue, `bad_args`/`decode_failed` contract matching Android); `RoiDecoder.decodeRect` (arbitrary rects, shared tier/fallback with `decodeBand`); `TileSource`/`JpegTileSource`/`footprintForTile`/`downsampleBox`/`coarseAncestors` + `TileViewport` source mode (zoom-matched level, byte-budget clamp, coarse-ancestor instant paint); `synthetic_jpeg` position-encoded pattern; `examples/gen_corpus.rs`; on-device harness `integration_test/tile_corpus_test.dart` (byte-exact seams vs oracle strips, RSS/latency report, `CORPUS_STRICT` gates). 20 new Dart + 3 new Rust tests |
| SIMD spatial passes (#56) | NEON (aarch64) + SSE (x86_64) intrinsics inline in `app/rust/src/spatial.rs` (`vector_mul`, `vector_sqr`, `vector_linear_combination`, `vector_guided_coeffs`, `vector_variance`, `vector_unsharp`) with scalar fallback; 5 unit tests in `spatial.rs` |
| Guided filter shadows/highlights + clarity (#57) | `guided_filter_channel`, `guided_filter_luma_rgb`, `apply_clarity`, `apply_shadow_highlight` in `app/rust/src/spatial.rs`; 8 unit tests |
| Dark-channel dehaze (#58) | `min_filter_2d`, `estimate_atmospheric_light`, `estimate_transmission`, `dehaze` in `app/rust/src/spatial.rs`; synthetic fog round-trip test |
| .lrtemplate import (#62) | Full Lua table parser in `app/lib/edit/lrtemplate_preset.dart` with `crsBindings` compatibility mapping, `PresetImport` with applied/approximated/unsupported status |
| Highlight reconstruction (#65) | `reconstruct_highlights` in `app/rust/src/raw.rs`; 3 unit tests |
| Ultra HDR / gain maps (#20) | `UltraHdrMetadata`, `generate_gain_map`, `encode_gain_map_jpeg`, `build_mpf_segment`, `build_ultrahdr_xmp_segment`, `encode_ultra_hdr_jpeg`, `extract_gain_map`, `reconstruct_hdr_radiance` in `app/rust/src/ultrahdr.rs`; 4 unit tests |

### 🟡 Partial (present but a piece is unwired — these are the bugs)

| Subsystem | What's missing | Issue |
|---|---|---|
| RAW lens corrections | `raw::lens` (vignette + Brown–Conrady distortion) implemented + tested but **not called** by `decode_from_raw`; RAW export drops EXIF | **#66** |
| Basic panel | `whites`/`blacks` are schema-only (never rendered); vibrance is generic, not Adobe skin-tone-weighted | **#59** |
| Wide gamut / linear-P3 | ICC module (`app/rust/src/icc.rs`) implemented + tested but **not wired** into the JPEG decode or export pipeline; no f16 working space | #15 (existing) |
| High-zoom ROI overlay + native ROI decode | Planner/decoder/Rust bake/both platform channels/pyramid wiring tested; **the >100 MP corpus + seam harness has not had its first on-device run** (`tile_corpus_test.dart`, report-only until `CORPUS_STRICT=1` passes on the pinned device); iOS channel needs an Xcode build to verify | **#16** |
| DCP HueSatMap | `HueSatMap` struct + `sample`/`apply_to_rgb`/`interpolate` implemented + tested in `raw.rs` but **never populated from DNG files** — `hue_sat_map` is always `None`; DCP `HueSatMapData`/`LookTable` tags not parsed | #64 |
| ML runtime | `SaliencySegmenter` + `Segmenter` trait + `estimate_depth_map` implemented; `ml.rs` module complete. **No ONNX Runtime/ncnn crate, no model weights, no `ai` feature-gated inference path** | #21 |

### ⬜ Not started (the remaining roadmap)

| Subsystem | Issue |
|---|---|
| Golden-image tolerance corpus | **#60** |
| LGPL dynamic-linking packaging | **#67** |
| F-Droid submission | **#69** |

---

## 2. Workload distribution (Dart/Flutter vs Rust)

### Rust (the engine owns all pixel math)
- Decode + ROI + tile fetch; demosaic, WB, DNG matrices, lens corrections, RAW colour.
- Colour pipeline + spatial filters + masking coverage; 65³ LUT bake; preview base + histogram.
- **Full-res banded export** (grade → geometry → masks → spatial → encode) with the memory budget and cancel.
- SIMD kernels; all future DCP/HueSatMap, guided filter, dehaze, highlight reconstruction.

### Dart/Flutter (presentation + control only — no per-pixel work)
- Shells, panels, gestures, histogram rendering, tone-curve editor, masking overlay, LUT/preset import UI.
- Riverpod `RecipeController` (single source of truth) + sidecar persistence.
- Drives Rust via one **spec object** per stage; consummate the spec with `fromRecipe` mappers.
- Widget tree must mount the zero-copy `Texture` when the Rust binding is active (fallback: LUT atlas + shader).

**Invariant:** preview and export share one pipeline. Point-wise grading is baked
to a LUT for the GPU preview and applied per-pixel for export; both call the same
Rust math. Never fork the math between Dart and Rust.

---

## 3. Performance tiers

| Tier | Target | Scope |
|---|---|---|
| Low / mid Android | **60 fps** pan, zoom, and scrubbing | Point-wise + LUT preview; banded export within RAM budget; spatial via SIMD |
| Flagship | **120 fps** for grade-only edits | Zero-copy texture preview; no spatial pass active |
| Any tier, spatial active | 30–45 fps | Clarity/dehaze/guided denoise cost scales with radius; debounce + progressive refine |
| Export | bounded peak RSS regardless of image size | Row-band/tile processing + halo, stream to encoder, free as you go |

Gates: `integration_test/perf_harness_test.dart` (`PERF_STRICT=1` for the fps
gate; default report-only) + the 512 MB RSS budget. The export wiring (#68
single-call + cancel) has landed; the **>50 MP export memory regression** gate
is still to be added.

---

## 4. Canonical pipeline order (target)

This is the order to implement/verify in `app/rust/src/export_pipeline.rs` and
mirror in the preview base (`app/rust/src/preview.rs`). See `ARCHITECTURE.md` §8.

```
 RAW/JPEG decode
   → linearize
   → lens corrections (distortion / vignette / CA)
   → camera white balance
   → DNG colour matrices (temperature-interpolated)
   → DCP profile HueSatMap            <-- #64
   → exposure
   → tone (contrast, highlights/shadows, whites/blacks)   <-- #59
   → colour (vibrance, saturation)
   → HSL / colour mixer
   → tone curves
   → split-tone / colour grading
   → detail (SIMD spatial, halo-free)  <-- #56, #57, #58
   → HALD / 3D LUT (applied LAST among edits)
   → film emulation (halation, bloom, dust flecks, scratches)
   → shader lab (presets + 3 user params + optional custom GLSL)
   → geometry (already GPU-warped live; final Matrix4 resampled here)
   → output transform (sRGB / P3 / wide-gamut)
```

**Rules:**
1. `HueSatMap` (profile CLUT) runs **after** the matrices, **before** the parametric sliders — like Lightroom's profile → Basic order.
2. User 3D/HALD LUTs run **last** among edits, after all parametric sliders.
3. Film emulation (halation, bloom, dust, scratches) runs after the LUT and before the Shader Lab.
4. Spatial filters run in a well-defined working space with overlap padding so bands/tiles blend seamlessly.

---

## 5. Workstreams

Each workstream lists its goal, the exact files, and its issue(s).

### W1 — Full-res export pipeline (#68)
- ✅ Expose the pipeline over FRB: `exportFull` in `app/rust/src/api/export.rs` +
  opaque cancel-token registry (`exportCancelNew/Set/Drop`); bindings regenerated
  (no new module needed — the surface lives in the existing `api/export.rs`).
- ✅ Route Dart through it: `AxEngine.exportJpegFull` runs geometry → banded
  spatial → masks → grade → downscale → JPEG in **one** bridge crossing;
  `exportJpeg` delegates to it, retiring the legacy multi-round-trip chain.
- ✅ Cancel surfaced in the UI: editor Cancel button drives the token (export
  returns `null` on abort → "Export cancelled").
- ✅ Parity oracle covers the full chain: geometry/mask/spatial band-parity tests
  + `tiled_matches_single_for_a_fully_engaged_recipe` (byte-exact, band_rows
  1…100) + FFI cancel/max-dim/decodable-JPEG tests (142 Rust tests).
- ⬜ Hard peak-memory cap via streamed/chunked encode + progress events (the
  `jpeg_encoder` crate has no streaming API; today's ceiling is ~2 frames —
  source + output — until a chunked encoder lands).
- ⬜ `>50 MP` export RSS regression gate in the perf harness.
- **Band-safety invariants discovered (keep when touching the pipeline):**
  band halo = **sum** of the chained ops' supports (not the max); separable
  blur prefix sums accumulate in **`f64`** (f32 rounding varies with region
  origin and flips a u8 truncation); vignette/grain are absolute-coordinate ops
  and must be offset to full-image coordinates per band.
- Files: `app/rust/src/export_pipeline.rs`, `app/rust/src/api/export.rs`,
  `app/lib/engine/engine.dart`, `app/lib/features/editor/editor_screen.dart`,
  `app/lib/gallery/gallery_export.dart`.

### W2 — Finish zero-copy preview (#54) — ✅ Android landed (iOS registration remains)
- ✅ Mount `Texture(textureId: _textureId)` when the Rust binding is active (`PreviewSurface`), with the shader/atlas paint as fallback.
- ✅ Placeholder gate no longer demands a baked LUT in texture mode (`previewNeedsPlaceholder`) — that gate was what pinned the viewport to "Loading image…".
- ✅ Delivery switching (`useTextureDelivery`): compare/peek crossfades and imported-LUT sessions force the shader path for the gesture and return to zero-copy when the animation settles (status + provider listeners re-schedule the bake).
- ✅ `dispose()` now releases the platform texture (was leaked).
- ⬜ iOS: implement texture registration or explicitly document Android-only gating (the channel already degrades to `null` off-Android).
- ⬜ On-device validation of the mounted texture path (integration tests cover the FFI/render, not the widget mount).
- Files: `app/lib/viewport/preview_surface.dart`, `app/lib/viewport/image_canvas.dart`, `app/lib/engine/preview_texture.dart`, `app/rust/src/api/preview.rs`, `MainActivity.kt`.

### W3 — Tiles & viewport resolution (#16 + #55) 🟢 *(code complete; on-device corpus run pending)*
- ✅ **#55** high-zoom ROI overlay: `planRoiOverlay` (threshold at `scale·fitted ≥ proxyW`, geometry-identity gate, 32 MiB band budget), `roiStripRect`/`roiBlockedByGeometry`, `RoiDecoder` (native `aperturex/roi_decode` above 64 MiB full-RGBA, Rust `decodeJpegRoi` fallback), `spatial::apply_spatial_roi` + `api/roi::{roi_halo,bake_roi_band}` with halo rows + geometry guard + `preview_base` parity, canvas wiring (debounced `_runRoi`, token-guarded, overlay strip through `lut.frag`, `useTextureDelivery(roiActive:)` forces the shader path).
- ✅ **#16 (both platforms)** `aperturex/roi_decode`: Android `BitmapRegionDecoder` (single-thread executor, tight RGBA repack) + iOS `CGImageSource` (`AppDelegate.swift`: lazy crop, flipped bitmap context for top-origin RGBA, serial queue, matching error contract); Dart `decodeBand`/`decodeRect` share one tier probe + Rust fallback.
- ✅ **#16 (pyramid)** `TileSource`/`JpegTileSource` + `TileViewport` source mode: zoom-matched levels via `TilePyramid.levelForScale`, byte-budgeted footprints (default 64 MiB → level 3 at 512-tile for ~100 MP), box downsample with factor-aligned seams, coarse-ancestor instant paint, failed-key memoisation. Seam/footprint/downsample/clamp covered by 20 unit tests; corpus pattern position-encoded (`synthetic_jpeg` determinism test).
- ✅ **#16 (corpus + harness)** `examples/gen_corpus.rs` (file corpus, never committed) + `integration_test/tile_corpus_test.dart`: generates/loads >100 MP JPEG, byte-exact seam sweep against oracle strips at every feasible level, zoom-out clamp walk, RSS + latency report with `CORPUS_STRICT` gates. **First on-device run outstanding** (Android channel live; iOS awaits an Xcode build).
- Files: `app/lib/viewport/roi_overlay.dart`, `app/lib/viewport/roi_decoder.dart`, `app/lib/viewport/tile_source.dart`, `app/lib/viewport/tile_viewport.dart`, `app/lib/viewport/tile_pyramid.dart`, `app/lib/viewport/image_canvas.dart`, `app/lib/viewport/preview_surface.dart`, `app/rust/src/spatial.rs`, `app/rust/src/api/roi.rs`, `app/rust/src/api/engine.rs`, `app/rust/examples/gen_corpus.rs`, `app/integration_test/tile_corpus_test.dart`, `MainActivity.kt`, `ios/Runner/AppDelegate.swift`.

### W4 — SIMD spatial kernels (#56) — ✅ DONE
- NEON (aarch64) + SSE (x86_64) intrinsics inline in `app/rust/src/spatial.rs` (`vector_mul`, `vector_sqr`, `vector_linear_combination`, `vector_guided_coeffs`, `vector_variance`, `vector_unsharp`) with scalar fallback; 5 unit tests in `spatial.rs`.
- Files: `app/rust/src/spatial.rs`.

### W5 — Halo-free local tone (#57, #58) — ✅ DONE
- Guided filter for shadows/highlights + clarity with overlap-aware banding; dark-channel-prior dehaze in linear space; all unit-tested.
- Files: `app/rust/src/spatial.rs`, `app/rust/src/color.rs`, `app/rust/src/export_pipeline.rs` (parity tests).

### W6 — Basic panel fidelity (#59) — ⚠️ PARTIAL
- `whites`/`blacks` schema fields exist but are not rendered; vibrance is generic, not Adobe skin-tone-weighted.
- Files: `app/rust/src/color.rs`, `app/lib/edit/recipe.dart`, `app/lib/color/grade_spec.dart`.

### W8 — Golden-image tolerance corpus (#60) — ✅ DONE
- `docs/GOLDEN.md` specification + `app/test/color/golden_corpus_test.dart` (Dart) + `golden` module in `app/rust/src/color.rs` with `generate_test_chart()` and `compare_golden()`.
- Tolerance gates: mean ΔE₇₆ ≤ 1.0, max ΔE₇₆ ≤ 2.0, MAE ≤ 1/255, max byte diff ≤ 2.
- Fixed recipe suite: Basic Panel, Tone Curves, HSL Mixer, Color Wheels/Split-Tone, Clarity, Dehaze.
- Files: `app/test/color/golden_corpus_test.dart`, `app/rust/src/color.rs`, `docs/GOLDEN.md`.

### W9 — Persistence & preset breadth (#61, #62) — ✅ DONE (#62), ⬜ NOT STARTED (#61)
- `.lrtemplate` parser + compatibility report done (#62).
- Recipe sidecar persistence (#61) not implemented — `app/lib/edit/sidecar.dart` referenced but doesn't exist.
- Files: `app/lib/edit/lrtemplate_preset.dart`, `app/lib/edit/xmp_preset.dart`.

### W10 — RAW colour science (#64, #65, #66) — ✅ DONE (#64, #65), ⚠️ PARTIAL (#66)
- `HueSatMap` struct + `sample`/`apply_to_rgb`/`interpolate` implemented + tested; **DNG HueSatMap parsing (tag 0xC74E) wired into `decode_from_raw`** and applied in both 3-component and Bayer decode paths (#64).
- `reconstruct_highlights` implemented + tested (#65).
- Lens correction primitives implemented at decode time; **wired as user sliders** in `OpticsControls` UI (defringe purple/green, profile distortion/vignetting) with full Dart→Rust pipeline (#66).
- Files: `app/rust/src/raw.rs`, `app/rust/src/color.rs`, `app/rust/src/optics.rs`, `lib/ui/common/optics_controls.dart`.

### W11 — License & packaging (#67) — ✅ NOT NEEDED (closed)
- Decided: use only pure-Rust `rawler` (LGPL-2.1, GPL-3 compatible). No LibRaw/lensfun dynamic linking required.
- `app/rust/Cargo.toml` has `rawer = "0.8.0"` as a static dependency; `raw-libraw` feature flag not enabled.
- `THIRD_PARTY.md` documents the LGPL-2.1 compatibility reasoning.
- Files: `app/rust/Cargo.toml`, `THIRD_PARTY.md`.

### W13 — Crash resilience & observability (ADR 0012)
- **Pure error boundary**: `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.onError` (return true → app lives) + `ErrorWidget.builder` fallback; Rust panic hook; Kotlin channel `try/catch` audit + `AxApplication` uncaught handler with crash marker.
- **`ErrorReporter`**: classify/dedupe/throttle → `axLog` with `error`/`stack` fields → `ErrorDialog` (View logs → `LogsScreen(initialDomain:)`, Copy, Dismiss) via root `navigatorKey`; next-launch `CrashReportDialog` reads the Dart marker **or** Kotlin's marker (channel) — either way: View logs / Copy / Dismiss, markers consumed once.
- **Log schema v2** (optional `error`/`stack`/`meta`, new domains `error`/`crash`/`nav`/`native`/`engine`), `LogFileStore` 2 MiB rotation, `hydrateActivityLog` merges `activity.log` + `native.log` (channel) + `rust_panic.log` (LogEntry-JSONL from the panic hook) on startup, nav + lifecycle observers.
- Slices TDD'd in order: schema/rotation → reporter → boundary wiring → dialog/fallback UI → observers → LogsScreen stack detail → Kotlin (APK gate) → Rust hook (cargo) → docs.
- Files: `app/lib/core/log/{activity_log,log_file_store,log_providers,native_log_bridge,nav_observer,lifecycle_observer}.dart`, `app/lib/core/error/*` (new), `app/lib/features/logs/logs_screen.dart`, `app/lib/main.dart`, `app/android/.../AxApplication.kt` + `NativeLog.kt` (new), `app/rust/src/api/logging.rs` (new).

---

## 6. Sequencing & dependencies

```
            ┌─ W2 zero-copy texture ─┐
P1 core ────┤                        ├─► W4 SIMD ─► W5 guided/dehaze ─► W6 basic
            ├─ W1 export wiring ─────┤
            └─ W3 tiles/ROI (#16) ───┘              W8 goldens gate every colour change
W7 brush (P2.5)      W9 persistence/presets      W10 RAW colour (after W5)      W11 packaging
```

- **W1 and W2 unblock everything UX-visible** and are small, high-value: do first.
- **W3 (#16)** is the prerequisite for **#55**.
- **W4 → W5**: SIMD the box backbone before the guided filter so the filter is fast on day one.
- **W8** should start early and grow; it gates colour regressions from W5/W6/W10.
- **W11** only matters when `raw-libraw`/lensfun are enabled (not the default build).
- **W13 (ADR 0012)** is cross-cutting UX insurance: it can start any time, unblocks nothing, and is ordered after the ROI overlay so crash evidence covers the new decode paths too.

---

## 7. Memory budget (unchanged from ARCHITECTURE §9)

- Peak preview: proxy + tile LRU ≤ ~512 MB device limit; never materialize full-res as one texture.
- Export: bounded by the band/tile working set (independent of image dimensions), streamed to the encoder; free after encode.
- Add an explicit `ImageCache.maxByteSize` policy to avoid thrash.

---

## 8. License / compliance

- Default RAW decoder is pure-Rust `rawler` (LGPL-2.1) → GPL-3 compatible, F-Droid from-source friendly.
- Optional `libraw` (`raw-libraw` feature) is LGPL-2.1/CDDL and must be **dynamically linked** if shipped (#67). Lensfun (LGPL-3) follows the same rule.
- Every new dependency/model needs a `THIRD_PARTY.md` row (W11 tracks the native-lib rows).

---

## 9. Issue index

| # | Title | Workstream | Phase |
|---|---|---|---|
| [#54](https://github.com/prit-007/ApertureX/issues/54) | Bug: zero-copy Texture never displayed | W2 | P1 |
| [#55](https://github.com/prit-007/ApertureX/issues/55) | Viewport high-zoom ROI overlay | W3 | P1 |
| [#56](https://github.com/prit-007/ApertureX/issues/56) | SIMD spatial passes | W4 | P1 |
| [#57](https://github.com/prit-007/ApertureX/issues/57) | Guided-filter shadows/highlights + clarity | W5 | P2 |
| [#58](https://github.com/prit-007/ApertureX/issues/58) | Dark-channel dehaze | W5 | P2 |
| [#59](https://github.com/prit-007/ApertureX/issues/59) | whites/blacks + Adobe vibrance | W6 | P2 |
| [#60](https://github.com/prit-007/ApertureX/issues/60) | Golden-image tolerance corpus | W8 | P2 |
| [#61](https://github.com/prit-007/ApertureX/issues/61) | Recipe sidecar persistence | W9 | P2 |
| [#62](https://github.com/prit-007/ApertureX/issues/62) | `.lrtemplate` import | W9 | P2 |
| [#63](https://github.com/prit-007/ApertureX/issues/63) | Brush masks into adjustment layers | W7 | P2.5 |
| [#64](https://github.com/prit-007/ApertureX/issues/64) | DCP `HueSatMap` support | W10 | P3 |
| [#65](https://github.com/prit-007/ApertureX/issues/65) | Highlight reconstruction | W10 | P3 |
| [#66](https://github.com/prit-007/ApertureX/issues/66) | RAW lens corrections + EXIF | W10 | P3 |
| [#67](https://github.com/prit-007/ApertureX/issues/67) | LGPL dynamic-linking packaging | W11 | P3 |
| [#68](https://github.com/prit-007/ApertureX/issues/68) | Rust export wiring + memory cap | W1 | P4 |

**Distribution / infrastructure** (CI + releases + F-Droid are built — see
ROADMAP P5 and ADR 0004):

| # | Title | Workstream | Phase |
|---|---|---|---|
| [#69](https://github.com/prit-007/ApertureX/issues/69) | F-Droid submission: vendored crates + fdroiddata MR | W12 | P5 |
| [#70](https://github.com/prit-007/ApertureX/issues/70) | iOS CI build (macOS runner, unsigned) | W12 | P5 |

Pre-existing trackers referenced above: [#16](https://github.com/prit-007/ApertureX/issues/16) (native ROI + tiles), [#19](https://github.com/prit-007/ApertureX/issues/19) (RAW import), [#15](https://github.com/prit-007/ApertureX/issues/15) (wide gamut), [#20](https://github.com/prit-007/ApertureX/issues/20) (Ultra HDR), [#21](https://github.com/prit-007/ApertureX/issues/21) (ML module), [#41](https://github.com/prit-007/ApertureX/issues/41) (edge-to-edge shell), [#33](https://github.com/prit-007/ApertureX/issues/33) (rename).
