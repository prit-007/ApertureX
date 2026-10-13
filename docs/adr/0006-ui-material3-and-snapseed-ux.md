# ADR 0006 — Material 3 UI and the Snapseed-style gesture model

- **Status:** Accepted
- **Date:** 2026-10-13
- **Deciders:** Developer's Paradise

## Context

The FOSS photo-editor gap is as much a UX gap as a technical one. Two distinct
design languages are relevant:

- **Material 3 / Material You** (as exemplified by Image Toolbox, a Kotlin/Compose
  app): wallpaper-derived color, pill sliders, floating `surfaceContainer` cards.
- **Snapseed's invisible editing model**: no sliders; vertical swipe cycles tools,
  horizontal swipe changes intensity, tap resets.

The team wants the Image Toolbox *look* with the Snapseed *feel*. Flutter's
Material 3 library is mature enough to replicate the look; the feel must be built
as an explicit interaction state machine.

## Decision

1. **Visual system:** Flutter **Material 3**, seeded via `ColorScheme.fromSeed`,
   overridden by **`dynamic_color`** on Android S+ (wallpaper palette). iOS keeps
   the seed (no system dynamic color). Tool panels are `Card(elevation: 0)` in
   `surfaceContainer`/`surfaceContainerHigh` with pill sliders.
2. **Reuse:** fork `pro_image_editor` for toolbar/slider/state scaffolding
   (ADR 0007, FORK-STRATEGY.md).
3. **The gesture FSM:** implement a **pure-Dart `GestureInterpreter`** with states
   `IDLE → SCANNING → {TAP, CYCLING, SCRUBBING}`, axis-locked after `kTouchSlop`,
   with tap-to-reset. The widget layer only forwards pan deltas; the FSM owns
   transitions and is exhaustively unit-tested. It arbitrates against the
   viewport's pan/zoom (no pan while scrubbing).
4. **Decided:** Tessera **migrates to `material_ui` / `cupertino_ui`** — the
   app's `MaterialApp` uses those packages directly, matching the fork's own
   foundation and avoiding the injected-localizations workaround (FORK-STRATEGY
   §5). This is done in P0 before any UI beyond a shell is built.

## Consequences

**Positive**
- Native-feeling shell; recognizable "Image Toolbox" aesthetic.
- A testable, deterministic gesture model instead of fragile ad-hoc detectors.
- Dynamic color is a one-line win on Android.

**Negative / risks**
- Dynamic color is Android-only; iOS needs a designed seed and the look must not
  depend on wallpaper colors.
- Gesture/viewport arbitration is subtle; the FSM + gesture-arena handling needs
  dedicated tests.
- Fork maintenance overhead (ADR 0007).

**Follow-ups**
- P-1 spike validates scrub feel and axis-lock before P1.
- Resolve the `material_ui` migration question in P0.
