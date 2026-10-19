# ApertureX — Architecture

> Status: design + partial implementation (P1/P2 in progress). This document
> specifies the system the phases build. It now covers the **dual-UI /
> Lightroom-parity direction** (ADR 0008–0010): two UI shells over one
> Lightroom-aligned recipe, preset/LUT import, masking, and an optional on-device
> ML module. It is implementation-guiding, not an implementation. For the
> **current build status and the gap between this design and the tree**, see
> [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md).

> **Implementation snapshot (kept intentionally short).** The point-wise colour
> pipeline, dual-shell skeleton, geometry (CPU + GPU live warp), spatial passes,
> preset/LUT import, histogram, and rawler-based RAW decode are **built**. The
> banded full-res export is **built and wired** (single `exportFull` bridge call,
> cancellable; streamed encode still pending). The zero-copy texture display and
> native ROI decoders/tile pyramid are **built but not yet wired end-to-end**.
> See the plan for the issue-tracked breakdown.

---

## 1. Goals and non-goals

### Goals
- **Non-destructive** editing: the source pixels are never modified; edits are a
  replayable recipe.
- **Fluid**: adjustment previews track the finger at display refresh rate.
- **Dual-UI**: one recipe rendered by two swappable shells — a Lightroom-style
  precision panel UI (default) and a Snapseed-style gesture UI — over a shared
  Material 3 (Material You) visual system (ADR 0008).
- **Scale**: open and edit images from 48 MP to 200 MP without OOM or visible
  texture distortion.
- **RAW-capable**: a pluggable decode engine that can grow from camera JPEG to
  full RAW (DNG/CR2/NEF/ARW) without an architectural rewrite.
- **FOSS**: GPL-3.0, reproducible, F-Droid-shippable, no telemetry, no accounts.

### Non-goals (v1)
- Web and desktop targets.
- Cloud sync, collaboration, accounts.
- Server-side processing.
- Generative/AI editing features (e.g. Snapseed Expand, Head Pose).
  *Non-generative on-device ML* — subject/sky masks, lens blur, face detect —
  is in-scope as an **optional, F-Droid-clean module** (ADR 0010), not a
  non-goal.
- Video editing.

---

## 2. Layer model

```
┌──────────────────────────────────────────────────────────────────────┐
│  app_ui            Flutter + Material 3 — TWO shells (ADR 0008)     │
│    • Lightroom panel shell (default)  • Snapseed gesture shell      │
│    • both read/write ONE recipe        • histogram, before/after    │
├──────────────────────────────────────────────────────────────────────┤
│  viewport          Flutter / Impeller                                  │
│    • tile compositor        • zoom / pan transform                     │
│    • fragment-shader chain  • texture & tile LRU caches                │
├──────────────────────────────────────────────────────────────────────┤
│  edit_core         Pure Dart                                           │
│    • EditRecipe (versioned JSON)   • undo / redo stack                 │
│    • presets                       • project sidecars / DB             │
├──────────────────────────────────────────────────────────────────────┤
│  engine            Rust (flutter_rust_bridge v2)                       │
│    • decode: RawDecoder trait (JPEG/PNG/HEIC/LibRaw/rawler)            │
│    • tile provider: ROI decode at any scale                            │
│    • color science: demosaic, WB, tone, LUT bake                       │
│    • export: full-res tiled render + encode                            │
├──────────────────────────────────────────────────────────────────────┤
│  platform          Android / iOS glue                                  │
│    • scoped storage / Photos   • camera capture                        │
│    • share / save              • F-Droid metadata                      │
└──────────────────────────────────────────────────────────────────────┘
```

**Dependency direction is strictly downward.** `app_ui` is *two shells* (ADR
0008) that both read and write a single `EditRecipe` in `edit_core`; neither
owns pixel state, so switching shells mid-edit never changes the image. `app_ui`
never calls `engine` directly for pixels; it talks to `viewport`, which owns the
tile/shader machinery. `engine` knows nothing about widgets. `edit_core` is pure
Dart with no platform imports so it is unit-testable everywhere.

An **optional, separable ML module** (ADR 0010) sits beside `engine`: ONNX
Runtime / ncnn in Rust, producing masks that feed the shader chain. It is
strip-able so the base app stays small and F-Droid-clean.

---

## 3. Data flow

```
 open image file
      │
      ▼
 [engine] probe metadata ──► raw dims, orientation, CFA, embedded preview ──┐
      │                                                                      │
      ▼                                                                      │
 [engine] build 1–2 MP proxy (fast, linear) ──► proxy texture ──► histogram │
      │                                                                      │
      ▼                                                                      │
 [viewport] visible-rect query ──► compute needed tiles @ current zoom ──┐  │
      │                                                                  │  │
      ▼                                                                  │  │
 [engine] ROI decode tile (native decoder or RawDecoder) ────────────────┘  │
      │                                                                     │
      ▼                                                                     │
 [viewport] upload tile texture ──► fragment-shader chain ──► on-screen     │
      │                                 (recipe uniforms)                   │
      │                                                                     │
      ▼                                                                     │
 user scrubs a slider ──► edit_core mutates recipe ──► set uniforms ──► redraw
      │
      ▼
 user taps Export
      │
      ▼
 [engine] full-res tiled render: for each output tile ─► decode ROI ─► CPU/GPU
          color bake ─► stitch ─► encode (JPEG/PNG/DNG) ─► save
```

Key property: **the preview path and the export path share one recipe and one
color definition**, but not one render target. Preview renders the *viewport* at
screen resolution; export renders the *full image* at native resolution, tile by
tile, in the background.

---

## 4. UI layer

### 4.1 Visual system — Material 3
- `ColorScheme.fromSeed` as the baseline, overridden by `dynamic_color` on
  Android S+ (wallpaper palette). iOS has no system dynamic color, so it keeps the
  seed.
- Tool panels are `Card(elevation: 0)` in `colorScheme.surfaceContainer` /
  `surfaceContainerHigh`, with pill-shaped `Slider`s — the Image Toolbox density
  language adapted to Flutter.
- A single `ThemeData` factory consumes the scheme; no widget hard-codes colors.

### 4.2 The gesture FSM (the Snapseed magic)
Snapseed has no visible sliders while editing. The core interaction is a
direct-manipulation state machine that must not fight the viewport's pan/zoom.

States:

```
IDLE
 └─ touch-down outside tool chrome ──► SCANNING
        SCANNING (pre-slop)
          ├─ release before slop ──► TAP (tap-to-reset current tool)
          └─ moved past kTouchSlop
                ├─ dominant axis vertical   ──► CYCLING   (pick next/prev tool)
                └─ dominant axis horizontal  ──► SCRUBBING (change value)
        CYCLING   (finger down) ── shows transient tool-name chip; release ──► IDLE
        SCRUBBING (finger down) ── live value + delta chip;        release ──► IDLE
```

Rules:
- **Axis lock after slop**: once the dominant axis is chosen it is fixed for the
  gesture; the viewport does not pan during a scrub.
- **Value sensitivity** is a function of screen width (full swipe ≈ full range),
  boosted by the tool's precision setting.
- **Reset**: double-tap (or tap in `TAP`) resets the active tool to neutral.
- The FSM is a **pure Dart class** (`GestureInterpreter`) with no Flutter gesture
  binding, so it is exhaustively unit-testable; the widget layer only forwards
  `onPanStart/Update/End` deltas into it. See ADR 0006.

### 4.3 Reused vs bespoke UI
- **Forked** `pro_image_editor`: bottom toolbar scaffolding, slider widgets,
  editor state plumbing, crop/rotate module. Stripped of sticker/emoji/AI/video.
  (See `FORK-STRATEGY.md`.)
- **Adopted** `extended_image`: gallery grid and the pinch/pan gesture layer.
- **Bespoke**: the tile compositor, the shader chain, the gesture FSM, the
  histogram, and the grading tool set.

---

## 5. Viewport & tile compositor

### 5.1 The problem
Flutter/Impeller rasterizes images through GPU textures whose maximum dimension
is device-dependent — commonly **8192**, up to **16384** px. An image larger than
that is silently **downscaled** by the engine, destroying fidelity. A 200 MP
image (e.g. 16384×12288) cannot exist as one texture anywhere in the pipeline.

### 5.2 The approach
Never materialize the full image as one texture. Decompose into a tile field:

- **Tile size:** 512–1024 px (power-of-two, tunable per device). Smaller tiles =
  lower peak memory, more draw calls. Default 512 on low-end, 1024 on flagships.
- **Tile pyramid (mip-like):** decode tiles at the resolution demanded by the
  current zoom. Zoomed out, sample a handful of downscaled tiles; zoomed in,
  decode full-res tiles for the visible region only.
- **ROI decode:** the engine exposes `decodeTile(rect, targetScale)`. On Android
  this maps to `BitmapRegionDecoder`; on iOS to `CGImageSourceCreateThumbnailAtIndex`
  / `CIImage` cropping; RAW goes through the `RawDecoder` (see §7). No full-image
  decode is ever required to show the viewport. *(Current tree: JPEG and RAW ROI
  both decode-full-then-crop — native ROI decoders and the tile pyramid are the
  remaining P1 work, issue #16.)*
- **Compositing:** the viewport draws each visible tile as a textured quad at its
  world position, then the fragment-shader chain (§6) is applied per tile before
  it hits the screen, so seams are invisible (each tile shares the same UV math
  and the same uniform set).
- **Caches:**
  - *Tile LRU* — decoded/uploaded tiles, budgeted in **bytes** (e.g. 96–192 MB),
    keyed by `(tileIndex, scaleLevel)`.
  - *Proxy cache* — the 1–2 MP proxy (one texture) used for histogram, fit-to-
    screen, and the film strip.
- **Prefetch:** tiles in the pan direction are decoded one ring ahead of the
  visible rect on a background isolate/Rust thread pool.

### 5.3 Geometry
Crop, rotate, flip, and perspective are expressed as a transform applied to the
tile's source rect / UVs, not as pixel operations on a full buffer. This keeps
geometry non-destructive and cheap in preview; export bakes it into the final
raster.

---

## 6. GPU shader pipeline

### 6.1 Mechanism
Flutter fragment shaders: `.frag` files declared under `flutter.shaders`, loaded
via `FragmentProgram.fromAsset`, parameterized with `FragmentShader.setFloat`
(one call per component, in declaration order) and bound textures with
`setImageSampler`. The image is sampled inside the shader; results are drawn into
a `CustomPainter`. `ImageFilter.shader` is available for post-processing but is
**Impeller-only**, so any use is feature-detected with a fallback.

### 6.2 Documented constraints we design around
- No UBOs/SSBOs; `sampler2D` is the only sampler type; no unsigned ints or bools;
  no additional varying inputs.
- The portability-safe coordinate function is `FlutterFragCoord()`, not
  `gl_FragCoord`.
- On the OpenGL ES backend the y-axis is inverted — shaders must un-flip UVs when
  sampling engine-provided textures.
- Shader compilation can stall on first use; programs are precached at app start
  and shader instances are reused across frames.

### 6.3 The chain
Adjustments are modeled as an ordered chain of color ops evaluated in a single
(or few) fragment shader pass(es). Ordering is fixed and documented (see §8).
To keep within uniform limits and cost:

- Scalar ops (exposure, contrast, saturation, temperature, tint, highlights,
  shadows, whites, blacks, clarity, vibrance) are folded into one "grade" shader
  with a packed uniform block.
- Curves and HSL/split-toning are pre-baked into small **1D/2D LUT textures** on
  the CPU (Dart/Rust) and sampled in the shader, so arbitrary user curves cost
  one texture fetch.
- Detail ops (sharpen, noise reduction) and geometry (crop/rotate) are separate
  passes.

### 6.4 Preview vs export
Preview uses the same op definitions but may use lower-precision LUTs and skip
expensive detail ops while a finger is down (progressive refinement on release).
Export runs the same math at full precision on the CPU/Rust side (and/or GPU
offscreen) tiled, guaranteeing preview/export consistency.

---

## 7. Engine (Rust) & the FFI boundary

### 7.1 Why Rust
- Memory-safe ROI decode and tiling over huge buffers.
- Cheap parallelism (`rayon`) and SIMD for demosaic/color.
- Mature image crates with strong benchmarks (e.g. `zune-jpeg` decode,
  `fast_image_resize`, `jpeg-encoder`).
- `flutter_rust_bridge v2` generates the Dart bindings, supports async Rust and
  zero-copy big arrays, and builds via `cargokit` in the Flutter build.

### 7.2 The `RawDecoder` trait
RAW engine choice is deferred (ADR 0005). The boundary is fixed now so either
implementation drops in:

```rust
pub trait ImageSource {
    fn metadata(&self) -> ImageMetadata;           // dims, orientation, CFA, WB
    fn proxy(&self, max_edge: u32) -> Result<ProxyImage>;
    fn decode_roi(&self, rect: Rect, scale: ScaleLevel) -> Result<Tile>;
    fn export(&self, recipe: &Recipe, sink: &mut ExportSink) -> Result<()>;
}
```

Implementations:
- `PlatformJpegSource` / `PlatformHeicSource` — native decoders for ROI speed.
  *(Still the decode-full-then-crop fallback in the tree; native
  `BitmapRegionDecoder`/`CGImageSource` ROI is pending — see
  [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) and issue #16.)*
- `RawSource` — backed by either **LibRaw** (via a Rust binding) or a
  **pure-Rust** decoder. **Decision (ADR 0005): rawler-first** — the pure-Rust
  `rawler` crate is the default (`raw::decode`/`metadata`/`color`/`lens`); LibRaw
  stays optional behind `--features raw-libraw` and would require dynamic linking
  for LGPL compliance.

### 7.3 Threading
- Decode runs off the UI thread (Rust thread pool / async).
- Tiles are delivered to the UI isolate as immutable buffers; upload to GPU
  happens on the raster thread.
- Export is a cancellable background job with progress streamed to the UI.

---

## 8. Color science

- **Working space:** linear light for all math; sRGB/Display-P3 output.
- **Precision:** 16-bit float intermediates where available; 8-bit only at the
  final encode.
 - **Op order (fixed):**
   1. Decode → linear
   2. Lens corrections (distortion, vignette, CA)
   3. Camera white balance (RAW) / as-shot (JPEG)
   4. Camera-profile matrices — DNG `ColorMatrix`, temperature-interpolated
   5. Camera profile CLUT — DCP `HueSatMap` / `LookTable` (Adobe-standard parity)
   6. Exposure
   7. Tone (highlights/shadows, whites/blacks, contrast, curve)
   8. Color (temperature/tint, vibrance/saturation, HSL)
   9. Split-tone / colour grading
   10. Detail (clarity, texture, sharpen, dehaze, noise reduction) — spatial
   11. **User HALD / 3D LUT — applied last among edits**
   12. **Film emulation physics** — halation, bloom, dust flecks, scratches (baked in CPU preview base)
   13. **Shader Lab** — custom presets + 3 user params + optional custom GLSL
   14. Geometry (crop, rotate, flip, perspective) — warped live on the GPU, baked
       into the final `Matrix4` resample at export
   15. Output transform (color space, gamma) → encode
- Op order is versioned inside the recipe so future reordering does not silently
  change existing edits.

> **Ordering rules.** (a) Profile `HueSatMap` (5) runs **after** the camera
> matrices and **before** the Basic sliders, mirroring Lightroom's profile →
> Basic order. (b) A user-imported 3D/HALD LUT (11) runs **last among edits**,
> after every parametric slider, so it behaves like a finishing look. (c) Spatial
> detail filters (10) run with overlap padding so tiled export bands blend
> seamlessly (see §5, §9).

---

## 9. Memory budget

Target peak working set ≤ ~300 MB on a 6 GB device; ≤ ~180 MB on a 4 GB device.

| Consumer | Budget | Notes |
|----------|--------|-------|
| Proxy texture (1–2 MP) | 8–16 MB | single, always resident |
| Tile LRU (decoded + GPU) | 96–192 MB | tunable by device tier |
| Shader/LUT textures | < 8 MB | small, shared |
| Undo snapshot of recipe | KB | recipes are tiny JSON |
| Rust decode scratch | bounded by tile size × parallelism | capped by thread count |
| Export | streams tile→encode→free | never holds full output |

Device tiering (RAM + GPU texture limit) is probed at first run and drives tile
size, cache budget, and thread count. Flutter's own `ImageCache.maxByteSize` must
be raised/side-stepped deliberately because a single full-res decode can exceed
its default ceiling and thrash.

---

## 10. Storage model

- **Project sidecar:** a versioned JSON `EditRecipe` (ops, params, geometry,
  color-space, schema version, source content hash). Portable and diffable.
- **Library DB:** SQLite (Drift, consistent with the org's Flutter stack) indexes
  projects, sidecars, presets, and histories. No source pixels are copied without
  explicit user intent.
- **Presets:** serialized recipes (`.aperturex-preset.json`), shareable.
- **Undo history:** in-memory command log that can be serialized for crash
  recovery.

---

## 11. Platform integration

- **Import:** Android Storage Access Framework / Photo Picker; iOS Photos +
  document picker. Read-only handles preferred; copy on demand.
- **Camera capture:** optional in v1; native camera to a temp file, then the
  normal import path.
- **Export/share:** write to Photos (scoped) or share sheet via `share_plus`.
- **Orientation/metadata:** EXIF read on import; EXIF/IPTC carried to export
  (subject to user choice).

---

## 12. Testing strategy

- **Unit (pure Dart):** gesture FSM (exhaustive state-transition tables), recipe
  (serialize/deserialize/version-migrate), undo/redo, LUT baking.
- **Rust:** `cargo test` for decode ROI correctness, tile-edge seam math, color
  op math against golden vectors.
- **Golden/widget:** tool panels, histogram, viewport at fixed zoom/tile grid.
- **Preset fidelity (ADR 0009):** golden-image tolerance tests — import a
  `.xmp`/LUT, apply to a reference image, compare to an Adobe-exported reference
  within a documented delta-E / per-channel tolerance.
- **Integration:** open → edit → export on a corpus of images including a
  >100 MP synthetic image; assert no OOM and pixel-consistent preview vs export
  within tolerance.
- **Device matrix:** at least one low-tier Android device for the memory budget.

---

## 13. CI/CD & distribution

Baseline follows the org's `nook` conventions:
- `flutter pub get` → `dart run build_runner build` → format check → `flutter analyze`
  → `flutter test` → Rust `cargo test`/`clippy`.
- Per-ABI Android release builds; F-Droid metadata and version-code scheme as in
  ADR 0004.
- iOS unsigned CI build; TestFlight later.

---

## 14. Proposed repository layout

```
adobe/                              (repo root; product name "ApertureX")
  README.md
  THIRD_PARTY.md                    incl. ML-model license ledger (ADR 0010)
  LICENSE                           GPL-3.0
  docs/
    ARCHITECTURE.md  ROADMAP.md  IMPLEMENTATION_PLAN.md  RISKS.md  FORK-STRATEGY.md  PARITY.md
    adr/0001..0010
  app/                              Flutter application
    lib/
      core/                         theme, DI, platform abstractions
      features/                     gallery, editor, export, settings
      edit/                         recipe model (superset), undo, presets
      ui/                           dual shells: lightroom/ + snapseed/
      presets/                      .xmp/.lrtemplate/.cube import + reports
      masking/                      adjustment layers, brush/gradient/range
      ml/                           optional AI module bindings (ADR 0010)
      viewport/                     tile compositor, shader chain, caches
      gesture/                      GestureInterpreter FSM
      engine/                       generated FFI bindings + Dart wrappers
    shaders/                        *.frag
    rust/                           cargo crate (flutter_rust_bridge)
      src/api/  src/decode/  src/tile/  src/color/  src/export/
      src/ml/                       optional ONNX/ncnn module (ADR 0010)
  packages/
    pro_image_editor_fork/          vendored/stripped fork
  test/  integration_test/
```

*(Exact layout may adjust in P0; the layer boundaries above are the contract.)*

---

## 15. Dual UI shells (ADR 0008)

The engine and recipe are UI-agnostic; two *shells* render/edit them:

- **Lightroom shell (default).** Panel-based. Categories: Light, Color, Effects,
  Detail, Optics, Geometry, Masking, Presets. Fine-grain Material 3 sliders with
  **tap-to-type numeric entry**, a **live histogram** with highlight/shadow
  clipping warnings, **before/after**, a filmstrip, **history/snapshots**, and
  **copy/paste/sync** of settings across images.
- **Snapseed shell.** The existing `GestureInterpreter` FSM (ADR 0006): vertical
  swipe cycles tools, horizontal swipe scrubs, tap resets. Each Snapseed tool is
  a named *mapping* onto the recipe schema (e.g. Tune Image →
  exposure/contrast/saturation/shadows/warmth).

**Invariant:** neither shell owns pixel or edit state. Both read and write the
single `EditRecipe`. Switching shells (Settings toggle or first-run choice)
mid-edit changes nothing about the image — it only re-renders the same recipe
through a different widget tree. The shell choice is app settings, never recipe
data.

The two shells may reach different breadth over time (tracked in `PARITY.md`);
the recipe schema must nonetheless be complete enough that a parameter exists
*before* either shell exposes it.

## 16. Recipe schema — the Lightroom-aligned superset

The `EditRecipe` is versioned JSON and a **superset** aligned to Lightroom's
parameter model (ADR 0008), so a Snapseed tool is always a *mapping onto* it,
never the schema's definition. Groups:

- **Light:** exposure, contrast, highlights, shadows, whites, blacks.
- **Color:** white balance (temp/tint), vibrance, saturation, HSL/color-mix
  (per-hue hue/sat/lum), color grading (shadow/mid/highlight).
- **Tone:** RGB tone curve + per-channel curves (represented as monotone
  splines; baked to 1D LUTs for the shader).
- **Effects:** texture, clarity, dehaze, vignette, grain.
- **Detail:** sharpening (radius/detail/masking), noise reduction (lum/chroma).
- **Optics:** lens profile, distortion, vignette, CA correction.
- **Geometry:** crop, rotate, skew, perspective (non-destructive transforms).
- **Masking:** a list of adjustment layers, each = mask (brush/linear/radial/
  range/AI) + a sub-recipe of the above params.
- **Film:** halation, bloom, dust flecks, scratches (photochemical emulation).
- **Lab:** shader presets + 3 user parameters + optional custom GLSL code.

The schema is **versioned**; op order is pinned (ARCHITECTURE §8) so future
reordering does not silently change existing edits. Recipes are tiny (KB), which
is why undo snapshots and QR sharing are cheap.

## 17. Preset & LUT import (ADR 0009)

- **Open LUTs (full):** `.cube` (1D/3D), HALD CLUT PNG, `.3dl` → parsed and
  baked into a **3D LUT texture** sampled in the shader.
- **Lightroom `.xmp` / `.lrtemplate` (best-effort):** parsed from the documented
  `crs:` settings namespace and mapped to the recipe schema. Every import emits a
  **compatibility report** (per setting: applied / approximated / unsupported)
  surfaced to the user. Embedded look/profile LUTs are extracted where present.
- **Fidelity is measured, not promised:** golden-image tolerance tests compare an
  imported preset applied to a reference image against an Adobe-exported
  reference within a documented delta-E / per-channel tolerance (§12). Adobe's
  exact rendering is proprietary and **not guaranteed**.
- **Snapseed Looks:** no import (no portable format). We ship an open
  **ApertureX Look** = the recipe JSON, shareable as a file or **QR code** (open
  standard, documented in-repo).

## 18. Masking & adjustment layers (P2.5)

Lightroom's "local adjustments" and Snapseed's "stack" are the same model:
**adjustment layers**, each a mask plus a sub-recipe.

- **Mask kinds:** brush, linear gradient, radial gradient, range
  (luminance/color), and (optionally, ADR 0010) AI masks (subject/sky/
  background).
- **Rendering:** a masked layer routes its sub-recipe through a per-mask uniform
  set; the mask itself is a coverage texture (or analytic gradient) blended in
  the shader, so only masked pixels receive the adjustment. Layers compose in
  order.
- **Non-destructive:** masks are vector/parametric where possible (gradients,
  radii) and stored in the recipe; only brush masks add per-stroke data (still
  KB-scale). Nothing bakes into source pixels until export.

## 19. On-device ML module (optional, ADR 0010)

A **separable** module for intelligent masking; the base app never depends on it.

- **Runtime:** ONNX Runtime Mobile (MIT) via Rust, with optional NNAPI/CoreML
  providers; ncnn (BSD-3) remains an alternative. No ML Kit, no Play Services.
  OpenCV (Apache-2.0) for classical CV (horizon/edge/saliency).
- **First bundled model:** Apache-2.0 U²-NetP (4.5 MB ONNX), compiled only into
  the optional `ai` build; the default app links neither ORT nor weights.
- **Models** (each license verified before adoption; prefer Apache-2.0/MIT):
  MobileSAM/SAM2-small (tap-select), U²-Net-style salient (auto subject), sky
  segmentation (or a classical fallback), MODNet-class matting (hair), Depth
  Anything V2 small (depth for blur), YuNet (face, MIT). RMBG avoided
  (non-commercial).
- **Output → shader:** a model produces a mask array; the mask becomes a coverage
  texture that gates a sub-recipe's edits (or a bokeh blur kernel) exactly like a
  manual mask (§18). Same rendering path, different mask source.
- **Packaging & licensing:** small models bundled in a strippable module (F-Droid
  builds from source; size matters). Prefer bundling over runtime download (a
  non-free download can trigger anti-feature flags). Every model gets a
  `THIRD_PARTY.md` ledger row (license, source, training-data note) — a hard gate
  before shipping.
- **Sequencing:** classical **auto-straighten** (Hough) ships in P2 geometry,
  before any learned auto-frame.

## 20. ApertureX Neural Forge (Declarative ONNX BYOM Architecture)

ApertureX is the first mobile photo editor allowing users to bring their own AI models
without requiring app store updates or recompilation.

```
Community Hub / GitHub Link (.zip or manifest.json)
                     │
                     ▼
             Manifest Parser (Dart)
       ┌─────────────┴─────────────┐
       ▼                           ▼
Dynamic Parameter UI        Tensor Pipeline (Rust/ONNX)
(Native Sliders in App)      (Zero-Copy Input RGBA -> Model)
                                   │
                                   ▼
                          Alpha Mask / Depth Map
                                   │
                                   ▼
                     Impeller GPU Fragment Shader
```

- **Manifest Contract (`manifest.json`):** Defines `plugin_id`, `input_shape` `[N, C, H, W]`,
  `task` (`depthEstimation`, `subjectSegmentation`, `portraitHair`, `superResolution`),
  and a list of dynamic `controls` (`id`, `label`, `min`, `max`, `default`).
- **Dynamic Flutter UI:** Generates standard `ParameterControl` sliders dynamically on the
  fly, mapping slider changes directly to plugin parameters.
- **Store & F-Droid Compliance:** Neither Android nor iOS permit dynamic executable code
  (`.so`, `.dylib`). ONNX weight graphs are strictly non-executable mathematical weight tensors
  evaluated inside the pre-compiled, sandboxed on-device runner.

## 21. Optics & Hardware Telemetry (Lensfun + Zero-Allocation EXIF)

- **Rust EXIF Engine (`app/rust/src/exif.rs`):** Zero-allocation TIFF IFD scanner supporting
  big-endian and little-endian headers. Extracts camera make, model, lens model, shutter speed
  rational, aperture f-number, ISO rating, focal length (plus 35mm equivalent), and GPS coordinates.
- **Lens Database (`app/lib/features/lens/lens_database.dart`):** Curated database of Sony,
  Canon, Nikon, Fujifilm, Sigma, Apple, and Google Pixel optics.
- **Optics Rectification:** Identifies camera/lens pairs to recommend polynomial distortion
  coefficients (`k1`, `k2`), chromatic aberration correction, and corner vignetting compensation.
- **Image Info Inspector (`ImageInfoSheet`):** Displays hardware shooting parameters, exposure
  stat pill badges, GPS coordinates, and recipe session history with 1-tap clipboard copying.

## 22. Lossless DNG CFA Passthrough & XMP Export (#79)

When editing camera RAW files, standard editors destructively demosaic and compress to 8-bit JPEG.
ApertureX provides pure archival DNG export:

```
RAW File (CR2, ARW, NEF, RW2, DNG)
                │
                ▼
        Rawler CFA Reader
    (Extracts Raw Bayer CFA Matrix)
                │
                ▼
      XMP Sidecar Generator
    (Encodes Non-Destructive Recipe)
                │
                ▼
        DngWriter Pipeline
   (Writes Lossless DNG with Tag 0x02BC)
```

- **Lossless CFA Bayer Stream:** Passes raw sensor samples directly into `rawler::dng::writer::DngWriter`
  without demosaicing or lossy compression.
- **Injected XMP Tag `0x02BC`:** Injects the full non-destructive editing recipe into TIFF tag
  `0x02BC` (ApplicationNotes), allowing desktop darkroom software (Adobe Lightroom, Photoshop,
  Darktable) to read and respect the edits.

## 23. In-App OTA Updater Subsystem ("Metrolist-style")

For open-source distribution outside Google Play (e.g., GitHub Releases, direct APKs):

- **Release Discovery:** Queries GitHub API `/repos/prit-007/ApertureX/releases/latest`
  using standard library `HttpClient`.
- **Semantic Version Engine (`AppUpdater.isNewerVersion`):** Compares remote semver against
  current version (`v0.2.0`), stripping metadata.
- **Download & Progress:** Streams the release `.apk` directly into the app's cache directory,
  emitting real-time byte counts and download percentages.
- **Release Notes Modal (`UpdateDialog`):** Presents markdown changelog and initiates installation.

## 24. ApertureX Academy & Interactive Guide Engine

- **Catalog Registry (`ToolGuideRegistry`):** Exhaustive model registry documenting all
  editing categories (`light`, `color`, `effects`, `detail`, `optics`, `geometry`, `masking`, `workflow`).
- **Interactive UI (`AppGuideScreen`):** Search bar with live query filtering across titles, summaries,
  and pro tips; category chips; expandable masterclass cards with "Best Used For" highlights and pro tips.
- **Contextual Help:** Every tool header and sheet provides direct 1-tap access to the specific
  tool's masterclass.

