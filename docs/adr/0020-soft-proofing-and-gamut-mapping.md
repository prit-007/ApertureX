# ADR 0020 — Soft Proofing & Gamut Mapping Engine

- **Status:** Accepted
- **Date:** 2026-10-30
- **Deciders:** Developer's Paradise
- **Consults:** ADR 0001 (Flutter UI & Rust Engine), ADR 0003 (Non-destructive Recipe Model), Issue #12

---

## 1. Context

Professional photographers preparing images for print or wide-gamut web delivery require accurate color fidelity across differing display media:
- Standard screens typically display sRGB, while mobile and desktop pro displays support Apple Display P3.
- Offset and digital commercial printing presses (e.g. US Web Coated SWOP CMYK) have substantially smaller gamuts in vibrant saturated colors (especially cyans, blues, and bright greens).
- Without soft proofing, photos that appear vibrant and well-exposed on an OLED display can suffer severe clipping, banding, or muddy tonal shifts when printed or viewed on lower-gamut monitors.

## 2. Decision

Implement an on-canvas Soft Proofing and Gamut Warning engine (`app/lib/viewport/soft_proofing.dart`):

1. **Target Profile Models (`ProofProfile`)**:
   - `sRGB`: Standard web and consumer mobile target.
   - `displayP3`: Apple / modern wide-gamut display target.
   - `adobeRgb`: High-end photography wide-gamut standard.
   - `cmykSwop`: Commercial offset printing press simulation (US Web Coated SWOP v2).

2. **Gamut Mapping Intents (`ProofIntent`)**:
   - `perceptual`: Compresses out-of-gamut colors smoothly while preserving proportional relationships across color zones.
   - `relativeColorimetric`: Preserves in-gamut chromaticities exactly and clips out-of-gamut coordinates to the nearest gamut border.

3. **Paper & Ink Simulation**:
   - Simulates physical print media limits by shifting the maximum white point and lifting black point DMax to mimic paper reflection characteristics.

4. **Real-Time Out-of-Gamut Warning Overlay**:
   - A GPU shader false-color mask (high-visibility bright cyan default `#00E5FF`) that highlights pixels exceeding the target color space boundary.
   - Fully toggleable in real time without altering the underlying non-destructive `EditRecipe`.

## 3. Consequences

### Positive
- **Studio Print Parity**: Matches capabilities found in Adobe Lightroom and Capture One Pro.
- **Predictable Output**: Photographers can tune saturation, highlights, and tone curves while watching gamut clipping resolve in real time.
- **Non-Destructive**: Proofing state is purely a viewport visualization layer; exported files retain full wide-gamut data unless specifically exported for a constrained color space.

### Negative
- Evaluating complex gamut conversions adds minor per-frame shader arithmetic when active, though performance remains above 60 FPS on supported GPUs.
