# ADR 0003 — Non-destructive recipe model

- **Status:** Accepted
- **Date:** 2026-10-13
- **Deciders:** Developer's Paradise

## Context

Users expect to revisit, tweak, and undo edits indefinitely without degrading the
image. Baking adjustments into pixels on every change is lossy, slow, and
irreversible. We also want portable, shareable edit state.

Alternatives considered:
- **Destructive editing (bake on each change):** simplest render path, but lossy,
  irreversible, and hostile to preview/export consistency.
- **Command/observer graph stored as code:** flexible but hard to serialize and
  migrate.
- **Serialized ordered op list (recipe):** explicit, versionable, portable.

## Decision

Represent every edit as a **versioned `EditRecipe`** — an ordered list of color ops
with parameters, plus geometry — serialized to JSON. The source pixels are never
modified. Preview applies the recipe to the viewport at screen resolution; export
applies the same recipe to the full image at native resolution. The op order is
fixed and versioned (ARCHITECTURE §8).

## Consequences

**Positive**
- Reversible, non-lossy editing; cheap undo/redo (mutate the recipe).
- Tiny storage footprint (KB-scale sidecars) vs. copying megapixels.
- Presets are just recipes; sharing is trivial (`*.tessera-preset.json`).
- Preview and export derive from one definition, guaranteeing consistency.

**Negative / risks**
- Every preview frame must re-evaluate the recipe (mitigated by LUT baking and a
  folded scalar "grade" shader).
- Schema evolution needs migration logic; op reordering must never silently change
  existing edits — hence versioning.
- Very long chains can exceed shader uniform limits; addressed by LUTs and
  multi-pass splits.

**Follow-ups**
- Define the migration policy (N → N+1) in P2.
- Golden tests for serialize/deserialize and migration.
