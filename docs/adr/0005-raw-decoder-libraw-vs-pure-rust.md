# ADR 0005 — RAW decoder: LibRaw vs pure-Rust

- **Status:** **Proposed / deferred to phase P3**
- **Date:** 2026-10-13
- **Deciders:** Developer's Paradise

## Context

RAW support is a defining feature, but the engine choice carries long-term
consequences for build complexity, camera coverage, battery, and license surface.
We do **not** need to decide now: phases P0–P2 are JPEG-first and prove the rest of
the architecture independently.

Two viable paths:

### Option A — LibRaw via Rust
- **What:** a Rust binding to the mature C/C++ `LibRaw` (plus `lensfun`-class
  correction profiles), called through the `ImageSource`/`RawDecoder` trait.
- **Pros:** broadest camera coverage; battle-tested demosaic/color; well-known
  behavior; large RAW corpus support "for free".
- **Cons:** C/C++ toolchain in the mobile build; larger binary; license/notice
  handling; ROI decode requires care since LibRaw is file-oriented; cross-compile
  friction in F-Droid's from-source builds.

### Option B — Pure Rust
- **What:** pure-Rust decode crates (e.g. `rawler` and friends) behind the same
  trait.
- **Pros:** single toolchain, memory-safe, easy cross-compile/reproducibility,
  smaller binary, natural ROI/streaming orientation.
- **Cons:** narrower camera matrix; less mature color science; more of our own
  work to reach LibRaw parity; risk of gaps in exotic formats.

A middle path also exists: ship Option A for coverage, keep the trait neutral so a
pure-Rust path can be added for supported cameras or for constrained builds.

## Decision

**Deferred.** The `ImageSource` trait (ARCHITECTURE §7.2) is fixed now so either
implementation drops in without touching the UI, viewport, or edit model. The
final choice is made in **P3** against measured evidence (frame time, peak memory,
camera-corpus coverage, build reproducibility) and recorded by moving this ADR to
**Accepted**.

## Consequences

- P0–P2 must not assume LibRaw-specific behavior anywhere above the engine.
- The RAW corpus test harness is defined before the choice so both options can be
  scored identically.
- Both licenses are compatible with GPL-3 (LibRaw: LGPL-2.1/CDDL; pure-Rust crates:
  typically MIT/Apache-2.0) — pending final crate selection and notice capture.

## Follow-ups (P3 entry criteria)

1. Stand up the RAW corpus (DNG, CR2, NEF, ARW, RAF, ORF).
2. Prototype ROI decode in each option.
3. Measure frame time, peak RSS, build time, binary size, F-Droid
   build-from-source feasibility.
4. Decide, set status to Accepted, update [`THIRD_PARTY.md`](../THIRD_PARTY.md).
