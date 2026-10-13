# ADR 0008 — Dual UI shells (Lightroom-default + Snapseed) over one recipe

- **Status:** Accepted (amends ADR 0006)
- **Date:** 2026-10-13
- **Deciders:** Developer's Paradise

## Context

ADR 0006 chose the Snapseed *invisible gesture* model as the primary interaction
and Material 3 as the visual system. That was the right call for the FOSS gap —
but the builder's own preference (and a large slice of the pro audience) is
**Lightroom's** precision UI: persistent categorized panels, numeric sliders with
tap-to-type exact values, a live histogram with clipping warnings, before/after,
history/snapshots, and copy/paste/sync of settings.

These are not competing products; they are two *shells* over the same edits. The
risk of picking one exclusively is rebuilding the engine later when the other is
wanted. The correct invariant is: **the recipe is the product; the UI is a
swappable view.**

## Decision

1. **One `EditRecipe` is the single source of truth.** Every UI shell reads and
   writes the same recipe. Switching shells mid-edit never changes the image,
   because no shell owns pixel state — they only render/edit recipe parameters.
2. **The recipe schema is a Lightroom-aligned superset**, not a Snapseed subset.
   It models (at minimum): exposure, contrast, highlights, shadows, whites,
   blacks, texture, clarity, dehaze, vibrance, saturation, white balance
   (temp/tint), tone curve (RGB + per-channel), HSL/color-mix, color grading
   (shadow/mid/highlight), sharpening, noise reduction, grain, vignette, lens
   corrections, geometry, and adjustment layers with masks. Doing it in this
   direction (Lightroom → Snapseed mapping) avoids an engine rewrite; the
   reverse (Snapseed-first) does not.
3. **Lightroom shell (default).** Panel-based UI: Light, Color, Effects, Detail,
   Optics, Geometry, Masking, Presets. Fine-grain Material 3 sliders with
   tap-to-type numeric entry, live histogram with highlight-clip warnings,
   before/after, filmstrip, history, snapshots, and copy/paste/sync settings.
4. **Snapseed shell (toggleable).** The existing gesture FSM (ADR 0006), driving
   the *same* recipe parameters. Snapseed tools become named *mappings* onto the
   superset schema (e.g. Tune Image → exposure/contrast/saturation/shadows/
   warmth).
5. **A toggle in Settings + a first-run choice.** The shell is a presentation
   preference stored in app settings, never in the recipe.
6. **The two shells may be built to different depths over time** (see
   `PARITY.md`); the recipe schema must nonetheless be complete enough that a
   parameter exists before either shell exposes it.

## Consequences

**Positive**
- One engine, two audiences; no fork of the edit model.
- Lightroom users get the precision they expect; Snapseed users keep the feel.
- Because the schema is a superset, adding a parameter benefits both shells.

**Negative / risks**
- Two full UIs to build and maintain — roughly double the UI surface.
- The superset schema must be designed up-front (P2), which is a large, hard-to-
  reverse commitment; getting the parameter model wrong is expensive.
- Defaulting to Lightroom means the already-built gesture shell is no longer the
  landing experience; it must still be kept working and tested.
- Histogram, history, snapshots, and sync are non-trivial subsystems in their own
  right, not free with the panel UI.

**Follow-ups**
- P2 lands the recipe superset + both shells reading it.
- The gesture FSM (already built and tested in P-1/P0) is retained as the
  Snapseed shell's engine; it is not discarded.
- Parity between the two shells is tracked in `PARITY.md`, not assumed.
