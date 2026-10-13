# ADR 0010 — On-device ML stack and model licensing (F-Droid-compliant)

- **Status:** Accepted
- **Date:** 2026-10-13
- **Deciders:** Developer's Paradise

## Context

We want Lightroom-class intelligent masking: select subject / sky / background,
portrait-grade lens blur, auto-frame, and face detection. F-Droid's constraints
make the obvious toolchains unusable:

- **No Google ML Kit**, no Play Services, no proprietary SDKs.
- **No non-free model weights.** Weights are distributed artifacts and their
  license must be redistributable under F-Droid's terms — a permissive *code*
  license is not enough if the *weights* are non-commercial.

So every ML component must be (a) open-source runtime, (b) open-weights model,
(c) on-device, (d) redistributable.

## Decision

1. **Runtime:** **ONNX Runtime Mobile** (MIT) or **ncnn** (BSD-3), driven from
   the Rust engine. No Google ML Kit. OpenCV (Apache-2.0) is available for
   classical CV (horizon/edge/saliency) where a model is overkill.
2. **Models** (each license verified *before* adoption; prefer Apache-2.0/MIT;
   recollection only — must be confirmed per model):
   - **Tap-to-select / promptable masks:** MobileSAM or SAM 2 (small).
   - **Auto subject (salient object):** a U²-Net-style salient-object model.
   - **Sky mask:** a small sky-segmentation model, **or** a classical
     color/gradient heuristic as a guaranteed-free fallback.
   - **Portrait / hair edges:** a MODNet-class matting model.
   - **Depth for lens blur:** Depth Anything V2 **small** (larger variants are
     non-commercial — do not adopt).
   - **Face detection:** YuNet (MIT) or BlazeFace.
   - **Explicitly avoided:** RMBG (believed non-commercial).
3. **Packaging:** AI features live in an **optional, separable module** with small
   bundled models. F-Droid builds from source and APK size matters, so the module
   must be strip-able. **Prefer bundling models over runtime download** — a
   download from a non-free service can trigger F-Droid anti-feature flags.
4. **Licensing ledger:** every model gets a row in `THIRD_PARTY.md` recording
   license, source URL, and a training-data/provenance note. No model ships
   without a verified row.
5. **Auto-straighten ships before learned auto-frame.** Classical horizon
   detection (Hough) is free, deterministic, and low-risk; learned auto-framing
   waits for the model module.

## Consequences

**Positive**
- Intelligent masking without telemetry, tracking, or proprietary binaries — the
  core FOSS promise holds.
- Optional module means the base app stays small and F-Droid-clean; AI is an
  enhancement, not a dependency.

**Negative / risks**
- **License verification is manual and ongoing.** Model licensing is a minefield
  (code vs weights vs training data); a wrong adoption is a compliance bug, not
  just a code bug. The weights-license check is a hard gate.
- ONNX/ncnn + model integration in Rust is real native work; debugging tensors
  across the FFI is slow.
- Bundled models inflate APK size; the size budget must be enforced per model.
- Model quality on low-tier NPUs is uncertain until measured on-device.

**Follow-ups**
- P3.5 (optional module): subject/sky/background masks, lens blur, face detect,
  auto-frame — gated on verified per-model licenses.
- Auto-straighten (classical) can land earlier, in the geometry work.
- Seed `THIRD_PARTY.md` with the ML-models table (stub added; rows filled as each
  model is adopted).
