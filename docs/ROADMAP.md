# Tessera — Roadmap

Each phase is independently demoable and leaves the tree green. Phases are
ordered to retire the highest-risk assumptions earliest.

Legend: **[scope]** → *exit criteria*.  Status: ✅ done · 🚧 in progress · ⬜ not started.

**Current status:** P-1 ✅ · P0 🚧 (foundations done; real-image decode folded into P1) · P1 🚧.

---

## P-1 — Spike ✅ (folded into `app/`)

Validate the two assumptions a beautiful architecture cannot rescue: the
interaction *feels* right, and the shader *is* fast on real hardware.

**Scope**
- Originally planned as a disposable `flutter create` app. **Decision changed:**
  the spike was folded directly into `app/` as the seed of the real editor — the
  gesture FSM and shader proved production-worthy rather than throwaway.
- Implement the Snapseed gesture FSM sketch: touch-slop → axis lock → tool
  cycle (vertical) / value scrub (horizontal) → tap-to-reset, over a static test
  image.
- One `.frag` shader applying exposure + contrast + saturation, driven by the
  gesture, over a full-screen textured quad.
- Measure: input-to-photon latency and sustained frame time on a mid-tier
  Android device and an iPhone.

**Exit criteria**
- Scrub feels "direct" (no perceptible lag) at display refresh on both devices.
- A documented go/no-go on the gesture + shader approach; findings folded back
  into ADR 0006 and ARCHITECTURE §6.
- If the shader path cannot hold frame rate, escalate to ADR for an alternative
  (e.g. `flutter_gpu`) *before* P1.

**Status — met.** `GestureInterpreter` (pure Dart, 9 unit tests) + `grade.frag`
run at display refresh on a mid-tier Android device (motorola edge 50 neo). No
escalation needed: the Flutter fragment-shader path is a go. iPhone validation is
still outstanding (needs a Mac; tracked under P5 device-matrix work).

---

## P0 — Foundations 🚧

**Scope**
- Repo, GPL-3 LICENSE, CI skeleton (analyze, format, Dart tests, Rust tests).
- Flutter app shell built on **`material_ui` / `cupertino_ui`** (per ADR 0006),
  Material 3 theme factory + `dynamic_color` wiring.
- `flutter_rust_bridge` "hello" round-trip building via `cargokit`.
- Open a JPEG, decode a 1–2 MP proxy, display it. *(deferred to P1 — the real image-decode path lands there)*
- Establish the **TDD workflow**: failing test first for every unit (this is the
  house standard from the spike onward).

**Exit criteria**
- Green CI on a fresh clone; app opens and shows a JPEG proxy on Android + iOS.
- Rust↔Dart boundary proven with a typed call and a non-trivial byte buffer.

**Status — mostly met.** Repo + GPL-3 `LICENSE`, CI skeleton, the Material 3
`material_ui`/`cupertino_ui` shell with `dynamic_color`, and the
`flutter_rust_bridge` typed + byte-buffer round-trip (via cargokit, building for
all Android ABIs) are done and green. The "JPEG proxy on screen" half is folded
into **P1**, where the real decode path lands.

---

## P1 — Viewport & tiles 🚧

**Scope**
- Tile compositor, zoom/pan, world↔screen transform.
- ROI tile decode: `BitmapRegionDecoder` (Android) / `CGImageSource` (iOS) via
  Rust, as `PlatformJpegSource`.
- Tile LRU with byte budget; device-tier probe.
- Fragment-shader chain with exposure/contrast/saturation; uniform plumbing.
- Open a >100 MP image and pan/zoom with no distortion.

**Exit criteria**
- 200 MP-class synthetic image opens; no OOM; no engine downscale blowout.
- Peak memory within the §9 budget on a low-tier device.
- Steady 60 fps while panning a 100 MP image.

---

## P2 — Edit core & UX

**Scope**
- `EditRecipe` model (versioned JSON), undo/redo, project sidecars, SQLite index.
- Full basic grading tool set (WB, exposure, tone, vibrance/sat, curves via LUT).
- Gesture FSM wired to the real viewport (not the spike).
- Histogram from the proxy; before/after; reset; copy/paste edits.
- Crop / rotate / flip (non-destructive geometry).

**Exit criteria**
- Edit a photo, kill the app, reopen: identical result from the sidecar.
- Undo/redo across 100+ operations with no memory growth beyond budget.
- Preview matches export within tolerance for the basic tool set.

---

## P3 — RAW

**Scope**
- `RawSource` implementing the `RawDecoder` trait, engine chosen per ADR 0005
  (LibRaw-via-Rust vs pure-Rust).
- Embedded-preview fast path, then full demosaic + camera WB + color.
- Lens corrections (distortion/vignette/CA) via profile set.
- RAW corpus test: DNG, CR2, NEF, ARW, RAF samples.

**Exit criteria**
- RAW opens at correct orientation/color across the test corpus.
- ROI decode of RAW tiles meets the P1 frame/memory budgets (or documented
  fallback to proxy-then-refine for the heaviest cameras).
- ADR 0005 finalized with measured evidence.

---

## P4 — Export & presets

**Scope**
- Full-res tiled export (JPEG/PNG; DNG deferred to P6), cancellable, with
  progress; metadata pass-through.
- Batch export; presets (save/apply/share as JSON).
- Background export surviving app backgrounding on both platforms.

**Exit criteria**
- Export a 200 MP image without exceeding the memory budget; output is
  pixel-consistent with preview.
- Preset round-trips across devices deterministically.

---

## P5 — Polish & distribution

**Scope**
- F-Droid metadata + per-ABI version codes (ADR 0004); reproducible release.
- HEIC import/export; accessibility (TalkBack/VoiceOver, dynamic type);
  i18n scaffolding; onboarding; error/empty states.
- Performance pass on the low-tier device matrix.

**Exit criteria**
- Signed Android release + F-Droid build succeeds; iOS TestFlight build.
- A11y audit passes; no hard-coded strings in UI.

---

## P6 — Advanced (post-v1)

- Local adjustments: linear/radial gradients, brush masks.
- Healing / spot removal.
- Advanced tone controls (parametric curves, color mixer depth).
- DNG/TIFF 16-bit export; HDR merge; `flutter_gpu` compute experiments.

---

## Cross-cutting workstreams (continuous)

- **Fork maintenance** of `pro_image_editor` (see `FORK-STRATEGY.md`).
- **Color correctness** golden tests, expanded each phase.
- **Memory/performance regression** benchmarks in CI on a pinned device profile.
