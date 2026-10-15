# ADR 0005 RAW engine prototype spike (Phase C)

## Objective
Prototype both candidate decoders against the fixed `ImageSource` boundary (ARCHITECTURE §7.2):
- `rawler` (pure-Rust): decode RAW/DNG in-memory, ROI feasibility, DNG re-encode path.
- `libraw` (C/C++): decode RAW via FFI, ROI feasibility, license/build notes.

## Setup
- Added `rawler = "0.8.0"` and `libraw = "0.1.1"` to `app/rust/Cargo.toml`
- `libraw` compiles against system LibRaw 0.21.2.
- Minimal `raw.rs` test produced a synthetic DNG via `rawler::dng::writer` and verified roundtrip through `rawler::decode`.

## Status
Prototyping started. Next: define a minimal `ImageSource` wrapper for both and benchmark against small fixtures.


## Findings
- **rawler**: in-memory DNG roundtrip works (`RawSource::new_from_slice`); dimensions/full/ROI shim compiles and a small DNG decodes. Pure-Rust, single toolchain (good for F-Droid from-source).
- **libraw**: crate links against system LibRaw 0.21.2; API surface in `libraw` 0.1.1 is `Image::open(path)` only (no obvious in-memory open). Linkage/structs compile; for the spike we can exercise via temporary files or note API constraint.
- Both fit behind a thin trait without leaking into UI/edit code (matches ADR 0005 deferral).

## Next
- Add a temp-file based decode test for libraw if desired, or skip in-memory. Curate tiny synthetic DNG fixture(s). Record timing/peak-RSS for small images and document tradeoffs.

