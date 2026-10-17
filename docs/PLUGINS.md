# ApertureX Neural Forge — Community AI Plugins

ApertureX is the world’s first mobile photo editor to feature a **Bring-Your-Own-Model (BYOM)** declarative plugin architecture.

This document describes the architectural design, safety compliance, and community development roadmap for on-device AI plugins.

---

## 1. Architectural Philosophy

Standard mobile editors (Lightroom, Snapseed, VSCO) are locked gardens. If an AI researcher creates a breakthrough model today (such as Depth Anything V2 or RMBG 1.4), photographers normally wait years for corporations to adopt it.

ApertureX decouples the **Model Weights** and **UI Controls** from the compiled application binary:

1. **Declarative Manifest (`manifest.json`):** Tells Flutter what sliders and buttons to render.
2. **ONNX Weights (`model.onnx`):** Non-executable matrix graph evaluated inside the native Rust runner.
3. **Hardware Acceleration:** Evaluates tensor operations on mobile GPUs/NPUs offline without network round-trips.

---

## 2. App Store & F-Droid Compliance

Both Google Play and Apple App Store policies strictly prohibit downloading and executing dynamic machine code (`.so`, `.dll`, `.dylib`, or Python bytecode) after app installation.

**Why ONNX Plugins Are 100% Compliant:**
- ONNX files are **not executable code**. They are static arrays of numerical floating-point tensor weights.
- The actual execution is handled exclusively by the sandboxed, pre-compiled Rust engine inside the app binary.
- This is mathematically identical to importing a 3D LUT `.cube` file or a RAW camera profile.

---

## 3. High-Demand Community Plugins

Based on state-of-the-art computational photography models on GitHub and HuggingFace:

### A. Restoration & Detail
* **Super-Resolution (Real-ESRGAN Compact):** 2x–4x high-frequency detail synthesis for heavy crops.
* **Focus Fixer (CodeFormer / GFPGAN):** Face landmark deblurring and eye sharpness restoration for portraits with missed focus.
* **Neural Denoise (NAFNet):** Low-light noise suppression preserving natural emulsion and surface grain.

### B. Computational Lighting & Depth
* **Magic Bokeh (Depth Anything V2):** Dense monocular depth map estimation simulating optical prime lenses (f/1.2–f/2.8) with customizable blade geometries.
* **Relighting (IC-Light):** Virtual direction-aware lighting to relight flat portrait shots.

### C. Masking & Erasing
* **Object Removal (LaMa - Large Mask Inpainting):** High-resolution clean inpainting for removing unwanted objects and photobombers completely offline.
* **Semantic Selectors:** Fine-grained segmentation plugins (Select Skin, Select Foliage, Select Architecture).

---

## 4. Developer Quickstart

For full instructions and ready-to-run export scripts, see [`plugins_template/`](../plugins_template/):
- `manifest.json`: Example manifest with parameter sliders.
- `export_to_onnx.py`: PyTorch-to-ONNX export and validation script.
- `package_plugin.py`: Manifest validator and `.zip` packager with SHA-256 integrity checksums.
