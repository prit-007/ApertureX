# Changelog

All notable changes to ApertureX are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and this project adheres to
[Semantic Versioning](https://semver.org/).

## [0.2.3] - 2026-10-19

Pro-level polish release: film/slate UI refinements, bottom sheet redesign,
auto-tone, AI depth blur for subjects, and compare-view fixes.

### Added
- **Ruby Peeks toggle** (default OFF) in Effects & Detail tab — auto-peek on
  detail sliders only activates when enabled, so you see the normal image
  during scrub.
- **Auto-Tone button** in the Light & Color tab — analyzes JPEG histogram and
  applies balanced exposure/contrast/highlights/shadows/whites/blacks in one
  tap.
- **ML Background Blur** — subject stays sharp while background blurs (separate
  from the DSLR optical blur). Power curve for creamier DSLR bokeh at 100%
  (max radius 24→60).
- **Compare view fix** — the "before" side now samples the unedited source
  texture instead of the graded base image; Wiper curtain and blend compare
  both show the true original.
- **Film tab sliders now work** — halation, bloom, dust, and scratches are
  wired through `SpatialSpec` → `PreviewBaseSpec` → Rust engine (were
  hardcoded to neutral).
- **Image Information sheet fixed** — loads original EXIF-bearing JPEG bytes
  via `loadImage()` instead of preview bytes (which had EXIF stripped).

### Fixed
- **Compare view** — Wiper curtain and blend now show the unedited "before"
  side instead of the graded image on both sides.
- **Film tab sliders** — halation/bloom/dust/scratches had no effect on the
  preview; now wired end-to-end through the render pipeline.
- **Ruby Peeks** — default OFF; opt-in via toggle in Effects & Detail tab.
- **Image Information** — was showing stale/null/fake EXIF data; now reads
  original image bytes for real metadata.
- **100% lens blur** — now produces a creamy DSLR blur (power curve, max
  radius 24→60).
- **Auto-mix on open** — verified code path; HSL defaults are all zeros.
- **Bottom-heavy test flakiness** — `bottom_heavy_test.dart` now drives
  `compareHoldProvider` directly instead of relying on gesture timing.

### Changed
- **Bottom sheet layout** — accordion-style `ExpansionTile` groups for
  Light/Color/Effects/Detail panels, tight 12×2 px spacing, compact chips;
  prominent Auto Tone button in the Light & Color panel header.
- **Prominent model-selection UI** — Active Model per Task router in the
  Plugins tab so you can choose which model runs for each AI task when
  multiple are installed.

### Technical
- `flutter_rust_bridge_codegen regenerate` after adding `blurBackgroundBlur`
  to `PreviewBaseSpec`/`ExportSpec`.
- All tests green: 1045 Dart + 320 Rust, `flutter analyze`/clippy/fmt clean.

## [0.2.2] - 2026-10-18

Film simulation, lens corrections, depth-aware lens blur, retouch preview, and
SIMD color math.

### Added
- **Film emulation physics**: halation, bloom, dust flecks, and scratches baked
  into the CPU preview base (`filmHalation`, `filmBloom`, `filmDust`,
  `filmScratches`) with radius/threshold controls; neutral-at-zero defaults.
- **Shader Lab**: selectable film presets (`shaderLabPreset`) plus three
  freeform user parameters (`shaderParam1..3`) and optional custom GLSL code.
- **Lens profile corrections**: distortion and vignetting
  (`profileCorrections`, `profileDistortion`, `profileVignetting`) in preview
  base + export.
- **Depth-aware lens blur**: bokeh shape, focal plane/range, and specular
  highlight boost (`blurAmount`, `blurFocalPoint`, `blurFocalRange`,
  `blurBokehShape`, `blurBokehBoost`).
- **Retouch patches**: healing brush & clone stamp applied in the CPU preview
  base (`retouchPatches`).
- **zune-jpeg SIMD direct decode**: `preview_open_jpeg` decodes JPEG straight
  into the resident store, eliminating the GPU readback stall and FFI copy;
  `preview_get_source_rgba` retrieves the source buffer.
- **NEON color math**: aarch64 `f32x4` SIMD kernels for sRGB↔linear conversion
  on Android.

### Fixed
- Gallery: photos load immediately; album metadata deferred to background.
- Gallery grid/export layout and batch-export determinate progress.
- Rust `blur.rs` / `preview.rs` formatting (rustfmt).

## [0.2.0] - 2026-10-17

Major milestone release: Look QR Open Standard, Pat David film emulation core,
Community Preset Hub, C2PA Content Credentials provenance, interactive Wiper
split curtain compare, Git-style non-linear edit history branching, and Zen
pro controls.

### Added
- **Look QR Open Standard (`apx://look/v1`)**:
  - Open URI protocol with sparse Deflate compression and URL-safe Base64 encoding.
  - Pure-FOSS offline optical QR image decoder (`zxing2`), reading presets from
    screenshots and downloaded photos without camera permissions or Google blobs.
  - Creator Preset Card Generator (1:1 Square & 9:16 Story formats) with
    frosted glass branding, live photo preview, watermark, and QR badge.
  - Direct "Export as Preset Card (QR)" action in editor export options.
- **Pre-Installed Film Simulation Core**:
  - Curated Pat David analog film profiles adding only ~0.04 MB to base APK:
    Kodak Portra 160 & 400, Kodak Ektar 100, Fuji Pro 400H, Fuji Velvia 50,
    Agfa Vista 200, Kodachrome 64, Ilford HP5 Plus, CineStill 800T, and Tri-X 400.
- **Community Preset Hub ("Plugin Store")**:
  - Live storefront browsing open GitHub repository (`devparadise/aperturex-presets`).
  - Category filter chips (`Film`, `Portraits`, `Moody`, `Landscape`), search,
    one-tap apply, and local offline saving.
- **C2PA Content Credentials & Authenticity Provenance**:
  - Offline Ed25519 signing key generation and SHA-256 pixel/recipe hashing.
  - In-app authenticity verification inspector and museum frame watermark.
- **Interactive Wiper Split Curtain Compare (120 FPS)**:
  - Drag-anywhere before/after split line with haptic boundary snaps.
- **Git-Style Non-Linear Edit Branching**:
  - Visual HistoryTreeSheet with commit snapshots, branching, and diff previews.
- **Zen Chrome, Exposure Assist & Precision Jog Dial**:
  - Zebra overexposure clipping stripes, 6 Master Tabs, and 120 FPS haptic Rotary
    Jog Dial with fine vernier gear steps.

## [0.1.0] - 2026-10-16

First public pre-release: a dual-UI (Lightroom panels + Snapseed gestures),
non-destructive, fully offline photo editor.

### Added
- **Launcher icon**: a camera-aperture shutter mark on a dark field, generated
  from committed 1024×1024 masters (`app/icons/`) via `flutter_launcher_icons`
  for every Android density (incl. adaptive + Android 13+ themed monochrome
  layers) and the full iOS app-icon set.
- **Dual shells over one recipe**: Lightroom-style panels and a Snapseed-style
  gesture "Ghost UI"; switching shells never changes the image.
- **Rust engine** (via `flutter_rust_bridge`): color pipeline (exposure,
  contrast, highlights/shadows/whites/blacks, WB, vibrance, saturation,
  split-tone, HSL mixer, tone curves), geometry (rotate/flip/straighten/crop),
  spatial ops (clarity, texture, sharpen, denoise, dehaze, vignette, grain),
  local-adjustment masks, JPEG decode/export, EXIF carry-over, ICC/P3 handling.
- **60fps preview**: proxy-resolution decode, split base/grade bakes, a baked
  65³ LUT sampled by one fragment shader; export grades at full resolution.
- **Crop tool** with aspect presets and rotate/flip.
- **Gallery**: date-grouped (newest first), album switching, multi-select batch
  paste/export, "edited" badges.
- **Non-destructive per-photo recipes**, persisted settings (theme, shell,
  export quality/size), preset import (`.cube`, Lightroom `.xmp`), shareable
  JSON looks, sidecar open.
- **On-device offline activity log** with a first-run guide and export.
- **Permissions**: asks on launch, re-prompts, and falls back to settings.
- Material 3 theming with neutral surfaces and a dynamic accent.

### Notes
- Android-first. iOS builds are not produced by the maintainers (no Xcode in
  CI) but the project targets both.
- RAW, Ultra HDR, and on-device ML are tracked and not in this release.
