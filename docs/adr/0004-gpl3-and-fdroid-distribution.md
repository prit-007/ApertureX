# ADR 0004 — GPL-3.0 licensing and F-Droid distribution

- **Status:** Accepted
- **Date:** 2026-10-13
- **Deciders:** Developer's Paradise

## Context

Tessera is a flagship FOSS project for the org. Distribution should be
reproducible and compatible with F-Droid, and the license should guarantee that
the work stays free — matching the org's existing `nook` app (GPL-3.0).

Permissive inbound licenses (we fork/carry BSD-3, MIT, Apache-2.0 components) are
compatible with a GPL-3.0 outbound project.

## Decision

- License Tessera **GPL-3.0-or-later**.
- Ship Android via **F-Droid**, reusing the org's `nook` F-Droid recipe patterns:
  - Per-ABI release APKs (`--split-per-abi`).
  - Version-code offsets encoded as `base × 10 + {1,2,3}` (v7a/arm64/x86_64) so
    `VercodeOperation: ['%c * 10 + 1', ...]` matches.
  - Pinned Flutter SDK version in the F-Droid `srclibs`.
  - NDK version pinned.
- Preserve all third-party notices ([`THIRD_PARTY.md`](../THIRD_PARTY.md)), incl.
  the BSD-3 fork notice and Apache-2.0 NOTICE.
- No telemetry, no accounts, no network calls required for core editing.

## Consequences

**Positive**
- Guarantees user freedom and matches org precedent.
- F-Droid listing satisfies the "leave proprietary apps" audience.
- Reproducible, source-available distribution.

**Negative / risks**
- GPL-3 is incompatible with some app-store/EULA terms; iOS distribution via the
  App Store must be reviewed against GPL-3 obligations (a known FOSS tension).
- Per-ABI + version-code scheme is fiddly; reuse the `nook` recipe to avoid
  re-deriving it.
- Reproducibility requires pinning toolchains and, for native deps, careful build
  hooks.

**Follow-ups**
- Confirm iOS/App Store GPL-3 distribution approach before P5 iOS release.
- Set up F-Droid metadata repo early (P5) but structure the build for it from P0.
