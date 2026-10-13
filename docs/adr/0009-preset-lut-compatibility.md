# ADR 0009 — Preset and LUT compatibility policy (honest, best-effort)

- **Status:** Accepted
- **Date:** 2026-10-13
- **Deciders:** Developer's Paradise

## Context

To replace Lightroom for real, users must bring their existing looks:

- **LUTs** (`.cube` 1D/3D, HALD CLUT PNG, `.3dl`) — open, industry-standard color
  transforms.
- **Lightroom presets** (`.xmp`, legacy `.lrtemplate`) — XML / Lua-table files
  mapping to Adobe Camera Raw settings in the documented `crs:` namespace.
- **Snapseed "Looks"** — Snapseed has **no documented portable file format**;
  its QR sharing encodes a proprietary blob.

Two hard truths constrain any promise here:

1. **Adobe's exact rendering is proprietary.** Their tone/color math is not
   published. The same `.xmp` will look *close*, never guaranteed identical.
2. "Works without any issue" is not a deliverable we can honestly sign. Saying
   so in a FOSS project is a trust problem.

## Decision

1. **Open LUT formats: full support.** `.cube` (1D and 3D), HALD CLUT PNG, and
   `.3dl` are parsed and baked into a 3D LUT texture sampled in the shader. These
   are deterministic and fully under our control.
2. **`.xmp` / `.lrtemplate`: best-effort import with a visible compatibility
   report.** We parse the documented `crs:` settings namespace and map each tag to
   our recipe schema. Every import produces a per-preset **compatibility report**
   classifying each setting as *applied*, *approximated*, or *unsupported*, shown
   to the user before/after applying.
3. **Adobe exact rendering is explicitly not guaranteed.** Fidelity is defined by
   **golden-image tolerance tests**: import a preset, apply to a reference image,
   and compare against an Adobe-exported reference within a documented delta-E /
   per-channel tolerance. "Close" is measured, not asserted.
4. **Embedded profile/LUT tables in presets:** partial. Where a preset embeds a
   look/profile LUT, we extract and use it; otherwise we approximate via our own
   tone/color ops and mark it *approximated*.
5. **Snapseed Looks: no import.** There is no portable format. We ship our own
   open alternative: an **ApertureX Look** = the `EditRecipe` JSON, shareable as a
   file or encoded to a **QR code** (open standard, documented in-repo) so users
   get Snapseed-like one-scan sharing without the proprietary blob.
6. **The compatibility report and golden tests are first-class deliverables**,
   not afterthoughts — a preset import that silently degrades is a bug.

## Consequences

**Positive**
- Users can move real Lightroom libraries in, with eyes-open expectations.
- Open LUT support is a strong, honest differentiator.
- Our own Look/QR format is open and portable (unlike Snapseed's).

**Negative / risks**
- The compatibility report + golden-tolerance harness is itself a substantial
  sub-project (test corpus of presets + reference exports).
- Maintaining the `crs:` tag map as Adobe evolves `.xmp` is ongoing work.
- Users will still report "it doesn't look exactly like Lightroom" — that is
  inherent to Adobe's closed math and must be communicated in-product and in docs.

**Follow-ups**
- P2: LUT import + `.xmp`/`.lrtemplate` parser + compatibility report.
- Establish the golden-image corpus and tolerance thresholds in P2.
- Document the Look/QR open standard in-repo when it ships.
