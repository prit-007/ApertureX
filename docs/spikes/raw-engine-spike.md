# ADR 0005 RAW engine prototype spike (Phase C)

## Objective
Prototype both candidate decoders against the fixed `ImageSource` boundary (ARCHITECTURE §7.2):
- `rawler` (pure-Rust): decode RAW/DNG in-memory, ROI feasibility, DNG re-encode path.
- `libraw` (C/C++): decode RAW via FFI, ROI feasibility, license/build notes.

## Setup
- Added `rawler = "0.8.0"` and `libraw = "0.1.1"` to `app/rust/Cargo.toml`
- `libraw` compiles against system LibRaw 0.21.2.
- Minimal `raw.rs` test produced a synthetic DNG via `rawler::dng::writer` and verified roundtrip through `rawler::decode`.

## Findings
- **rawler**: in-memory DNG roundtrip works (`RawSource::new_from_slice`); dimensions/full/ROI shim compiles and a small DNG decodes. Pure-Rust, single toolchain (good for F-Droid from-source). Can write DNGs for fixtures. ROI feasible by decoding full then cropping in the spike (matches the existing JPEG ROI approach) or by accessing tiles; direct file ROI depends on format.
- **libraw**: crate links against system LibRaw 0.21.2; API surface in `libraw` 0.1.1 is `Image::open(path)` only (no obvious in-memory open). Linkage/structs compile. System LibRaw gives broad camera support but requires C toolchain and packaging. ROI: LibRaw can operate on subimages in some modes but requires careful integration.

## Comparison (micro-scale, synthetic 8x8 DNG)
| Criterion | rawler | libraw |
|---|---|---|
| Toolchain | Rust only | Rust + C/C++ (system libraw) |
| In-memory decode | Yes (buffer-based) | Limited by 0.1.1 (file-open only); temp files possible |
| ROI feasibility | Easy (decode full + crop or format-specific) | Possible but API-coupled; file-oriented |
| Build reproducibility (F-Droid) | High (vendored/crates.io) | Needs packaged libraw; cross-compile friction |
| Binary size impact | Small delta | Larger transitive (C lib) |
| License surface | LGPL-2.1 (rawler), GPL-3 compatible via §3 | Rust crate MIT; LibRaw C++ LGPL-2.1/CDDL — notice handling required |
| Camera coverage | Growing but may lag very new bodies vs LibRaw | Very broad, mature |
| Maintainability | Single language, memory-safe | Mixed; more build complexity |

## Recommendation (preliminary)
Given the project goals (FOSS, offline, mobile, F-Droid-friendly, and the architecture already supports JPEG ROI by decode+crop), **rawler is the better default starting point**. It matches the "single toolchain" principle, is easy to test in-memory, and avoids C build complexity. LibRaw remains a strong fallback if coverage gaps arise; ADR 0005 should be accepted with rawler as the first implementation, keeping the `ImageSource` trait neutral so LibRaw can be re-evaluated later.

## Status
Spike complete. Decision: **rawler-first** (LibRaw kept optional behind `--features raw-libraw`).

### Phase D follow-on (landed on this surface)
- `raw::metadata` reads dimensions, cpp, orientation, WB and the DNG camera
  matrix (a DNG with an embedded `ColorMatrix` round-trips through decode).
- `raw::color`: 3×3 inverse/multiply, `camera_to_srgb` (XYZ→camera DNG matrix,
  D50→D65 Bradford adaptation) and `apply`.
- `raw::lens`: Brown–Conrady radial distortion (`distortion_factor`,
  `distorted_radius`, Newton `undistort_radius`) and radial vignette gain +
  `correct_vignette`.
- `raw::decode` handles 3-component LinearRaw; Bayer/CFA demosaic is the next
  P3 step along with ROI tiles and the embedded-preview fast path.

### Phase E follow-on (landed on this surface)
- `raw::decode` now handles single-channel Bayer/CFA sources: the sensor CFA
  (`CfaPattern`, from `camera.cfa`) drives `demosaic_bilinear`, followed by
  white-balance normalisation (green-referenced). `decode_with_metadata` decodes
  the source once for callers that need pixels + matrix. A synthetic Bayer DNG
  round-trips end-to-end (real CFA photos are still untested — no RAW corpus).
- ROI: `demosaic` → `crop_linear` / `decode_roi` (decode-full-then-crop, the same
  strategy as the JPEG path, pending true tile access).
- Orientation: `decode` applies the EXIF orientation (`RawOrientation::to_flips`
  → flip H/V then transpose) so pixels come out upright; `raw_dimensions`
  reports display dimensions (swapping axes for 90°/270°/transpose).
- FFI (`api/raw.rs`, exposed as `TesseraEngine.rawDimensions` /
  `decodeRawRgba` / `decodeRawRoi`): decode + `camera_to_srgb` + `to_rgba8` so
  Dart receives sRGB RGBA8. `lib/engine/image_format.dart` sniffs TIFF/CR3/RAF
  and the viewport, crop screen, editor export and gallery export route raw
  containers through this path instead of Flutter's JPEG/PNG-only codec.
  (RAW EXIF passthrough on export is a follow-up.)
- **Deferred:** the embedded-preview fast path is intentionally skipped:
  using the camera's embedded JPEG preview as the graded base would break the
  "preview == export" invariant, since export runs our demosaic + colour
  pipeline. If added, it must be a transient placeholder swapped for the full
  decode, not the graded base.
