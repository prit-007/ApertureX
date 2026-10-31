# ApertureX — Feature Parity Matrix

Living document. Tracks each Snapseed / Lightroom feature, its support status,
and the phase that delivers it. This is the honest ledger — "parity" is a
multi-year goal shipped in tiers, not a milestone. Update a row's status only
when the feature is actually demoable with tests.

**Status:** ✅ shipped · 🚧 planned (phase) · ⬜ later · ❌ not planned · ⚠️ constrained
**Phases:** see [`ROADMAP.md`](ROADMAP.md). P2.5 = masking, P3.5 = optional AI module.
Issue numbers in parentheses are the GitHub issue carrying the remaining work;
the consolidated, file-by-file plan is [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md).

---

## Core editing (both shells)

| Feature | Snapseed analogue | Lightroom analogue | Status | Phase |
|---|---|---|---|---|
| Exposure / contrast / saturation | Tune Image | Basic panel | ✅ | P0 |
| Highlights / shadows | Tune Image | Basic panel | ✅ | P2 |
| Whites / blacks | Tune Image | Basic panel | ✅ (#59) | P2 |
| White balance (temp/tint) | White Balance | Basic panel | ✅ | P2 |
| Vibrance | Tune Image | Basic panel | ✅ (Adobe vibrance + skintone protection in #59) | P2 |
| Full basic panel (numeric, tap-to-type) | — | Basic panel | ✅ (#59) | P2 |
| RGB tone curve (+ per-channel) | Curves | Tone Curve | ✅ | P2 |
| HSL / color mix | Selective | HSL/Color | ✅ | P2 |
| Color grading (shadow/mid/high) | — | Color Grading | ✅ (split-tone) | P2 |
| Texture / clarity / dehaze | Details/Structure | Effects panel | ✅ (halo-free guided refine in #57, dark-channel dehaze in #58) | P2 |
| Film emulation: halation, bloom, dust flecks, scratches | — | Effects / Film panel | ✅ (photochemical physics in Rust preview base + grade.frag) | P2 |
| Shader Lab: custom presets + 3 user params + custom GLSL | — | Effects / Lab panel | ✅ (`shaderLabPreset`, `shaderParam1..3`, `customGlslCode`) | P2 |
| Sharpening (radius/detail/masking) | Details | Detail panel | ✅ | P2 |
| Output sharpening (Screen, Matte, Glossy, Web) | — | Export / Output Sharpening | ✅ (`outputSharpen`, `outputSharpenMedia` — ADR 0024) | P6 |
| Noise reduction | Details | Detail panel | ✅ | P2 |
| Auto-tone refinement (skin-aware, clipping recovery) | Auto | Basic panel | ✅ (`auto_tone` percentile histogram + skin prior) | P6 |
| Crop / rotate / skew / perspective | Crop | Geometry | ✅ | P2 |
| Upright / Auto Geometry (vertical convergence) | — | Geometry / Upright | ✅ (`AxEngine.detectUpright`, Sobel convergence — ADR 0024) | P6 |
| Retouch: healing brush & clone stamp (patches) | Healing / Clone | Spot Healing | ✅ (`retouchPatches`, applied in CPU preview base) | P2 |

## Geometry & framing

| Feature | Source | Status | Phase |
|---|---|---|---|
| Crop (free / aspect / straighten) | Both | ✅ | P2 |
| Auto-straighten (classical horizon) | Lightroom | ✅ (`AxEngine.detectStraightenAngle`) | P2 |
| Auto-frame (face + saliency) | — | ✅ (YuNet face priority + Rule of Thirds auto-crop) | P3.5 |
| Expand (generative fill) | Snapseed Expand | ❌ (non-goal; generative) | — |
| Lens profile corrections (distortion + vignetting) | Lightroom Optics | ✅ (`profileCorrections`, `profileDistortion`, `profileVignetting`) | P2 |
| Chromatic aberration defringe (purple/green) | Lightroom Optics | ✅ (`removeChromaticAberration`, defringe fields) | P2 |

## Depth & optical effects

| Feature | Source | Status | Phase |
|---|---|---|---|
| Depth-aware lens blur (bokeh, focal plane, focal range) | Lightroom Lens Blur | ✅ (monocular depth + optical blade bokeh, baked in CPU base) | P2 |
| Bokeh shapes / boost | Lens blur tools | ✅ (`blurBokehShape`, `blurBokehBoost`) | P2 |

## Masking & local adjustments

| Feature | Lightroom analogue | Status | Phase |
|---|---|---|---|
| Linear gradient mask | Linear Gradient | ✅ | P2.5 |
| Radial gradient mask | Radial Gradient | ✅ | P2.5 |
| Brush mask | Brush | ✅ (stylus pressure, palm rejection, inverted-stylus eraser) | P2.5 |
| Auto Mask (Edge-aware brush) | Auto Mask | ✅ (`MASK_AUTO_BRUSH` Euclidean color contrast gating — ADR 0024) | P6 |
| Range mask (luminance/color) | Range Mask | ✅ (Zone-system luminance + HSV color-range) | P2.5/P6 |
| Depth range mask | Depth Range | ✅ (`MASK_DEPTH_RANGE` monocular depth plane slicing — ADR 0024) | P6 |
| Adjustment layers over masks | Masks + local adj | ✅ (analytic masks) | P2.5 |
| Snapseed stack == adjustment layers | Stack | 🚧 | P2.5 |

## Intelligent / AI masking (optional module — ADR 0010)

| Feature | Source | Status | Phase |
|---|---|---|---|
| Select subject | Lightroom | ✅ (on-device saliency + guided-filter re-matting) | P3.5 |
| Select sky | Lightroom | ✅ (classical blue-luminance gradient segmentation) | P3.5 |
| Select background | Lightroom | ✅ (inverted subject segmentation mask) | P3.5 |
| Portrait / hair matting | Lightroom | ✅ (BiSeNet portrait & guided-filter edge refinement) | P3.5 |
| Lens / background blur | Lightroom | ✅ (monocular depth estimation + optical blade bokeh) | P3.5 |
| BYOM Neural Plugins | Unique to ApertureX | ✅ (declarative ONNX manifests via GitHub/HuggingFace links) | P3.5 |
| Face detection | — | ✅ (YuNet ONNX model, 5 landmarks, portrait auto-mask) | P3.5 |
| Head pose / generative | Snapseed | ❌ (non-goal) | — |

## Presets, LUTs & sharing (ADR 0009)

| Feature | Status | Phase |
|---|---|---|
| `.cube` (1D/3D) / HALD / `.3dl` LUT import | ✅ | P2 |
| Lightroom `.xmp` import (+ compatibility report) | ✅ | P2 |
| Lightroom `.lrtemplate` import | ✅ (#62) | P2 |
| Golden-image tolerance tests for preset fidelity | ✅ (7 automated golden fixture tests in CI #60) | P2 |
| ApertureX Look (recipe JSON) save/apply | ✅ | P2 |
| Look share via QR (open standard) | ✅ (`docs/LOOK_QR_STANDARD.md`, `apx://look/v1`, creator cards, zxing2 decoder) | P2 |
| Pre-installed FOSS film simulation core | ✅ (Pat David profiles: Portra 160/400, Fuji Pro 400H, HP5, CineStill 800T, Tri-X) | P2 |
| Community Preset Hub | ✅ (GitHub-backed plugin repository, category filtering, one-tap preview & save) | P2 |
| Snapseed Look import | ❌ (no portable format) | — |

## Workflow & Library (Lightroom shell)

| Feature | Status | Phase |
|---|---|---|
| Live histogram + clipping warnings | ✅ (interactive HUD histogram + highlight/shadow indicators) | P2 |
| Before/after | ✅ (hold-to-compare + draggable split curtain wiper) | P2 |
| Soft proofing & gamut warnings | ✅ (sRGB, Display P3, Adobe RGB, CMYK SWOP + false color) | P2 |
| History / snapshots | ✅ (unlimited undo/redo stack + history tree) | P2 |
| Copy / paste / sync settings | ✅ (selective recipe clipboard + multi-photo batch sync edits) | P2 |
| Filmstrip / library (SQLite Drift) | ✅ (Google Photos-style grid, date grouping, album ellipses, keywords, color labels) | P2 |
| Smart Collections | ✅ (dynamic multi-rule query engine: rating, flag, color, keywords, edits — ADR 0025) | P6 |
| Perceptual Duplicate Detection | ✅ (64-bit dHash + Hamming distance burst clustering — ADR 0025) | P6 |
| Quality Culling (Sharpness & Closed-Eye) | ✅ (Laplacian variance + YuNet facial eye openness score — ADR 0025) | P6 |
| Folder Watching / Auto-Import | ✅ (debounced `Directory.watch` background ingestion — ADR 0025) | P6 |
| Desktop MenuBar | ✅ (native macOS/Linux/Windows PlatformMenuBar with shortcuts) | P5 |
| Internationalization (i18n) | ✅ (flutter_localizations + intl for EN, ES, DE, FR, JA, ZH) | P5 |
| Lensfun Optics & EXIF Inspector | ✅ (hardware camera/lens profile database, distortion correction, EXIF sheet #85) | P2 |
| In-App OTA Updater | ✅ ("Metrolist-style" GitHub Releases live updater with download progress) | P5 |
| Interactive Academy & Tool Guide | ✅ (searchable masterclasses, pro tips, category chips, tool guide sheet) | P5 |
| Print Studio & Contact Sheets | ✅ (A4/A3/Letter/Legal/Photo paper, PDF 1.4 generator, margins, contact sheet grids — ADR 0021) | P6 |
| Video Color Studio & Multi-Clip Editing | ✅ (Multi-clip sequencing, Razor split, ripple delete, duplicate, transitions, audio gain/fade, 16:9/9:16/1:1/4:5/21:9 framing, text overlays, 3D LUT grading, .CUBE export — ADR 0022) | P6 |
| Studio Tethered Shooting | ✅ (USB/PTP live telemetry, remote shutter release, auto-import, auto-recipe — ADR 0023) | P6 |
| Soft-Proofing & Gamut Mapping | ✅ (sRGB, Display P3, Adobe RGB, CMYK SWOP, paper & ink simulation, gamut overlay — ADR 0020) | P6 |

## Import / export / formats

| Feature | Status | Phase |
|---|---|---|
| JPEG import | ✅ (zune-jpeg SIMD direct decode into resident store via `preview_open_jpeg`) | P1 |
| PNG photo import | ✅ (standard PNG decode via `AxEngine.decodeImageRgba`) | P6 |
| HEIC / AVIF import | ✅ (ISO-BMFF spatial parsing & embedded payload extraction in `decodeHeicRgba`) | P5 |
| RAW import (DNG/CR2/NEF/ARW/RAF) | ✅ (rawler: decode/demosaic/matrices/orientation/ROI + lens/EXIF #66, DCP #64, highlights #65; all 5 golden fixtures green) | P3 |
| JPEG full-res export | ✅ (basic, P1); banded full-res path #68 | P4 |
| C2PA Content Credentials + FOSS watermark + museum frame branding on export | ✅ (progressive disclosure export UI) | P4 |
| PNG full-res export | ✅ (standard 8-bit RGBA PNG encoder in Rust `export.rs` via DEFLATE) | P4 |
| DNG export (original CFA + XMP, lossless) | ✅ (rawler DngWriter lossless CFA passthrough + XMP ApplicationNotes; editor "Export DNG" option gated to RAW sources; round-trip test green — #79) | P6 |
| TIFF / re-rendered 16-bit DNG export | ✅ (uncompressed 16-bit-per-channel TIFF with full edit bake-in) | P6 |
| Background / batch export | ✅ (dedicated `BackgroundExportWorker` Isolate with wake-lock persistence & notifications) | P4 |

---

### How to use this matrix
- A feature moves to ✅ only when it is demoable **and** covered by tests
  (unit/golden/integration as appropriate).
- "Parity" is tiered: ship a coherent Lightroom-default v1 (core + basic + LUT +
  a couple of masks) before claiming breadth. Track breadth here, not in marketing.
- Any row marked ❌ is a deliberate non-goal; re-opening it requires an ADR.
