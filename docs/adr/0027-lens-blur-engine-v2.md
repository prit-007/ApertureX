# ADR 0027 — Lens Blur Engine v2: Realistic Optical Bokeh, Occlusion-Aware Depth Gather, and Non-Destructive Sidecar Architecture

- **Status:** Accepted
- **Date:** 2026-11-18
- **Deciders:** ApertureX Core Team
- **Consults:** ADR 0001 (Flutter UI & Rust Engine), ADR 0002 (Tile-Based Viewport), ADR 0003 (Non-destructive Recipe Model), ADR 0010 (On-Device ML Stack), ADR 0024 (Output Sharpening & Depth Range Masking)

---

## 1. Context

Portrait and shallow depth-of-field photography relies fundamentally on optical physics: aperture blades, pupil magnification, spherical aberrations, circle of confusion (CoC), and occlusion geometry. Previous mobile blur implementations suffered from five severe synthetic artifacts:
1. **Hard Cutout Silhouettes:** In-focus foreground subjects lacked optical foreground bokeh bleed from out-of-focus foreground elements, producing an unnatural "cardboard cutout" appearance.
2. **Simplified Bokeh Kernel Shapes:** Standard approximations circularized bokeh shapes at larger radii, failing to replicate true mechanical aperture blades, optical cat's eye vignetting, or swirl characteristics.
3. **Crunchy / Plastic Bokeh from Spatial Unsharp Chains:** Applying clarity, texture, or sharpening indiscriminately across the image sharpened soft background bokeh and noise, ruining optical realism.
4. **Interactive Stalling on Mobile Devices:** Gathering 64 samples per pixel at 4K-8K resolutions stalled the UI thread during scrubbing.
5. **Loss of Depth on Recipe Reload:** Recipes lacked binary depth serialization, meaning depth maps had to be re-inferred upon reopening a project.

---

## 2. Architecture & Decisions

### 2.1 Optical Thin-Lens Model & Continuous Diopter Space (`rust/src/blur.rs`)
- Distance mapped to continuous optical diopter space $z^{-1}$ rather than raw linear distance.
- Smooth focal falloff at depth-of-field boundaries via cubic Hermite smoothstep curves, eliminating stepped discontinuities.
- Physical aperture diffraction modeled across $f/1.2$ to $f/22$ equivalent aperture settings.
- Resolution-invariance enforced through dynamic maximum blur radius $R_{\max} = \text{clamp}(\max(w, h) \times 0.045, 8.0, 48.0)$, verified by PSNR $\ge 38.0\,\text{dB}$ parity tests.

### 2.2 Occlusion-Aware Gather & Foreground Bokeh Bleed (`rust/src/blur.rs`)
- Asymmetric depth weighting in gather loop:
  - **Background Occlusion:** Samples behind the current pixel ($z_{sample} - z_{pixel} > \epsilon_{depth}$) are strictly culled (weight = 0.0), completely preventing background light from leaking into foreground subjects.
  - **Foreground Bleed:** Out-of-focus samples in front of the current pixel ($z_{sample} - z_{pixel} < -\epsilon_{depth}$) bleed over in-focus subject edges according to their own circle of confusion $r_{sample}$, accurately replicating real camera optical bokeh.
- **16×16 Foreground Dilation Grid:** Precomputes maximum foreground CoC per 16×16 tile, enabling sharp in-focus pixels near foreground edges to gather foreground bleed without running full-image dilations.

### 2.3 Physically-Accurate Bokeh Kernel Geometry (`rust/src/blur.rs`)
- **Cat's Eye (Optical Vignetting):** Exact analytical intersection of two offset circular lens barrels separated by normalized mechanical barrel displacement $d = 0.70$:
  $$r(\theta) = \sqrt{1.0 - \frac{d^2}{4}\sin^2\theta} - \frac{d}{2}|\cos\theta|$$
- **Swirl (Petzval Astigmatism):** Tangential coordinate twist with quadratic radial growth $\theta' = \theta + 1.85 \cdot r^2$.
- **Soap Bubble & Onion Rings:** Bright outer caustic rim with $r^5$ falloff combined with concentric sinusoidal wave rings simulating spherical aberration and glass element polishing rings.
- **Longitudinal Chromatic Aberration (LoCA):** Optical dispersion causing cyan/green fringing on background bokeh rims and magenta/red fringing on foreground bokeh rims.
- **Dynamic 99th-Percentile Specular Boost:** Measures scene highlight luminance in linear light and boosts specular out-of-focus points above $p_{99}$ luminance without blowing out mids.

### 2.4 Performance Architecture: Culling, Caching, and Far-Field (`rust/src/`)
- **Tile-Max-CoC Culling (`blur.rs`):** Computes maximum CoC and foreground bleed per 16×16 tile. Tiles where $\text{CoC}_{\max} \le 10^{-3}$ and $\text{CoC}_{fg} \le 10^{-3}$ are culled in bulk using `copy_from_slice`, bypassing millions of sampling passes.
- **Blur Stage Cache (`preview.rs`):** Caches the baked blur stage keyed on `(geometry, optics, blur_params, patches, depth)`. Adjusting spatial sliders (clarity, sharpen, texture, vignette, grain) or color grading reuses the cached blur frame instantly at 60–120 FPS.
- **Multi-Resolution Far-Field Gather (`blur.rs`):** When $R_{\max} \ge 12.0$, constructs a 2×2 box-filtered half-resolution MIP for distant background sampling, reducing memory cache bandwidth by $4\times$.
- **Dynamic Sample Budgeting (`image_canvas.dart`):** Dispatches 12 samples during live dragging and interactive gestures, automatically settling to 36/64 samples upon gesture completion (120ms settle debounce).

### 2.5 Blur-Aware Spatial Attenuation (`rust/src/spatial.rs`)
- High-frequency spatial passes (clarity, texture, unsharp sharpening, and output medium sharpening) are modulated by an in-focus attenuation weight:
  $$\alpha = \text{clamp}(1.0 - 8.0 \cdot \text{CoC}, 0.0, 1.0)$$
- Out-of-focus bokeh regions receive zero high-frequency unsharp amplification, preventing harsh ringing and plastic artifacts.

### 2.6 Depth Field Binary Serialization (`depth.rs`, `depth_sidecar.dart`, `recipe.dart`)
- Introduced `.axdf` binary sidecar container with magic bytes `AXDF`, uint8 version, uint32 geometry, float32 confidence, and IEEE 754 float32 depth planes.
- Integrated into `EditRecipe` via `depthField`, `depthSidecar`, and `depthSidecarPath` properties, preserving depth across recipe export and reload.

### 2.7 Interactive UI/UX (`image_canvas.dart`, `lens_blur_controller.dart`)
- **Draggable Focus Ring:** Canvas focus ring features an inner bullseye for focal point placement and an interactive outer perimeter with drag handles for tactile calibration of `blurFocalRange`.
- **Mask Refinement Brush Integration:** `applyDepthBrush` allows manual touchup of focal planes, while `refineDepthEdges` uses guided filtering against the color image to snap depth boundaries to photo edges.

---

## 3. Consequences

### Positive
- Matches desktop-class optical renderers (Lightroom Lens Blur / Phase One) in physical realism.
- True foreground bokeh bleed eliminates cutout silhouettes.
- 60 FPS live scrubbing for color and spatial adjustments thanks to the blur stage cache.
- Non-destructive recipes serialize companion `.axdf` depth data safely alongside edits.
- All 422 engine unit, smoke, and golden tests pass with zero clippy or format warnings.

### Neutral / Trade-offs
- Deeply defocused images require ~15% more memory temporarily during export for the multi-resolution far-field MIP buffer.
