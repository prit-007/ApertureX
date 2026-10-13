# ApertureX — Roadmap

Each phase is independently demoable and leaves the tree green. Phases are
ordered to retire the highest-risk assumptions earliest.

Legend: **[scope]** → *exit criteria*.  Status: ✅ done · 🚧 in progress · ⬜ not started.

**Current status:** P-1 ✅ · P0 🚧 (foundations done; real-image decode folded into P1) · P1 🚧 (viewport core + tile compositor + EditRecipe v1 + basic JPEG export done; native ROI + >100 MP profiling + tile pyramid remaining) · P2+ queued.

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
tests green. **Remaining:** native ROI decoders to avoid full-decode for >100 MP,
device-tier probe, a >100 MP corpus with memory/60 fps profiling, and the
multi-level tile pyramid.

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

- **Fork maintenance** of `pro_image_editor` (`FORK-STRATEGY.md`).
- **Color correctness** golden tests, expanded each phase (incl. preset
  fidelity, ADR 0009).
- **Memory/performance regression** benchmarks in CI on a pinned device profile.
- **Parity ledger** upkeep (`PARITY.md`) — status moves only when demoable +
  tested.
- **ML model license ledger** (`THIRD_PARTY.md`) — hard gate before any model
  ships (ADR 0010).
