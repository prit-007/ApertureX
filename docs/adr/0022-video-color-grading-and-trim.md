# ADR 0022 — Video Color Grading & Non-Destructive Trim Pipeline

- **Status:** Accepted
- **Date:** 2026-10-30
- **Deciders:** Developer's Paradise
- **Consults:** ADR 0003 (Non-destructive Recipe Model), ADR 0009 (Preset & 3D LUT Compatibility)

---

## 1. Context

Modern creators and hybrid photographers shoot both still RAW photos and video footage in the field. Photographers expect to:
- Apply the same color grading recipe (exposure, tone curves, white balance, HSL color mix, split toning, and 3-way color wheels) across video clips to achieve consistent visual aesthetics.
- Trim video clips with frame-accurate In/Out markers directly inside their primary creative editor.
- Export color grades as standard 3D `.CUBE` LUTs (17³, 33³, 65³) compatible with Hollywood and broadcast NLEs (DaVinci Resolve, Adobe Premiere Pro, Final Cut Pro).

## 2. Decision

Implement the Video Color & Grading Studio (`app/lib/features/video/`):

1. **Video Clip & Transport State Model (`video_model.dart`)**:
   - `VideoClip`: Tracks frame rate (FPS), duration, native resolution, and non-destructive `inPointMs` / `outPointMs`.
   - `formatTimecode()`: Formats SMPTE-compliant timecodes (`HH:MM:SS.FF`).
   - `VideoPlaybackState`: Manages playback status, loop toggle, and playback speed (0.5x, 1.0x, 2.0x).

2. **Grading Controller & NLE LUT Export (`video_grading_controller.dart`)**:
   - Integrates the core `EditRecipe` pipeline into video transport and timeline scrubbing.
   - Provides frame-step forwards (`|>`) and frame-step backwards (`<|`) operations.
   - Exports 3D `.CUBE` LUTs using the Rust `export_cube_lut` engine (or high-speed Dart fallback) across 17³, 33³ (Pro), and 65³ (Master) resolutions.

3. **Video Timeline Scrubber Widget (`video_timeline_widget.dart`)**:
   - Visual filmstrip track displaying draggable In-point and Out-point trim brackets.
   - Interactive playhead needle with seek scrubbing.
   - Mark In (`I`) and Mark Out (`O`) quick-set buttons.

4. **Dedicated Video Color Studio Screen (`video_editor_screen.dart`)**:
   - Live video preview viewport with aspect ratio preservation and 3D LUT active indicator.
   - Full Lightroom/Snapseed color adjustment sliders (Exposure, Contrast, Highlights, Shadows, Whites, Blacks, Temperature, Tint, Vibrance, Saturation).
   - 3-Way primary color wheels (Lift / Gamma / Gain).
   - Direct export of trimmed video and .CUBE LUT strings.

## 3. Consequences

### Positive
- **Unified Creative Pipeline**: Still photography recipes map directly onto video clips without duplicate grading logic.
- **Industry Standard Interoperability**: Direct `.CUBE` LUT export enables seamless workflows with DaVinci Resolve and Adobe Premiere.
- **Frame-Accurate Control**: SMPTE timecode transport and sub-frame trim precision.

### Negative
- Decoding 4K/8K 60fps video frames on mobile requires hardware video decoders; full real-time playback relies on target platform Surface textures.
