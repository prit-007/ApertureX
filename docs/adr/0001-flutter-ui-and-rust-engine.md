# ADR 0001 — Flutter UI with a Rust engine

- **Status:** Accepted
- **Date:** 2026-10-13
- **Deciders:** Developer's Paradise

## Context

Tessera must be a mobile-native, touch-first photo editor on Android and iOS. The
UI demands fluid gesture handling and GPU-accelerated previews; the engine demands
memory-safe, parallel image decoding and color math over very large buffers. The
team's existing expertise is Flutter (see the `nook` project); there is no
existing Rust code in the org.

Alternatives considered:
- **Fully native (Kotlin + Swift, or Kotlin/Compose only):** maximal platform
  reach but doubles UI work and abandons the team's Flutter velocity.
- **Pure Dart engine:** simplest build, but benchmarks show pure-Dart decode +
  process is an order of magnitude slower and consumes far more peak RSS than
  native/Rust paths.
- **C++ engine:** capable, but higher memory-safety risk and a heavier build story
  than Rust with `flutter_rust_bridge`.

## Decision

Build the UI in **Flutter** (with **Material 3**) and the image engine in **Rust**,
connected by **`flutter_rust_bridge v2`** (built via `cargokit`). Consolidate on
Android + iOS for v1.

## Consequences

**Positive**
- One UI codebase; team velocity retained.
- Rust gives memory safety, `rayon`/SIMD, and strong image crates; the bridge
  handles arbitrary types, async Rust, and zero-copy big arrays.
- Rust's `trait` system cleanly expresses the pluggable `RawDecoder` boundary.

**Negative / risks**
- Rust is new to the team — mitigated by a thin initial Rust surface in P0.
- Two toolchains (Flutter + Cargo) in CI.
- FFI debugging is harder than pure Dart.

**Follow-ups**
- P0 proves the bridge end-to-end before any imaging work.
- Keep `edit_core` pure Dart so most logic is testable without the bridge.
