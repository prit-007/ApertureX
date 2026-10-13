# Fork Strategy — `pro_image_editor`

We fork [`hm21/pro_image_editor`](https://github.com/hm21/pro_image_editor)
(BSD-3-Clause) as the base for Tessera's Material 3 grading UI scaffolding. This
document defines provenance, what we keep, what we strip, and how we stay
maintainable.

> Related: [ADR 0007](adr/0007-third-party-components-and-licenses.md) ·
> [THIRD_PARTY.md](../THIRD_PARTY.md) · [ARCHITECTURE §4](ARCHITECTURE.md#4-ui-layer)

---

## 1. Why fork instead of depend

- We need to **reduce** the package to grading chrome and **replace** its render
  path with our tile/shader engine, which is not possible from the outside.
- We want to control the cadence of upgrades instead of chasing upstream breaks.
- BSD-3 permits this; GPL-3 covers our combined distribution.

## 2. Provenance & pinning

| Field | Value |
|-------|-------|
| Upstream | `github.com/hm21/pro_image_editor` |
| Pinned version | `14.13.1` (record the exact commit SHA at P0) |
| License | BSD-3-Clause |
| Fork location | `packages/pro_image_editor_fork/` (vendored, renamed) |

Rules:
- Record the upstream commit SHA in this file and in the fork's README.
- **Rename** the fork (package name + Dart class prefixes) so imports cannot
  silently resolve to upstream and so symbols read as ours.
- Never strip the upstream copyright header from source files.

## 3. Keep-list (what we reuse)

- Bottom toolbar / tool tray scaffolding and its state machine plumbing.
- Slider and pill-control widgets and their theming hooks.
- Crop / rotate / flip module (behind our geometry model).
- i18n hooks and per-module configuration surfaces.
- Any utility that is purely structural (layer ordering, history scaffolding) if
  it maps cleanly onto our `EditRecipe`.

## 4. Strip-list (what we remove in P0/P1)

| Module | Action | Reason |
|--------|--------|--------|
| Emoji picker | Remove | Out of scope; also a bundled-data weight. |
| Sticker editor | Remove | Not a grading tool. |
| AI assistant / background remove/replace | Remove | Explicit non-goal; would imply a service. |
| Video editor | Remove | Out of scope. |
| Social/WhatsApp theme variants | Remove | Replaced by our M3 factory. |
| Own filter pipeline | **Replace** | Superseded by our shader/LUT chain. |

Each removal is a separate commit so rebases are tractable.

## 5. Landmine: `material_ui` / `cupertino_ui` decoupling

Upstream v14 builds on the decoupled `material_ui` / `cupertino_ui` packages.
If the host app still uses `package:flutter/material.dart`, the editor's app bars,
dialogs, and bottom sheets throw **`No MaterialLocalizations found`** unless the
host injects the decoupled localizations:

```dart
import 'package:material_ui/material_ui.dart' as material_ui;

MaterialApp(
  localizationsDelegates: [
    ...material_ui.GlobalMaterialLocalizations.delegates,
    // existing delegates (flutter_localizations, etc.)
  ],
);
```

**Decided (P0 / ADR 0006):** Tessera **migrates to `material_ui` /
`cupertino_ui` wholesale.** The app's own `MaterialApp` uses those packages from
the start, so the fork's widgets need no localizations workaround. This keeps the
host and the fork on one foundation.

## 6. License & notice obligations

- Retain BSD-3 copyright/conditions/disclaimer in all forked source files.
- Do not use upstream author/contributor names to endorse Tessera.
- Reproduce the notice in the in-app license bundle and in
  [`THIRD_PARTY.md`](../THIRD_PARTY.md).

## 7. Update cadence

- **Baseline:** track upstream stable tags; evaluate a rebase each release cycle.
- **Method:** maintain our fork on a branch with the strip-list/replacements
  isolated as discrete commits; rebase upstream tags onto it rather than merging.
- **Triage:** keep a `FORK-DIVERGENCE.md` changelog listing every intentional
  divergence, so a rebase conflict is easy to attribute.
- **Upstream-back:** small, generic fixes (not Tessera-specific) are offered back
  as PRs to reduce future divergence.

## 8. Exit option

If maintaining the fork costs more than it saves (e.g. upstream restructures
heavily), fall back to **reference-only** and rebuild the small amount of chrome
we actually need. This is a deliberate escape hatch, not a failure — see
ADR 0007's "reference-only" tier.
