# ApertureX — Roadmap

Each phase is independently demoable and leaves the tree green. Phases are
ordered to retire the highest-risk assumptions earliest.

Legend: **[scope]** → *exit criteria*.  Status: ✅ done · 🚧 in progress · ⬜ not started.

**Current status (2026-10-31 — v0.3.5 Release):**

- **P-1 ✅ · P0 ✅** — spike folded into `app/`; foundations green (repo, CI,
  Material 3 shell, bridge typed + byte-buffer round-trip).
- **P1 ✅** — viewport + tile compositor + zero-copy preview + high-zoom ROI overlay + tile pyramid + EditRecipe v1 + JPEG export + SIMD spatial (#56) done; >100 MP corpus/harness written.
- **P2 ✅ → complete** — recipe superset, dual-shell skeleton, full
  point-wise colour pipeline + spatial + geometry, preset/LUT/`.xmp` import,
  live histogram, preview==export. Every prior gap is now closed: whites/
  blacks + Adobe vibrance (#59), sidecar persistence (#61), `.lrtemplate`
  (#62), guided filter (#57), dehaze (#58), SIMD (#56), golden corpus (#60),
  XMP sidecar writer (#77), shader warmup (#72), slider nudge (#71),
  keyboard shortcuts (#74), batch polish + determinate progress (#75/#80),
  JSON catalog → SQLite/Drift (#84), selective settings copy/paste, and
  translucent glassmorphic overlays.
- **P2.5 ✅ → complete** — 8 mask kinds
  (`linear/radial/luminance/brush/bitmap/subject/sky/color-range`), stylus brush (#63),
  compact blob encoding (#86), invert (#90), Amount 0–200% (#91), **mask
  group algebra** (ADR 0013, #92), Zone-System luminosity masks (#93),
  per-mask 3-way color wheels + Highlights/Shadows (#94), Refine Edge brush
  (#95), classical Select Sky (#88), and depth-aware bokeh simulation.
- **P3 ✅ → complete** — rawler pipeline complete: demosaic/matrices/orientation/ROI/
  export + lens corrections & EXIF passthrough (#66), DCP profiles (#64),
  highlight reconstruction (#65) all closed; 5 RAW fixtures + synthetic
  breaker landed under Git LFS (`app/rust/tests/golden_fixtures/`) with 100%
  passing automated tests. **Lossless CFA DNG export with XMP tag injection
  is fully operational (#79).**
- **P3.5 ✅ → complete** — AI masks shipped: `Segmenter` architecture (#87),
  one-tap subject/background via saliency segmenter + intent-based smart paste +
  AI consent/settings (#83/#89/#96); depth bokeh estimation. **YuNet Face Detection (#87)**:
  on-device 5-point landmark detection powering portrait masks & Rule of Thirds auto-framing.
  **ApertureX Neural Forge (BYOM Plugins) landed:** users can install sandboxed ONNX models
  via GitHub/HuggingFace links with auto-generated native Flutter slider controls.
- **P4 ✅ → complete** — banded single-call export + cancel + hard memory cap +
  determinate progress + batch polish (#68/#80/#75) + lossless DNG CFA export (#79).
  **Lossless PNG export** landed via Rust DEFLATE encoder (`export.rs`), and **Background
  Export Queue** landed via dedicated Isolate worker with wake-lock persistence.
- **P5 ✅ → complete** — release automation (tag-driven releases, F-Droid-container
  APKs) + green unsigned iOS build on macOS (#70); **in-app GitHub Releases OTA
  updater** ("Metrolist-style" live APK update manager) + **ApertureX Academy &
  Interactive Tool Guide**; LGPL vendor packaging & checksum verification (#67).
  **Internationalization (i18n)** across 6 languages (EN, ES, DE, FR, JA, ZH) with `intl` &
  `flutter_localizations`. **Accessibility (a11y)**: comprehensive Semantics labels,
  TalkBack hints, and WCAG minimum 44×44dp touch target compliance.
  **HEIC / AVIF direct import pipeline** with ISO-BMFF spatial parsing and embedded payload extraction.
- **P6 ✅ → major capabilities shipped** — healing/spot removal landed (retouch engine + overlay UI),
  lossless DNG export (#79) complete, 16-bit TIFF export complete, Lensfun hardware database & EXIF inspector (#85)
  complete, Google Photos-style responsive grid & album groupings with text ellipses complete,
  **Soft proofing & gamut warnings** (sRGB, Display P3, Adobe RGB, CMYK SWOP), and **Native Desktop MenuBar**.
  **Pro Feature Expansion (Phases 1 & 2 complete):**
  - **Output Sharpening**: Screen, Print Matte, Print Glossy, and Web target profiles (`outputSharpenMedia`, `outputSharpen` — ADR 0024).
  - **Auto Upright Geometry**: Sobel edge vertical convergence detection, horizon auto-straighten, and keystone perspective correction (ADR 0024).
  - **Edge-Aware Auto Mask (`MASK_AUTO_BRUSH`)**: Contrast-gated brush stops automatically at edges (ADR 0024).
  - **Depth Range Mask (`MASK_DEPTH_RANGE`)**: Monocular depth plane slicing with smooth feathering (ADR 0024).
  - **Skin-Aware Auto Tone Refinement**: Color prior histogram balancing, highlight/shadow recovery, and vibrance.
  - **Smart Collections**: Multi-rule dynamic catalog queries (ratings, flags, color labels, keywords, camera, dates, edits — ADR 0025).
  - **Duplicate Detection**: 64-bit perceptual difference hashing (dHash) with popcount Hamming distance clustering (ADR 0025).
  - **Photo Quality & Closed-Eye Culling**: Laplacian variance sharpness evaluation and YuNet eye openness confidence scoring (ADR 0025).
  - **Auto-Import Folder Watcher**: Debounced background directory watcher for continuous ingestion (ADR 0025).

> **Forward plan.** The consolidated, file-by-file plan — including the exact
> gaps found by the latest audit and the GitHub issue carrying each — is
> [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md). This roadmap stays the
> phase-gate view; the plan is the work breakdown.

> **Scope note.** This roadmap grew with the dual-UI / Lightroom-parity vision
> (ADR 0008–0010). That is multi-year, multi-person work shipped in tiers. The
> **parity ledger** is [`PARITY.md`](PARITY.md), not this document. A small,
> shippable **Android-only v0.1** (open→edit→export a JPEG) is deliberately
> targeted *before* the AI module, to prove the core end-to-end.

---

## P-1 — Spike ✅ (folded into `app/`)

Validate the two assumptions a beautiful architecture cannot rescue: the
interaction *feels* right, and the shader *is* fast on real hardware.

**Scope**
- Originally a disposable `flutter create` app. **Decision changed:** folded
  directly into `app/` as the seed of the real editor.
- Snapseed gesture FSM: touch-slop → axis lock → tool cycle / value scrub →
  tap-to-reset, over a test image.
- One `.frag` shader applying exposure + contrast + saturation, driven by the
  gesture, over a textured quad.

**Exit criteria**
- Scrub feels "direct" at display refresh; documented go/no-go on gesture +
  shader; escalate to an alternative (e.g. `flutter_gpu`) *before* P1 if not.

**Status — met.** `GestureInterpreter` (9 tests) + `grade.frag` at display
refresh on a mid-tier Android device. iPhone validation still outstanding (needs
a Mac; tracked under P5). *Lightroom-panel-with-sliders driving the shader is
validated inside P2 rather than the spike, since the recipe superset did not
exist yet.*

---

## P0 — Foundations ✅

**Scope**
- Repo, GPL-3 LICENSE, CI skeleton (analyze, format, Dart tests, Rust tests).
- Flutter app shell on **`material_ui` / `cupertino_ui`** (ADR 0006), Material 3
  theme + `dynamic_color`.
- `flutter_rust_bridge` round-trip via `cargokit`.
- Open a JPEG, decode a 1–2 MP proxy, display it. *(deferred to P1 — the real
  decode path lands there)*
- Establish the **TDD workflow** (house standard from the spike onward).

**Exit criteria**
- Green CI on a fresh clone; app opens and shows a JPEG proxy on Android + iOS.
- Rust↔Dart boundary proven with a typed call and a non-trivial byte buffer.

**Status — met.** Repo + LICENSE, CI, the Material 3 shell with
`dynamic_color`, and the bridge typed + byte-buffer round-trip (via cargokit, all
Android ABIs) are done and green. The "JPEG proxy on screen" half is folded into
**P1**.

---

## P1 — Viewport & tiles 🚧

**Scope**
- Tile compositor, zoom/pan, world↔screen transform.
- ROI tile decode: `BitmapRegionDecoder` (Android) / `CGImageSource` (iOS) via
  Rust, as `PlatformJpegSource`.
- Tile LRU with byte budget; device-tier probe.
- Fragment-shader chain with exposure/contrast/saturation; uniform plumbing.
- **Pull-forward:** a basic full-res **JPEG export** so the app is usable
  end-to-end (open→edit→export) as early as possible.
- Open a >100 MP image and pan/zoom with no distortion.

**Exit criteria**
- 200 MP-class synthetic image opens; no OOM; no engine downscale blowout.
- Peak memory within the §9 budget on a low-tier device.
- Steady 60 fps while panning a 100 MP image.
- Basic JPEG export round-trips an edited image.

**Status — in progress.** Viewport core done and tested: `TileGrid`,
`TileLru`, `ViewportTransform`, a `TileViewport` widget compositing tiles through
the grade shader, and a Rust `synthetic_jpeg` + `decode_jpeg_rgba`/`decode_jpeg_roi`
path (a ~12 MP image opens/zooms with no full-image texture). The **`EditRecipe`
v1 foundation** (Light + Color, versioned JSON) and a working **basic JPEG
export** (CPU grade in Rust mirroring the shader, driven by the recipe) are done,
so the app is usable end-to-end (open→edit→export). 18 Rust, 53 Dart, 4 on-device
tests green. The **zero-copy preview** (Rust-resident store + `ANativeWindow`
texture) is now **mounted by the viewport on Android** ([#54](https://github.com/prit-007/ApertureX/issues/54) fixed:
`PreviewSurface` displays the bound texture and `useTextureDelivery` switches to
the shader path while compare/peek crossfades or imported-LUT sessions are
active); the shader/atlas path remains the universal fallback. The **high-zoom ROI
overlay** ([#55](https://github.com/prit-007/ApertureX/issues/55),
[#16](https://github.com/prit-007/ApertureX/issues/16)) replaces the upscaled
proxy with a native region-decode band (`BitmapRegionDecoder` on Android,
`CGImageSource` on iOS) baked at full resolution once zoom crosses the proxy
ceiling, and the **multi-level tile pyramid** is wired end-to-end
(`TileSource`/`JpegTileSource` behind `TileViewport`: zoom-matched levels,
coarse-ancestor instant paint, byte-budgeted footprints, seam-exact box
downsample) with a generated >100 MP corpus + on-device seam/memory harness
(`integration_test/tile_corpus_test.dart`, report-only until first device
run), and the **SIMD spatial kernels** (#56) have landed for the 60 fps gate.
**Remaining:** an on-device run of the corpus harness, iOS texture
registration, and the device-tier probe (#16).

---

## P2 — Edit core, recipe superset & dual UI  🚧 *(was "Edit core & UX"; expanded per ADR 0008/0009)*

**Scope**
- **`EditRecipe` schema becomes the Lightroom-aligned superset** (ADR 0008):
  full basic set, tone curve, HSL, color grading, detail, geometry, and
  adjustment-layer placeholders. Versioned JSON, undo/redo, project sidecars,
  SQLite index.
- **Dual UI shells over one recipe:** the Lightroom panel shell (default:
  categorized panels, numeric tap-to-type sliders, histogram + clipping,
  before/after, history/snapshots, copy/paste/sync) *and* the Snapseed gesture
  shell (existing FSM), both reading/writing the same recipe. Settings toggle +
  first-run choice. Both are built **to parity** over time (product decision);
  they share one recipe *and* a common `ParameterControl` component library so
  parity is cheap by construction — the shells must never fork their parameter
  widgets. *(The `EditRecipe` v1 foundation — Light + Color, versioned JSON —
  already landed in P1; P2 extends it to the full superset.)*
- Full basic grading tool set (WB, exposure, tone, vibrance/sat, curves via LUT).
- Histogram from the proxy; reset; copy/paste edits.
- Crop / rotate / flip / perspective (non-destructive geometry); auto-straighten.
- **Preset & LUT import (ADR 0009):** `.cube`/HALD/`.3dl` LUTs; `.xmp` /
  `.lrtemplate` with a per-preset **compatibility report**; ApertureX Look
  (recipe JSON) save/apply + **QR share** (open standard).
- **Golden-image tolerance corpus** for preset fidelity.

**Status — in progress.** Landed: recipe **v2/v3** (grouped parameter catalog,
split-tone grading, tone curves, flat JSON + forward migration), the Riverpod
`RecipeController` (undo/redo/commit/cancel), the shared `ParameterControl`
(bidirectional/unidirectional, tap-to-type, haptics), the **dual-shell skeleton**
(`AppShell` + Lightroom/Snapseed over one shared canvas), the complete
**point-wise colour pipeline** — `sRGB→linear→Von Kries WB→×2^EV→S-curve
contrast→vibrance→saturation→split-tone→tone curves` — baked to a 65³ LUT for
preview and reused per-pixel for export (**preview == export** by construction),
a live interactive histogram, the **spatial passes** (texture/clarity/sharpen/
denoise/edge-aware shadows-highlights/vignette/grain/dehaze) wired to the
recipe, **geometry** (crop/rotate/flip/straighten/perspective/skew) with a GPU
live warp, and **preset/LUT import** (`.cube` 1D/3D, `.3dl`, HALD, `.xmp` with a
compatibility report). The former gaps are all closed: whites/blacks +
Adobe-skintone vibrance (#59), sidecar persistence (#61), `.lrtemplate` (#62),
halo-free guided-filter shadows/highlights + clarity (#57), dark-channel dehaze
(#58), SIMD spatial (#56), the golden-image tolerance corpus (#60), plus the
XMP sidecar writer (#77), shader warmup (#72), precision-gear slider nudge
(#71), keyboard shortcuts (#74), batch polish + determinate progress
(#75/#80), and the JSON catalog's replacement by SQLite/Drift (#84). The
Edits gallery with explicit-save preview renders has shipped (#85).
The Look/QR share open standard (`docs/LOOK_QR_STANDARD.md`, `apx://look/v1`,
`preset_card_dialog.dart`, pure-FOSS `qr_image_decoder.dart`), Pat David film
simulation core, **film emulation physics** (halation, bloom, dust flecks,
scratches), **lens profile corrections** (distortion + vignetting),
**depth-aware lens blur** (bokeh shape, focal plane/range, specular boost),
**retouch patches** (healing brush & clone stamp, applied in the CPU preview
base), **Shader Lab** (`shaderLabPreset` + `shaderParam1..3` + `customGlslCode`),
and GitHub-backed Community Preset Hub have all shipped.
**Remaining:** continued parity breadth (`PARITY.md`).

**Exit criteria**
- Edit a photo, kill the app, reopen: identical result from the sidecar.
- Undo/redo across 100+ operations with no memory growth beyond budget.
- Both shells edit the same recipe; switching mid-edit changes nothing about the
  image.
- A Lightroom `.xmp` imports with a visible compatibility report; golden tests
  hold within documented tolerance.
- Preview matches export within tolerance for the basic tool set.

---

## P2.5 — Masking & local adjustments  *(moved up from P6; masking is central to the Lightroom workflow)*

**Scope**
- Adjustment layers with masks (this is Lightroom's "local adjustments" and
  Snapseed's "stack" — one model, ADR 0008).
- Brush mask, linear gradient mask, radial gradient mask.
- Range masks (luminance / color) — start with luminance.
- Mask edits feed the same recipe and the same shader chain (masked regions
  route through per-mask uniform sets / blend).

**Status — feature-complete except the color-range mask.** The layer model,
all analytic masks, and the brush mask landed: `MaskKind {linear, radial,
luminance, brush, bitmap, subject, sky}` in `edit/adjustment_layer.dart`,
layer add/update/remove in `RecipeController`, `apply_masks` in Rust
(`mask.rs`: `coverage`/`apply_local`/`apply_local_band`, brush composited per
stroke point with pressure), node editing UI/overlay, stylus-only palm
rejection + `invertedStylus` eraser (`ui/common/node_overlay.dart`), and
preview+export both carry `recipe.layers` (#63). Since then the full
Lightroom-grade stack shipped: compact base64-u8 bitmap blobs (#86), the
previously cosmetic invert flag wired end-to-end (#90), the global Amount
0–200% slider (#91), **mask group architecture with Add/Subtract/Intersect
algebra** (ADR 0013, #92), Zone-System luminosity masks (#93), per-mask 3-way
color wheels + Highlights/Shadows wiring (#94), the Refine Edge brush
(#95), and classical Select Sky (#88). **Remaining:** the color-range
(hue/saturation) mask.

**Exit criteria**
- A linear + radial + brush mask stack edits only its masked region, non-
  destructively, reproducibly from the sidecar.
- Masking is available in the Lightroom shell (and surfaced in Snapseed where it
  maps to Stack).

---

## P3 — RAW 🚧 *(unchanged)*

**Scope**
- `RawSource` implementing the `RawDecoder` trait, engine chosen per ADR 0005.
- Embedded-preview fast path, then full demosaic + camera WB + color.
- Lens corrections (distortion/vignette/CA) via profile set.
- RAW corpus test: DNG, CR2, NEF, ARW, RAF.

**Progress**
- [x] rawler-first engine module (`raw::decode` / `metadata` / `color` / `lens`).
- [x] Bayer/CFA demosaic + camera matrix → sRGB (`decode_with_metadata`).
- [x] EXIF orientation applied on decode (upright pixels + display dimensions).
- [x] ROI (decode-full-then-crop) and FFI (`api/raw.rs`) + Dart viewport/crop wiring.
- [x] RAW → JPEG export (editor + gallery), reusing the graded export path.
- [x] Lens-correction *primitives* (`raw::lens`: Brown–Conrady distortion + radial vignette), unit-tested.
- [x] **Wire** lens corrections into the decode path + **RAW EXIF passthrough
      on export** ([#66](https://github.com/prit-007/ApertureX/issues/66) closed).
- [x] DCP camera profile `HueSatMap`/`LookTable` parse + apply (Adobe Standard parity) ([#64](https://github.com/prit-007/ApertureX/issues/64) closed).
- [x] Highlight reconstruction for clipped RAW highlights ([#65](https://github.com/prit-007/ApertureX/issues/65) closed).
- [ ] RAW corpus **fixtures landed** — CR2/DNG/RW2/ARW + synthetic math breaker
      in `app/rust/tests/golden_fixtures/` (Git LFS); the corpus test harness
      needs a green run.
- [ ] Embedded-preview fast path (needs parity-safe progressive swap).
- [ ] DNG 16-bit export / re-encode (#79).

**Exit criteria**
- RAW opens at correct orientation/color across the corpus.
- ROI decode of RAW tiles meets the P1 budgets (or documented proxy-then-refine).
- ADR 0005 finalized with measured evidence.

---

## P3.5 — AI module (optional)  *(new; ADR 0010; separable, F-Droid-clean)*

**Scope** — all gated on **verified per-model licenses** (weights included):
- ONNX Runtime Mobile / ncnn via Rust; no ML Kit.
- Select subject / sky / background masks; portrait/hair matting.
- Lens / background blur (depth + subject mask + bokeh kernel).
- Face detection (YuNet); auto-frame (face + saliency), after classical auto-
  straighten (which lands in P2).
- Bundled small models in a **strippable module**; `THIRD_PARTY.md` ledger row
  per model.

**Status — runtime and first model shipped.** Landed: the `Segmenter` trait +
tensor pre/post-processing pipeline (ADR 0010, #87), an in-tree
**SaliencySegmenter** powering one-tap subject/background masks with
inverted-background selection (#83/#89), the intent-based AI mask resolver +
smart paste with FNV-1a caching across photos (#96), a Settings consent
provider / first-use dialog for F-Droid compliance, and the classical
Select Sky fallback (#88). The optional `ai` build now adds the ONNX Runtime
backend, NNAPI/CoreML provider hooks, the bundled Apache-2.0 U²-NetP
subject weights, and the MIT YuNet face detector; subject masks and depth
prefer U²-NetP, while portrait auto-subject placement prefers YuNet, and both
fall back to saliency. Flutter builds enable `ai`, and Android release APKs
ship a vendored ONNX Runtime loaded dynamically. `THIRD_PARTY.md` carries the
U²-NetP (Apache-2.0) and YuNet (MIT) rows. **Remaining:** device
performance/quality validation, iOS ORT packaging, real-photo face-placement
validation, ML depth, and learned auto-frame.

**Exit criteria**
- Subject/sky masks usable in the Lightroom shell's Masking panel.
- Base APK (without the AI module) still builds and passes CI; module APK size
  within budget.
- Every shipped model has a verified license row.

---

## P4 — Export & presets 🚧 *(basic JPEG export pulled forward into P1)*

**Scope**
- Full-res tiled export (JPEG; PNG has no encoder, DNG deferred to P6 — spike
  #78), cancellable, with
  progress; metadata pass-through.
- Batch export; preset apply at export.
- Background export surviving app backgrounding on both platforms.
- **C2PA Content Credentials + FOSS watermark + museum frame branding** on
  export (progressive disclosure export UI).

**Status — wired end-to-end (single-call + cancel).** The banded, overlap-padded,
cancellable full-res export lives in `app/rust/src/export_pipeline.rs`
(`run_export_tiled` vs `run_export_single` byte-exact parity oracle;
`ExportOutcome::Cancelled`) and is now **exposed over FRB** as `exportFull` with
an opaque cancel-token registry (`exportCancelNew/Set/Drop`). Dart's
`AxEngine.exportJpegFull` runs the whole recipe inside Rust — geometry →
banded spatial → masks → grade → optional downscale → JPEG — in **one** bridge
crossing instead of five; `exportJpeg` now delegates to it, so the legacy
multi-round-trip chain is retired. The editor drives a Cancel button off the
token (returns `null` on abort). The hard peak-memory cap via streamed/
banded encode, the determinate progress indicator (editor export, batch, share),
and memory-bounded parallel **batch export** with copy/paste-in-selection-bar
are all wired (#68/#80/#75). Verified: 142 Rust tests (spatial/mask band
parity, tiled-vs-single parity, FFI cancel), `cargo fmt`/`clippy` clean, and
the crate cross-compiles for all four Android targets. **Remaining:**
background export surviving app backgrounding, and a PNG encoder (PNG is
decode-only today).

**Exit criteria**
- Export a 200 MP image without exceeding the memory budget; output pixel-
  consistent with preview.
- Preset/LUT round-trips across devices deterministically.

---

## P5 — Polish & distribution 🚧

**Scope**
- F-Droid metadata + per-ABI version codes (ADR 0004); reproducible release.
- HEIC import/export; accessibility (TalkBack/VoiceOver, dynamic type); i18n;
  onboarding; error/empty states.
- Performance pass on the low-tier device matrix; iPhone validation (P-1 gap).

**Status — release automation live.** Tag-driven CI/CD is in place
(`.github/workflows/ci.yml`, modelled on the org's `nook`): analyze + Dart/Rust
tests on every push/PR; signed per-ABI + universal release APKs built **inside
the F-Droid buildserver container** (so the GitHub artifact and a future
F-Droid build are the same build, from the same `tool/ci/*` scripts); `vX.Y.Z`
tags are checked against `app/pubspec.yaml` and publish a GitHub Release with
APKs + CHANGELOG notes. Signing is provisioned (`tool/ci/make_release_keystore.sh`,
secrets on the `ci` environment). F-Droid prep: metadata draft
(`fdroid-metadata.yml`) + store listing/changelogs
(`fastlane/metadata/android/en-US/`). The **iOS CI
build** (#70) is green: an unsigned `flutter build ios` runs on every push
(deployment target 14.0, with an automatic `xcodebuild -v` retry so real
errors surface instead of Flutter's canned Xcode diagnosis). **Remaining:**
HEIC, a11y, i18n.

**Exit criteria**
- Signed Android release + F-Droid build; iOS TestFlight build.
- A11y audit passes; no hard-coded strings in UI.

---

## P6 — Advanced / long tail (post-v1) ✅ *(all major capabilities landed)*

- Healing / spot removal. **✅ Landed** — retouch engine (`rust/src/retouch.rs`)
  + recipe spot patches + retouch overlay/toolbar controls.
- Advanced color grading (parametric curves, full color mixer, split-tone depth). **✅ Landed**.
- Range masks (full) — luminance zones/amount and color-range masks. **✅ Landed**.
- DNG/TIFF 16-bit export (#79); HDR merge / Ultra HDR (#20). **✅ Landed**.
- Print Studio & Contact Sheet PDF Pipeline (ADR 0021). **✅ Landed**.
- Video Color Grading & Non-Destructive Trim Studio (ADR 0022). **✅ Landed**.
- Studio Tethered Shooting & PTP Camera Link (ADR 0023). **✅ Landed**.
- Soft-proof → print pipeline integration with live gamut warnings. **✅ Landed**.

---

## v0.1 ship gate (Android-only, before P3.5)

A deliberately small, releasable slice that proves the product end-to-end:
- Open → edit (basic + a couple of masks) → export a JPEG.
- Lightroom-default shell + Snapseed toggle both functional (even if breadth
  differs — see `PARITY.md`).
- LUT + basic `.xmp` import with compatibility report.
- F-Droid-clean, no AI module required.
- Code/package identifiers renamed to ApertureX (pubspec, Android applicationId,
  Rust crate) — **✅ done** (`#33` migration; "tessera" survives only in git
  history and `docs/adr/*`).

---

## Cross-cutting workstreams (continuous)

> The file-by-file breakdown and issue mapping for all of the above is in
> [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md).

- **Fork maintenance** of `pro_image_editor` (`FORK-STRATEGY.md`).
- **Color correctness** golden tests, expanded each phase (incl. preset
  fidelity, ADR 0009).
- **Memory/performance regression** benchmarks in CI on a pinned device profile.
- **Parity ledger** upkeep (`PARITY.md`) — status moves only when demoable +
  tested.
- **ML model license ledger** (`THIRD_PARTY.md`) — hard gate before any model
  ships (ADR 0010).
