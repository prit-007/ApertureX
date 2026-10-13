# ADR 0011 — Material You neutrality, premium UX, and the FOSS library set

Status: Accepted · Date: 2026-10-13

## Context

ApertureX ships two shells (ADR 0008) and must look modern (Material 3 /
Material You) without compromising **colour accuracy** — the whole point of a
photo editor. We also want "premium" micro-interactions that beat the
proprietary apps, and we must not re-invent decoders or FFI.

## Decisions

### 1. Material You "neutrality rule" (colour accuracy)

Material You extracts the accent from the wallpaper. If that tint leaks into the
app background, the user's eye adapts and they grade wrong (e.g. a pink surface
makes them push the photo green).

- **Keep** the dynamic scheme's **accent** (`primary`/`secondary`/`tertiary`) for
  active slider tracks, selected chips/icons, and the Snapseed HUD accent.
- **Force neutral greys** for `surface`, `background`, and all
  `surfaceContainer*` tones (pure black / near-black in dark; near-white in
  light). Beautiful M3 shapes and padding, perfectly neutral canvas.
- Apply in `core/theme/app_theme.dart` by post-processing the dynamic
  `ColorScheme` (`copyWith` the neutral roles only).

### 2. Premium micro-interactions (adopt)

- **Zero-gravity haptics:** a *crossing* of neutral fires `mediumImpact`; hitting
  an end-stop fires `heavyImpact`. The core is a pure, unit-tested function
  `hapticFor(previous, next, min, max) -> HapticTick`; widgets fire it.
- **"Anywhere" before/after:** long-press anywhere on the canvas crossfades
  (~150 ms) to the unedited image; release crossfades back. (Ships with the
  canvas.)
- **Interactive histogram:** drag the left third → Blacks, middle → Exposure,
  right third → Whites. (Follows the histogram widget.)
- **Thumb-zone radial menu:** long-press blooms an M3 radial tool menu under the
  thumb in the Snapseed shell. (Exploratory.)
- **Git-style history tree:** the recipe history is a branchable tree, not a
  linear stack; a History sheet lists edits and lets the user branch.

### 3. FOSS library set (do not reinvent)

- **Engine:** `flutter_rust_bridge` (already in use), `zune-jpeg`/`jpeg-encoder`
  (in use), **`image-rs`** for PNG/WebP, **`libraw-rs`** for RAW
  (CR2/NEF/ARW/RAF/DNG) behind the `RawDecoder` trait (ADR 0005).
- **UI:** **`dynamic_color`** (in use), **`riverpod`** (in use),
  **`extended_image`** — *evaluate* for the canvas pinch/pan/tiling; keep our own
  tile compositor as the engine of record.
- Every addition needs a `THIRD_PARTY.md` row.

## Consequences

- Colour accuracy is preserved while keeping M3 polish.
- Haptics/history are pure-logic-testable; the rest are incremental UI.
- The colour-canvas/tile engine stays ours; libraries are adopted only where
  they don't fight the memory/colour model.

## Not in scope here

Spatial passes (clarity/texture/sharpen/dehaze/shadows-highlights) and wide
colour gamut (f16/linear-P3, ICC) are tracked separately (see ROADMAP/PARITY).
