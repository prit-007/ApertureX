# Tessera — Architecture

> Status: design. This document specifies the system that phases P0–P6 will
> build. It is intentionally implementation-guiding, not an implementation.

---

## 1. Goals and non-goals

### Goals
- **Non-destructive** editing: the source pixels are never modified; edits are a
  replayable recipe.
- **Fluid**: adjustment previews track the finger at display refresh rate.
- **Touch-first**: an invisible, gesture-driven interaction model (Snapseed-like)
  layered over a Material 3 (Material You) visual system.
- **Scale**: open and edit images from 48 MP to 200 MP without OOM or visible
  texture distortion.
- **RAW-capable**: a pluggable decode engine that can grow from camera JPEG to
  full RAW (DNG/CR2/NEF/ARW) without an architectural rewrite.
- **FOSS**: GPL-3.0, reproducible, F-Droid-shippable, no telemetry, no accounts.

### Non-goals (v1)
- Web and desktop targets.
- Cloud sync, collaboration, accounts.
- Server-side processing.
- Generative/AI editing features.
- Video editing.

---

## 2. Layer model

```
┌──────────────────────────────────────────────────────────────────────┐
│  app_ui            Flutter + Material 3                               │
│    • gesture FSM            • tool trays / bottom sheets              │
│    • film strip / gallery   • histogram, before/after                 │
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

**Dependency direction is strictly downward.** `app_ui` never calls `engine`
directly for pixels; it talks to `viewport`, which owns the tile/shader
machinery. `engine` knows nothing about widgets. `edit_core` is pure Dart with no
platform imports so it is unit-testable everywhere.

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
  decode is ever required to show the viewport.
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
- `RawSource` — backed by either **LibRaw** (via a Rust binding) or a
  **pure-Rust** decoder. Selected by feature flag at build time; the decision is
  recorded in ADR 0005 when phase P3 runs.

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
  1. Decode → linear, apply camera WB (RAW) / as-shot (JPEG)
  2. Lens corrections (distortion, vignette, CA) — RAW, via lensfun-class profiles
  3. Exposure
  4. Tone (white/black point, highlights/shadows, contrast)
  5. Color (temperature/tint, vibrance/saturation, HSL, curves, split-tone)
  6. Detail (clarity, sharpen, noise reduction) — export-fidelity
  7. Geometry (crop, rotate, flip, perspective)
  8. Output transform (color space, gamma) → encode
- The order is versioned inside the recipe so future reordering does not silently
  change existing edits.

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
- **Presets:** serialized recipes (`.tessera-preset.json`), shareable.
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
adobe/                              (repo root; product name "Tessera")
  README.md
  THIRD_PARTY.md
  LICENSE                           GPL-3.0
  docs/
    ARCHITECTURE.md  ROADMAP.md  RISKS.md  FORK-STRATEGY.md
    adr/0001..0007
  app/                              Flutter application
    lib/
      core/                         theme, DI, platform abstractions
      features/                     gallery, editor, export, settings
      edit/                         recipe model, undo, presets
      viewport/                     tile compositor, shader chain, caches
      gesture/                      GestureInterpreter FSM
      engine/                       generated FFI bindings + Dart wrappers
    shaders/                        *.frag
    rust/                           cargo crate (flutter_rust_bridge)
      src/api/  src/decode/  src/tile/  src/color/  src/export/
  packages/
    pro_image_editor_fork/          vendored/stripped fork
  test/  integration_test/
```

*(Exact layout may adjust in P0; the layer boundaries above are the contract.)*
