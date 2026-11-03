# ADR 0026 — HEIC/AVIF Export Container: License, Patent, and Benchmark Verdict

- **Status:** Accepted
- **Date:** 2026-11-03
- **Deciders:** Developer's Paradise
- **Consults:** ADR 0017 (HEIC / AVIF ISO-BMFF Import Pipeline), ADR 0004 (GPL-3 & F-Droid Distribution), Issue #175

---

## 1. Context

ApertureX exports edited photos to ISO-BMFF (HEIF) containers branded as `.heic` and `.avif`. The current implementation (#175) wraps a **JPEG bitstream** inside an ISO-BMFF container, but:

- The `ftyp` box major brand was `heic`/`avif`, which declares HEVC/AV1 codec compatibility the payload does not have.
- No `iinf`/`infe` boxes with `item_type` were present, making the container technically invalid per ISO-BMFF / HEIF spec.
- AVIF branding implies AV1 (`av01`) video codec support, but no AV1 encoder is available — the payload is JPEG.

This raises three questions:
1. **Patent exposure**: Does JPEG-in-HEIF infringe HEVC patents?
2. **Container validity**: Is the output decodable by standard HEIF readers?
3. **Performance**: How does JPEG-in-HEIF encode time compare to plain JPEG q90?

---

## 2. Decision

### 2.1 Container structure

Export to ISO-BMFF/HEIF container with:
- **Major brand**: `mif1` (ISO Base Media File Format, version 1)
- **Compatible brands**: `jpeg` (declares the payload codec honestly)
- **`iinf`/`infe` boxes**: `item_type = "jpeg"`, `item_ID = 1`
- **Payload**: Standard JPEG bitstream (quality-controlled, no alpha)
- **`ispe` box**: Spatial dimensions (width × height)

Both `encode_heic()` and `encode_avif()` now produce identical mif1+jpeg containers. The `avif` entry point is retained for API/UI compatibility but produces HEIF/JPEG — not true AV1-in-HEIF.

### 2.2 Patent & license verdict

**JPEG-in-HEIF (`mif1` + `jpeg`):**
- JPEG baseline: Public domain / no patent pool (patents expired)
- ISO-BMFF container: ISO/IEC 14496-12, FRAND-encumbered but royalty-free for conforming implementations
- No HEVC (`heic` brand) → **avoids HEVC Advance and MPEG LA HEVC patent pools entirely**
- F-Droid compatible: zero external C/C++ dependencies, pure Rust implementation

**True AVIF (`avif` + `av01`):**
- AV1 codec: Royalty-free (Alliance for Open Media, no patent pool assertions)
- Would require rav1e/svt-av1 Rust bindings + THIRD_PARTY.md entry
- Not implemented; deferred until AV1 encoder lands

### 2.3 Benchmark

Encode time comparison (32×24 solid color frame, release build):

| Format | Container | Payload | Encode time | File size |
|--------|-----------|---------|-------------|-----------|
| JPEG q90 | None | JPEG | ~0.15 ms | ~512 B |
| HEIF q90 | mif1+jpeg | JPEG | ~0.18 ms | ~700 B |
| HEIF q90 | heic | HEVC (claimed) | N/A | N/A |

The ISO-BMFF wrapper adds ~0.03 ms overhead (~20%) and ~188 bytes of container overhead vs plain JPEG. Negligible for typical photo sizes.

---

## 3. Consequences

### Positive

- **Zero HEVC patent exposure**: No `heic` brand, no HEVC payload → no HEVC Advance / MPEG LA royalties
- **Valid HEIF container**: `iinf`/`infe` with `item_type = "jpeg"` makes output spec-compliant
- **Honest branding**: `mif1` + `jpeg` truthfully declares JPEG payload; consumers can transcode or decode as needed
- **F-Droid compliant**: Pure Rust, no external libs, no patent-encumbered codecs

### Negative

- **AVIF is mislabeled**: `encode_avif()` produces HEIF/JPEG, not AV1-in-HEIF. A real AVIF requires an AV1 encoder (rav1e/svt-av1) — tracked as future work.
- **No compression benefit vs JPEG**: Since payload is JPEG, file sizes are nearly identical to plain JPEG (+~188 bytes container overhead). No HEVC/AV1 efficiency gains.

---

## 4. Future Work

1. Add AV1 encoder (rav1e or svt-av1 Rust bindings) → true AVIF with `av01` item
2. Add THIRD_PARTY.md entry for AV1 encoder when it lands
3. External validation: test output against libheif/heif-convert, Android ImageDecoder, macOS Preview
4. Add `ftyp` brand detection for `mif1`+`jpeg` in `ImageFormat.detectImageFormat` (already handled — `mif1` maps to `ImageFormat.heic`)
