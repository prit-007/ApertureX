# ApertureX — Roadmap

Each phase is independently demoable and leaves the tree green. Phases are
ordered to retire the highest-risk assumptions earliest.

Legend: **[scope]** → *exit criteria*.  Status: ✅ done · 🚧 in progress · ⬜ not started.

**Current status:** P-1 ✅ · P0 ✅ (foundations + JPEG proxy folded into P1) · P1 🚧 (viewport + tile compositor + zero-copy preview *partly* wired + EditRecipe v1 + basic JPEG export done; a **bug blocks the zero-copy Texture display** (#54), and native ROI + >100 MP profiling + tile pyramid remain (#16)) · **P2 🚧** (recipe superset + Riverpod controller + shared ParameterControl + dual-shell skeleton + full point-wise colour pipeline (LUT, WB/exposure/contrast/vibrance/saturation/split-tone/curves) + **spatial passes** + **geometry** + **presets/LUT/.xmp import** + preview==export + live histogram done; whites/blacks + Adobe vibrance (#59), sidecar persistence (#61), `.lrtemplate` (#62), guided-filter/quality refinements remain) · P2.5 🚧 (linear/radial/luminance masks + layer model landed; **brush wiring** pending #63) · P3 🚧 (rawler RAW decode/demosaic/matrices/orientation/ROI/export landed; corpus, EXIF passthrough, lens-correction wiring (#66), DCP profiles (#64), highlight reconstruction (#65) remain).

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

## P0 — Foundations 🚧

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

**Status — mostly met.** Repo + LICENSE, CI, the Material 3 shell with
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
texture) is implemented and Rust-tested, but **not yet integrated into the widget
tree** — the viewport never mounts a `Texture` widget, so texture mode falls back
to the "Loading image…" placeholder ([#54](https://github.com/prit-007/ApertureX/issues/54)); the shader/atlas path is the
working fallback. **Remaining:** finish zero-copy display (#54), native ROI
decoders + multi-level tile pyramid to avoid full-decode for >100 MP (#16),
high-zoom ROI overlay (#55), device-tier probe + >100 MP corpus with
memory/60 fps profiling, and SIMD spatial kernels for the 60 fps gate (#56).

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
compatibility report). **Remaining:** render `whites`/`blacks` and make vibrance
Adobe-skintone-accurate (#59), **sidecar persistence** — the encoder exists and
is tested but is never saved/loaded in the app (#61), `.lrtemplate` import (#62),
halo-free guided-filter shadows/highlights + clarity (#57), dark-channel dehaze
(#58), SIMD spatial (#56), and the golden-image tolerance corpus (#60).

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

**Status — in progress.** The layer model and analytic masks landed:
`MaskKind {linear, radial, luminance}` in `edit/adjustment_layer.dart`, layer
add/update/remove in `RecipeController`, `apply_masks` in Rust (`mask.rs`:
`coverage`/`apply_local`/`apply_local_band`), node editing UI/overlay, and
preview+export both carry `recipe.layers` — all tested. **Remaining:** the
**brush** mask. `features/masking/paint_brush.dart` (pressure-aware, unit-tested)
exists but is a standalone class, not wired to `AdjustmentLayer`/preview/export;
stylus-only filtering + `invertedStylus` eraser pending
([#63](https://github.com/prit-007/ApertureX/issues/63)).

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
- [ ] **Wire** lens corrections into the decode path (currently implemented but never called) ([#66](https://github.com/prit-007/ApertureX/issues/66)).
- [ ] **RAW EXIF passthrough on export** (currently empty EXIF for RAF/RAW exports) ([#66](https://github.com/prit-007/ApertureX/issues/66)).
- [ ] DCP camera profile `HueSatMap`/`LookTable` parse + apply (Adobe Standard parity) ([#64](https://github.com/prit-007/ApertureX/issues/64)).
- [ ] Highlight reconstruction for clipped RAW highlights ([#65](https://github.com/prit-007/ApertureX/issues/65)).
- [ ] RAW corpus across real CR2/NEF/ARW/RAF (colour + orientation).
- [ ] Embedded-preview fast path (needs parity-safe progressive swap).
- [ ] DNG 16-bit export / re-encode.

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

**Exit criteria**
- Subject/sky masks usable in the Lightroom shell's Masking panel.
- Base APK (without the AI module) still builds and passes CI; module APK size
  within budget.
- Every shipped model has a verified license row.

---

## P4 — Export & presets 🚧 *(basic JPEG export pulled forward into P1)*

**Scope**
- Full-res tiled export (JPEG/PNG; DNG deferred to P6), cancellable, with
  progress; metadata pass-through.
- Batch export; preset apply at export.
- Background export surviving app backgrounding on both platforms.

**Status — wired end-to-end (single-call + cancel).** The banded, overlap-padded,
cancellable full-res export lives in `app/rust/src/export_pipeline.rs`
(`run_export_tiled` vs `run_export_single` byte-exact parity oracle;
`ExportOutcome::Cancelled`) and is now **exposed over FRB** as `exportFull` with
an opaque cancel-token registry (`exportCancelNew/Set/Drop`). Dart's
`TesseraEngine.exportJpegFull` runs the whole recipe inside Rust — geometry →
banded spatial → masks → grade → optional downscale → JPEG — in **one** bridge
crossing instead of five; `exportJpeg` now delegates to it, so the legacy
multi-round-trip chain is retired. The editor drives a Cancel button off the
token (returns `null` on abort). Verified: 142 Rust tests (spatial/mask band
parity, tiled-vs-single parity, FFI cancel), `cargo fmt`/`clippy` clean, and the
crate cross-compiles for all four Android targets. **Remaining:** a hard
peak-memory cap via streamed encode (the `jpeg_encoder` crate has no streaming
API, so the graded frame is still held for the final encode), a progress
indicator, batch/preset export, and background export
([#68](https://github.com/prit-007/ApertureX/issues/68)).

**Exit criteria**
- Export a 200 MP image without exceeding the memory budget; output pixel-
  consistent with preview.
- Preset/LUT round-trips across devices deterministically.

---

## P5 — Polish & distribution ⬜

**Scope**
- F-Droid metadata + per-ABI version codes (ADR 0004); reproducible release.
- HEIC import/export; accessibility (TalkBack/VoiceOver, dynamic type); i18n;
  onboarding; error/empty states.
- Performance pass on the low-tier device matrix; iPhone validation (P-1 gap).

**Exit criteria**
- Signed Android release + F-Droid build; iOS TestFlight build.
- A11y audit passes; no hard-coded strings in UI.

---

## P6 — Advanced / long tail (post-v1) ⬜

- Healing / spot removal.
- Advanced color grading (parametric curves, full color mixer, split-tone depth).
- Range masks (full), masks refine.
- DNG/TIFF 16-bit export; HDR merge; `flutter_gpu` compute experiments.
- The long tail of Snapseed filters (Glamour, Drama, Vintage, Retrolux, …) as
  recipe-defined looks.

---

## v0.1 ship gate (Android-only, before P3.5)

A deliberately small, releasable slice that proves the product end-to-end:
- Open → edit (basic + a couple of masks) → export a JPEG.
- Lightroom-default shell + Snapseed toggle both functional (even if breadth
  differs — see `PARITY.md`).
- LUT + basic `.xmp` import with compatibility report.
- F-Droid-clean, no AI module required.
- Code/package identifiers renamed to ApertureX (pubspec, Android applicationId,
  Rust crate) — mechanical, scheduled so it never lands mid-phase.

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
