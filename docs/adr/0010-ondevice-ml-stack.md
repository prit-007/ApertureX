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

## Implementation status (2026-10-19)

**Shipped**
- `Segmenter` trait + tensor pre/post-processing pipeline in
  `app/rust/src/ml.rs` (#87). The trait and deterministic fallback always
  build; ORT, native ML libraries, and weights only build with `ai`.
- **ONNX Runtime Mobile backend** (`app/rust/src/ort_runtime.rs`, #87): the
  `ort` crate (MIT OR Apache-2.0) sits behind the optional `ai` feature. It
  loads models from memory, runs a single f32 input, and passes a host
  Add-one ONNX fixture. `ai-nnapi` and `ai-coreml` gate the Android/iOS
  execution providers.
- **U²-NetP subject segmenter** (`app/rust/src/u2netp.rs`, #87): the
  Apache-2.0 4.5 MB `u2netp.onnx` weights are compiled into the `ai` build,
  run through ORT, and post-processed into a target-sized alpha mask.
  `ai` builds prefer U²-NetP and fall back to the saliency segmenter if
  inference is unavailable; default builds use saliency only.
- **One-tap subject/background masks** with inverted-background selection
  (#83/#89), now model-backed when `ai` is enabled.
- **Classical Select Sky** (horizon + chromaticity, no model) as the free,
  deterministic sky path (#88).
- **Intent-based AI masks + smart paste** (`AiMaskResolver`, FNV-1a result
  cache across photos, #96) and an `aiConsentProvider` with a Settings toggle
  / first-use dialog for F-Droid compliance.
- **Classical depth-aware lens blur** (bokeh shape, focal plane/range, specular
  boost) baked into the CPU preview base + export pipeline
  (`app/rust/src/blur.rs`, `app/rust/src/preview.rs`), shipping in P2 as a
  classical (non-ML) feature — **no model weights required**.
- `THIRD_PARTY.md` ML table with the U²-NetP row (Apache-2.0 code *and*
  weights, #87).

**Pending**
- U²-NetP ships only in the optional `ai` build. Validate mask quality on real
  photos and measure APK growth, cold-start, and NNAPI/CoreML latency before
  any platform enables `ai` by default.
- ORT mobile packaging: replace the development `download-binaries` path with
  vendored native libraries for release/`ai` builds.
- ML-based depth for lens blur (Depth Anything V2 small), YuNet face detection,
  learned auto-frame — each gated on verified per-model licenses.

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
- P3.5 (optional module): subject/sky/background masks **✅ shipped
  (classical/saliency paths, #83/#87/#88/#89/#96)**; **classical lens blur
  shipped (P2)**; ML-based depth (Depth Anything V2), face detect, auto-frame
  remain — each gated on verified per-model licenses.
- Auto-straighten (classical) can land earlier, in the geometry work.
- Seed `THIRD_PARTY.md` with the ML-models table (stub added; **U²-NetP row
  adopted via #87** — the rest fill as each model is adopted).
