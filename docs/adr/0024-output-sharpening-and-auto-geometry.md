# ADR 0024 — Output Sharpening, Auto Upright Perspective, Edge-Aware Brush, and Depth Range Masking

- **Status:** Accepted
- **Date:** 2026-10-31
- **Deciders:** Developer's Paradise
- **Consults:** ADR 0001 (Flutter UI & Rust Engine), ADR 0003 (Non-destructive Recipe Model), ADR 0013 (Mask Group Algebra)

---

## 1. Context

Professional photo workflows distinguish strictly between input capture sharpening (de-blurring lens softness during capture) and output medium sharpening (optimizing spatial high-frequency response specifically for destination display media):
- **Output Sharpening**: Screen display (sub-pixel unsharp mask, halo suppression), matte paper (broad high-boost kernel compensating for high ink bleed/absorption), glossy photo paper (fine micro-contrast high-boost kernel matching high ink holdout), and web compression (compact thresholded edge crisping).
- **Auto Upright / Perspective Geometry**: Architectural and interior photography requires automatic detection and rectification of vertical perspective convergence caused by upward camera tilt, together with horizon leveling.
- **Auto Mask (Edge-Aware Brush)**: Local adjustment brushing must respect high-contrast color and luminance object boundaries automatically without requiring tedious manual masking.
- **Depth Range Mask**: Utilizing computed monocular depth maps to isolate foreground subjects, mid-ground planes, or backgrounds across a depth threshold with smooth feathering.
- **Auto Tone Refinement**: Histogram-based tonal balancing with skin-tone protection, highlight clipping recovery, and perceptual vibrance adjustment.

## 2. Decision

### 1. Output Sharpening Pipeline (`rust/src/spatial.rs` & `app/lib/`)
- Introduced `OutputSharpenMedia` enum in Rust: `Screen` (0), `PrintMatte` (1), `PrintGlossy` (2), `Web` (3).
- Implemented `apply_output_sharpen`:
  - **Screen**: 3×3 unsharp mask kernel with gentle high-frequency enhancement.
  - **PrintMatte**: 5×5 high-boost kernel with broader radius ($R=2$) and increased gain ($\times 1.4$) to counter paper ink absorption.
  - **PrintGlossy**: 3×3 crisp edge kernel with tight micro-contrast radius and threshold masking.
  - **Web**: Sub-pixel unsharp kernel with adaptive thresholding to retain edge sharpness post-resampling.
- Extended `SpatialParams`, `ExportSpec`, `PreviewBaseSpec`, `EditRecipe`, and `Parameter` enum (`outputSharpen`, `outputSharpenMedia`).

### 2. Upright Auto Geometry (`rust/src/geometry.rs`, `api/geometry.rs`, `geometry_controls.dart`)
- Implemented `detect_vertical_convergence`:
  - Computes Sobel vertical and horizontal gradient fields.
  - Filters high-gradient edge points with predominantly vertical orientation ($|\nabla_y| > 1.2 |\nabla_x|$).
  - Divides image into left and right vertical halves, measuring convergence tilt angles via linear regression.
  - Computes keystone vertical perspective factor: $\frac{\theta_{left} - \theta_{right}}{2}$.
  - Computes global straighten angle: $\frac{\theta_{left} + \theta_{right}}{2}$.
- Exposed `AxEngine.detectUpright(rgba, width, height)` returning `UprightResult`.
- Added tactile "Upright" button in `GeometryControls` that applies auto-straighten and vertical perspective.

### 3. Edge-Aware Auto Mask (`rust/src/mask.rs`, `app/lib/edit/adjustment_layer.dart`)
- Added `MASK_AUTO_BRUSH` (kind 8) to mask pipeline.
- During coverage rasterization, computes Euclidean distance in RGB color space between pixel color and seed stroke color.
- Modulates brush stroke coverage by edge weight: $1.0 - \text{smoothstep}(\text{tolerance} \times 0.4, \text{tolerance}, \Delta_{color})$, cleanly halting the mask brush at contrasting edges.

### 4. Depth Range Masking (`rust/src/mask.rs`, `app/lib/edit/adjustment_layer.dart`)
- Added `MASK_DEPTH_RANGE` (kind 9) to mask pipeline.
- Generates mask coverage based on depth plane values: $d_{min} \le z \le d_{max}$, modulated by smoothstep edge feathering $\pm \text{feather}$.
- Added `AdjustmentLayer.depthRange(...)` constructor and interactive depth range controls in `MaskControls`.

### 5. Skin-Aware Auto Tone Refinement (`rust/src/api/color.rs`)
- Enhanced `auto_tone` in Rust engine:
  - Detects skin-tone pixels using golden/red-dominant chromatic priors ($R > G > B$ with skin hue $10^\circ \le H \le 45^\circ$).
  - When skin pixels are detected, shifts target luminance towards 0.52 and limits temperature correction to prevent unnatural pallor or jaundice.
  - Implements continuous highlight recovery derived from $p_{99}$ and $p_{99.9}$ histogram percentiles.
  - Implements continuous shadow lift derived from $p_1$ and $p_{0.1}$ percentiles.
  - Calculates complementary vibrance adjustment.

## 3. Consequences

### Positive
- **Output-Aware Sharpening**: Professional photographers can optimize exports for specific physical print media and web publishing directly within the non-destructive recipe pipeline.
- **Architectural Perspective Correction**: Upright perspective geometry eliminates keystoning in a single tap.
- **Precision Local Masking**: Edge-aware brush strokes and depth slicing provide Lightroom-grade masking speed.
- **100% Offline & F-Droid Clean**: Zero cloud or proprietary dependencies; pure Rust math and SIMD acceleration.

### Negative
- Print matte 5×5 spatial convolution has a slightly larger kernel footprint, which is managed via existing ROI halo margins in the tile pipeline.
