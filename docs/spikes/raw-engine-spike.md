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
