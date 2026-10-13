# ADR 0002 — Tile-based viewport

- **Status:** Accepted
- **Date:** 2026-10-13
- **Deciders:** Developer's Paradise

## Context

Mobile cameras produce 48–200 MP images. Flutter/Impeller rasterizes images via
GPU textures whose maximum dimension is device-dependent — commonly 8192 px, up to
16384 px. Images larger than that limit are **silently downscaled** by the engine,
destroying fidelity. Separately, Flutter's `ImageCache` defaults to ~100 MB, and a
single full-resolution decode of a 200 MP image is hundreds of MB — enough to
trigger the OS memory killer.

Alternatives considered:
- **Decode full-res, let engine downscale:** simple, but visibly wrong on large
  images and memory-hostile.
- **Always downscale to a safe proxy:** memory-safe but throws away the
  resolution users paid for when they zoom in.
- **Tile field with ROI decode:** more complex, but bounded memory at full
  fidelity in the viewed region.

## Decision

Adopt a **tile-based viewport**:
- Decompose the image into a field of 512–1024 px tiles (device-tier dependent).
- Never materialize the full image as one texture.
- Decode **only the region of interest** at the resolution the current zoom
  requires, via a native ROI decoder (Android `BitmapRegionDecoder`, iOS
  `CGImageSource`/`CIImage`).
- Keep a **byte-budgeted LRU** of decoded/uploaded tiles; prefetch one ring ahead
  in the pan direction.
- Render the identical fragment-shader chain per tile with shared UV math so
  seams are invisible.
- Export streams full-res tiles through a background job, freeing each after
  encode.

## Consequences

**Positive**
- Bounded peak memory independent of source megapixels.
- Full fidelity in the viewed region at any zoom.
- Export is memory-flat (tile → encode → free).

**Negative / risks**
- More moving parts: tile indexing, seam math, cache eviction, prefetch heuristics.
- Requires correct, fast ROI decode from the engine (P1 dependency).
- Devices with a low max texture size force smaller tiles / more draw calls.

**Metrics to uphold**
- Peak working set within the ARCHITECTURE §9 budget on a low-tier device.
- 60 fps while panning a 100 MP image.
- Zero engine-downscale blowouts when opening a 200 MP image.
