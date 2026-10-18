# Golden-Image Tolerance Corpus (Lightroom / Adobe Parity)

## Overview
ApertureX maintains a checked-in golden-image test suite to enforce strict numerical and perceptual color-grading parity against Lightroom and Adobe Standard pipelines.

Without automated tolerance gating, color science regressions (such as subtle gamma drift, S-curve shifts, or gamut clipping) can easily go unnoticed. This corpus runs continuously in CI across both the Rust color engine (`cargo test golden`) and the Flutter edit layer (`flutter test test/color/golden_corpus_test.dart`).

---

## Provenance & Test Fixtures
All golden test images are synthetically generated to guarantee byte-level reproducibility and zero third-party licensing dependencies:
- **Macbeth ColorChecker 24 (CC0 / Public Domain):** 24 standardized color patches covering natural skin tones (dark/light), foliage, blue sky, primary/secondary colors, and a 6-step neutral grayscale sweep (black to white).
- **Edge Step Band:** High-contrast step edge (dark 40 $\leftrightarrow$ light 220) to verify guided-filter edge-aware local contrast and halo-free clarity.
- **Low-Contrast Gradient Band:** Linear density gradient (levels 100..160) to verify dark-channel transmission refinement and dehaze response.

Dimensions: 24×16 pixels (384 pixels, 1.5 KB RGBA), keeping CI fast (<10 ms evaluation) and lightweight.

---

## Tolerance Gates & Metrics
The comparator evaluates differences using standard CIE metric suites:

| Metric | Target Gate | Description |
|---|---|---|
| **Mean $\Delta E_{76}$** | $\le 1.0$ | Average perceptual color error in CIE $L^*a^*b^*$ space across all patches. |
| **Max $\Delta E_{76}$** | $\le 2.0$ | Peak perceptual error on any individual patch (well below human JND threshold). |
| **Mean Absolute Error (MAE)** | $\le 1.0 / 255$ | Average 8-bit channel deviation across all channels. |
| **Max Byte Difference** | $\le 2$ | Maximum per-channel quantization difference (accounting for rounding/LUT trilinear interpolation). |

Any intentional or accidental change that perturbs exposure, tone curves, or color balance by more than ~1 level triggers a CI gate failure with an actionable report identifying the exact failing patch and channel delta.

---

## Fixed Recipe Suite
The golden suite covers the six core Lightroom-aligned operations:
1. **Basic Panel:** Exposure (+0.5 EV), Contrast (+0.20), Whites (+0.15), Blacks (-0.15), Temperature (+0.20), Tint (-0.10), Vibrance (+0.25), Saturation (+0.10).
2. **Tone Curves:** Master S-curve with control points `[(0, 0), (0.25, 0.20), (0.75, 0.85), (1.0, 1.0)]` anchored in linear light.
3. **HSL Mixer:** 8-band HSL deltas targeting specific hues (Red hue +15°, Blue saturation +30%, Green luminance -20%).
4. **Color Wheels / Split-Tone:** 3-way color grading with cool shadow hue (210°), warm highlight hue (40°), midpoint blending (0.50), and balance (0.00).
5. **Clarity:** Guided-filter edge-aware high-frequency boost (+0.30) without edge overshoot or ringing halos.
6. **Dehaze:** Dark-channel prior transmission recovery (+0.25) boosting atmospheric contrast and saturation.

The Rust engine's `preview.rs` unit tests additionally assert that film emulation
(halation/bloom/dust/scratches), lens profile corrections (distortion/vignetting),
depth-aware lens blur, and retouch patches each change the baked base while
neutral specs stay byte-identical — guarding these newer ops against regressions
alongside the golden-image suite.

---

## Running the Golden Tests
Run the test suites locally or in CI:

```bash
# Rust color engine golden tests
cd app/rust
cargo test golden

# Flutter / Dart recipe mapping golden tests
cd app
flutter test test/color/golden_corpus_test.dart
```

---

## Update Workflow (Regenerating References)
When an intentional color science refinement is introduced:
1. Run the test with the update flag:
   ```bash
   UPDATE_GOLDENS=1 cargo test golden
   ```
2. Inspect the git diff carefully using `git diff` to confirm that the changes represent a deliberate improvement rather than an unintended side effect.
3. Commit the updated references along with the corresponding issue number.
