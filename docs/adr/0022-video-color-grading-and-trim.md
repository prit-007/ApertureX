# ADR 0022 — Video Color Grading & Multi-Clip Editing Studio

- **Status:** Accepted
- **Date:** 2026-10-30 (Updated 2026-10-31)
- **Deciders:** Developer's Paradise
- **Consults:** ADR 0003 (Non-destructive Recipe Model), ADR 0009 (Preset & 3D LUT Compatibility)

---

## 1. Context

Modern creators and hybrid photographers shoot both still RAW photos and video footage in the field. Photographers expect to:
- Apply the same color grading recipe (exposure, tone curves, white balance, HSL color mix, split toning, and 3-way color wheels) across video clips to achieve consistent visual aesthetics.
- Assemble and edit multi-clip sequences with sub-frame trimming, razor cuts, ripple deletion, duplication, and reordering.
- Add non-destructive transitions (Cross Dissolve, Dip to Black/White, Wipes) between clips.
- Control audio volume (-60dB to +6dB), mute state, and fade envelopes.
- Adjust framing and canvas aspect ratios (16:9, 9:16 Shorts/Reels/TikTok, 1:1, 4:5, 21:9), rotate, and flip.
- Overlay animated title cards and lower thirds directly on the timeline.
- Export color grades as standard 3D `.CUBE` LUTs (17³, 33³, 65³) compatible with Hollywood and broadcast NLEs (DaVinci Resolve, Adobe Premiere Pro, Final Cut Pro).

## 2. Decision

Implement the Video Color & Multi-Clip Studio (`app/lib/features/video/`):

1. **Multi-Clip Sequence & Transport Model (`video_model.dart`)**:
   - `VideoClip`: Tracks frame rate (FPS), duration, native resolution, speed (0.25x–8.0x), reverse playback, audio settings, transform, and non-destructive `inPointMs` / `outPointMs`.
   - `VideoSequence`: Manages an ordered list of clips, inter-clip transitions, text overlays, and sequence-to-clip time mapping.
   - `VideoTransition`: Configurable transition types (`cut`, `crossDissolve`, `dipToBlack`, `dipToWhite`, `wipeLeft`, `wipeRight`) with millisecond duration.
   - `VideoAudioSettings`: Linear volume (0.0 to 2.0), mute toggle, audio gain in dBFS, and fade-in/fade-out millisecond curves.
   - `VideoTransform`: Social aspect ratio framing presets (16:9, 9:16, 1:1, 4:5, 21:9), 90° rotation, horizontal/vertical flipping, and fit/fill modes.
   - `VideoTextOverlay`: Title cards and lower thirds with screen positioning (Top, Center, Lower Third, Bottom), timing windows, font size, and background pill badges.
   - `formatTimecode()`: Formats SMPTE-compliant timecodes (`HH:MM:SS.FF`).

2. **Sequence Grading Controller (`video_grading_controller.dart`)**:
   - Integrates the core `EditRecipe` pipeline into video transport and timeline scrubbing across multi-clip sequences.
   - Provides Razor splitting at playhead (`splitActiveClip()`), ripple deletion, duplicate clip, and clip reordering.
   - Controls audio gain, mute, fade, spatial orientation, and text overlays.
   - Exports 3D `.CUBE` LUTs using the Rust `export_cube_lut` engine (or high-speed Dart fallback) across 17³, 33³ (Pro), and 65³ (Master) resolutions.

3. **Multi-Clip Timeline Scrubber Widget (`video_timeline_widget.dart`)**:
   - Quick action toolbar: Split (Razor), Duplicate, Ripple Delete, Speed Ramping, Reverse, and Append Clip.
   - Visual multi-clip sequence track displaying proportional clip blocks, active clip borders, and transition pill badges.
   - Audio track indicator with volume levels and mute status.
   - Interactive playhead needle with seek scrubbing.
   - Mark In (`I`) and Mark Out (`O`) quick-set buttons.

4. **Dedicated Video Color Studio Screen (`video_editor_screen.dart`)**:
   - Live video preview viewport with aspect ratio framing, 2D rotation/flip transforms, active text overlays, and 3D LUT active indicator.
   - Tabbed inspector:
     - `Grading`: Full Lightroom/Snapseed color adjustment sliders.
     - `Wheels`: 3-Way primary color wheels (Lift / Gamma / Gain).
     - `Transform`: Aspect ratio framing presets, 90° rotation, horizontal/vertical flipping, scale, and fit modes.
     - `Audio`: Volume slider, mute switch, fade in/out durations, and peak dBFS metering.
     - `Titles / Text`: Add title, lower third, or subtitle overlays with position and animation pickers.
     - `Export / Info`: Sequence telemetry, target resolution presets, codec selection, frame rate selection, and .CUBE LUT export.

## 3. Consequences

### Positive
- **Complete Hybrid Workflow**: ApertureX functions as both a high-end RAW photo developer and a capable mobile/desktop video editor.
- **Unified Creative Pipeline**: Still photography recipes map directly onto video clips without duplicate grading logic.
- **Industry Standard Interoperability**: Direct `.CUBE` LUT export enables seamless workflows with DaVinci Resolve and Adobe Premiere.
- **Multi-Clip Sequencing**: Users can assemble complete reels and short-form content directly in-app.

### Negative
- Decoding multiple high-bitrate video streams concurrently increases memory usage; clip preview rendering uses hardware surface textures.
