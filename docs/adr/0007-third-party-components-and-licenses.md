# ADR 0007 — Third-party components and licensing

- **Status:** Accepted
- **Date:** 2026-10-13
- **Deciders:** Developer's Paradise

## Context

Tessera can be built faster by standing on existing Flutter packages. For a
GPL-3.0 project we must confirm inbound-license compatibility and preserve
notices.

Components under consideration:
- `pro_image_editor` — BSD-3-Clause.
- `extended_image` — MIT.
- `dynamic_color` — Apache-2.0.
- `flutter_rust_bridge` — MIT / Apache-2.0.

Permissive licenses are inbound-compatible with GPL-3: the combined work is
distributed under GPL-3 as long as original notices are retained.

## Decision

Adopt three tiers:

1. **Adopt as dependencies:** `dynamic_color` (Material You theming),
   `extended_image` (gallery + gesture layer + `ExtendedRawImage.sourceRect` tile
   blits), `flutter_rust_bridge` (FFI).
2. **Fork:** `pro_image_editor` (pin 14.13.1), reduced to grading chrome; see
   [`FORK-STRATEGY.md`](../FORK-STRATEGY.md).
3. **Reference-only:** Image Toolbox, Snapseed, darktable — behavior/ideas only,
   no code copied. If code is ever copied, the component is promoted to the
   fork/adopt tier with its notices.

All notices and compatibility reasoning live in [`THIRD_PARTY.md`](../THIRD_PARTY.md)
and will be surfaced in the in-app license registry at P0.

## Consequences

**Positive**
- Faster delivery; proven UI/gesture/theme code.
- Clear, auditable license posture for a GPL-3 project.

**Negative / risks**
- Fork drift and maintenance cost (FORK-STRATEGY §7, with an escape hatch to
  reference-only).
- `pro_image_editor` v14's `material_ui`/`cupertino_ui` dependency forces a
  localizations decision (ADR 0006).
- Notice hygiene must be enforced in CI (license check step in P0).

**Follow-ups**
- Add `flutter_licenses`/`LicenseRegistry` output and a CI license check.
- Re-evaluate the fork at each upstream stable tag.
