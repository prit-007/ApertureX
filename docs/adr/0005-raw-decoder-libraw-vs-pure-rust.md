# ADR 0005 — RAW decoder: LibRaw vs pure-Rust

- **Status:** **Accepted — rawler-first** (Phase C spike complete; rawler is the
  default shipped decoder. Real-corpus/perf evidence still being gathered in P3.)
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

**Accepted — rawler-first.** The `ImageSource` trait (ARCHITECTURE §7.2) is fixed
and the **pure-Rust `rawler` path is the default shipped decoder**. Phase C spike
(rawler 0.8.0 + libraw 0.1.1/system 0.21.2) favored rawler for FOSS/mobile/
F-Droid (single toolchain, in-memory decode, easier ROI, simpler cross-compile),
and the implementation has since landed: `raw::decode` (Bayer/CFA demosaic),
`raw::metadata`, `raw::color` (DNG matrices), and `raw::lens` (distortion +
vignette), with RAW ROI and RAW→JPEG export wired through Dart. LibRaw remains a
fallback behind `--features raw-libraw` if coverage gaps arise, and **must be
dynamically linked** (LGPL) if it ever ships. See
[raw-engine-spike.md](../spikes/raw-engine-spike.md). Remaining P3 evidence work:
real multi-vendor corpus coverage, lens-correction wiring, DCP profiles, and
highlight reconstruction.

## Consequences

- P0–P2 must not assume LibRaw-specific behavior anywhere above the engine.
- The RAW corpus test harness is defined before the choice so both options can be
  scored identically.
- Default build is pure-Rust (LGPL-2.1 rawler), GPL-3 compatible and F-Droid
  from-source clean. Adopting LibRaw/lensfun later requires dynamic linking +
  notices (issue #67); see [`THIRD_PARTY.md`](../THIRD_PARTY.md).

## Follow-ups (P3)

1. Stand up the RAW corpus (DNG, CR2, NEF, ARW, RAF, ORF). *(Pending.)*
2. Prototype ROI decode in each option. *(rawler ROI = decode-full-then-crop;
   native tiles pending.)*
3. Measure frame time, peak RSS, build time, binary size, F-Droid build-from-source
   feasibility.
4. **Done:** status set to Accepted; keep [`THIRD_PARTY.md`](../THIRD_PARTY.md)
   current (LibRaw/lensfun rows added only when the optional feature is enabled).
