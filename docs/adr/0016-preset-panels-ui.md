# ADR 0016 — Preset Panels UI

- **Status:** Accepted
- **Date:** 2026-10-19
- **Deciders:** Developer's Paradise

## Context

ApertureX supports preset import via `.xmp`, `.lrtemplate`, `.cube` LUTs, and its
own open `apx://` Look/QR format (ADR 0009). Users need a single place to:

- Browse built-in looks (Punch, Soft Portrait, Kodak Portra 160/400, Fuji Pro
  400H, Ilford HP5 Plus, CineStill 800T, etc.).
- Apply a built-in look to the current image with one tap.
- Import a custom look via JSON or `apx://` QR code.
- See which look is currently applied (visual indicator on the card).
- Access community presets through the same panel.

## Decision

### 1. "Looks & Presets" Master Tab

A dedicated **Looks & Presets** tab lives in the Lightroom shell. It renders a
scrollable list divided into two sections:

- **Built-in Looks** — one card per built-in `ToolDefinition` from
  `ToolLibrary.builtins`. Each card shows the look name, description, and a
  checkmark icon when its parameters match the current recipe (indicating it is
  applied). Tapping a look applies it via
  `RecipeController.applyTool(tool)` and commits a new history entry so the user
  can undo.
- **Import Look** — a text field accepting a look JSON or `apx://` QR code.
  On submit it decodes via `ToolDefinition.decode(json)`, applies it, commits,
  and shows a snackbar confirmation. A "Scan QR Look" button launches
  `LooksSheet.show(context)` for QR scanning.

### 2. Visual state

Each look card shows:
- **Icon** — `Icons.style` (primary color when applied, onSurfaceVariant otherwise).
- **Title** — look name (primary color when applied).
- **Subtitle** — one-line description.
- **Trailing** — `Icons.check_circle` (primary, size 20) when applied, otherwise
  `Icons.chevron_right`.

### 3. Commit behavior

Applying a look always commits a new history entry (label: `Applied <look name>`)
so the user can undo via the dedicated Undo button in the shell's action bar.
This keeps looks consistent with all other edits — non-destructive and
reversible.

### 4. Community presets

Community presets (downloaded/installed via the plugin hub or preset store) are
listed in the same tab under a separate section when available. Each preset
card shows name, author, and an Apply button.

## Consequences

**Positive**
- One-tap look application with full undo support.
- Clear visual indication of which look is applied.
- QR code import matches Snapseed-like sharing without the proprietary blob.

**Negative / risks**
- Built-in looks apply globally (entire image); selective/localized look
  application (per-mask) is out of scope for P2.
- The look match check compares parameter values within ±0.01 tolerance —
  near-identical but not exact matches may show as "not applied."

**Follow-ups**
- Add favorite/star looks for quick access.
- Add look intensity slider (apply look at X% strength).
- Add look stacking (apply multiple looks cumulatively).
