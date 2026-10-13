# ApertureX — Feature Parity Matrix

Living document. Tracks each Snapseed / Lightroom feature, its support status,
and the phase that delivers it. This is the honest ledger — "parity" is a
multi-year goal shipped in tiers, not a milestone. Update a row's status only
when the feature is actually demoable with tests.

**Status:** ✅ shipped · 🚧 planned (phase) · ⬜ later · ❌ not planned · ⚠️ constrained
**Phases:** see [`ROADMAP.md`](ROADMAP.md). P2.5 = masking, P3.5 = optional AI module.

---

## Core editing (both shells)

| Feature | Snapseed analogue | Lightroom analogue | Status | Phase |
|---|---|---|---|---|
| Exposure / contrast / saturation | Tune Image | Basic panel | ✅ (preview) | P0 |
| Highlights / shadows / whites / blacks | Tune Image | Basic panel | 🚧 | P2 |
| White balance (temp/tint) | White Balance | Basic panel | 🚧 | P2 |
| Vibrance | Tune Image | Basic panel | 🚧 | P2 |
| Full basic panel (numeric, tap-to-type) | — | Basic panel | 🚧 | P2 |
| RGB tone curve (+ per-channel) | Curves | Tone Curve | 🚧 | P2 |
| HSL / color mix | Selective | HSL/Color | 🚧 | P2 |
| Color grading (shadow/mid/high) | — | Color Grading | ⬜ | P2/P6 |
| Texture / clarity / dehaze | Details/Structure | Effects panel | 🚧 | P2 |
| Vignette / grain | Vignette / Grain | Effects panel | 🚧 | P2 |
| Sharpening (radius/detail/masking) | Details | Detail panel | 🚧 | P2 |
| Noise reduction | Details | Detail panel | 🚧 | P2 |
| Crop / rotate / skew / perspective | Crop | Geometry | 🚧 | P2 |

## Geometry & framing

| Feature | Source | Status | Phase |
|---|---|---|---|
| Crop (free / aspect / straighten) | Both | 🚧 | P2 |
| Auto-straighten (classical horizon) | Lightroom | 🚧 | P2 |
| Auto-frame (face + saliency) | — | ⬜ (AI) | P3.5 |
| Expand (generative fill) | Snapseed Expand | ❌ (non-goal; generative) | — |

## Masking & local adjustments

| Feature | Lightroom analogue | Status | Phase |
|---|---|---|---|
| Linear gradient mask | Linear Gradient | 🚧 | P2.5 |
| Radial gradient mask | Radial Gradient | 🚧 | P2.5 |
| Brush mask | Brush | 🚧 | P2.5 |
| Range mask (luminance/color) | Range Mask | ⬜ | P2.5/P6 |
| Adjustment layers over masks | Masks + local adj | 🚧 | P2.5 |
| Snapseed stack == adjustment layers | Stack | 🚧 | P2.5 |

## Intelligent / AI masking (optional module — ADR 0010)

| Feature | Source | Status | Phase |
|---|---|---|---|
| Select subject | Lightroom | ⬜ | P3.5 |
| Select sky | Lightroom | ⬜ | P3.5 |
| Select background | Lightroom | ⬜ | P3.5 |
| Portrait / hair matting | Lightroom | ⬜ | P3.5 |
| Lens / background blur | Lightroom | ⬜ | P3.5 |
| Face detection | — | ⬜ | P3.5 |
| Head pose / generative | Snapseed | ❌ (non-goal) | — |

## Presets, LUTs & sharing (ADR 0009)

| Feature | Status | Phase |
|---|---|---|
| `.cube` / HALD / `.3dl` LUT import | 🚧 | P2 |
| Lightroom `.xmp` import (+ compatibility report) | 🚧 | P2 |
| Lightroom `.lrtemplate` import | 🚧 | P2 |
| Golden-image tolerance tests for preset fidelity | 🚧 | P2 |
| ApertureX Look (recipe JSON) save/apply | 🚧 | P2 |
| Look share via QR (open standard) | 🚧 | P2 |
| Snapseed Look import | ❌ (no portable format) | — |

## Workflow (Lightroom shell)

| Feature | Status | Phase |
|---|---|---|
| Live histogram + clipping warnings | 🚧 | P2 |
| Before/after | 🚧 | P2 |
| History / snapshots | 🚧 | P2 |
| Copy / paste / sync settings | 🚧 | P2 |
| Filmstrip / library (SQLite index) | 🚧 | P2 |

## Import / export / formats

| Feature | Status | Phase |
|---|---|---|
| JPEG / PNG import | 🚧 | P1 |
| HEIC import | ⬜ | P5 |
| RAW import (DNG/CR2/NEF/ARW/RAF) | ⬜ | P3 |
| JPEG / PNG full-res export | ⬜ | P4 (basic moved forward) |
| DNG / TIFF 16-bit export | ⬜ | P6 |
| Background / batch export | ⬜ | P4 |

---

### How to use this matrix
- A feature moves to ✅ only when it is demoable **and** covered by tests
  (unit/golden/integration as appropriate).
- "Parity" is tiered: ship a coherent Lightroom-default v1 (core + basic + LUT +
  a couple of masks) before claiming breadth. Track breadth here, not in marketing.
- Any row marked ❌ is a deliberate non-goal; re-opening it requires an ADR.
