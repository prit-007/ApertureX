# Changelog

All notable changes to ApertureX are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and this project adheres to
[Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-10-14

First public pre-release: a dual-UI (Lightroom panels + Snapseed gestures),
non-destructive, fully offline photo editor.

### Added
- **Dual shells over one recipe**: Lightroom-style panels and a Snapseed-style
  gesture "Ghost UI"; switching shells never changes the image.
- **Rust engine** (via `flutter_rust_bridge`): color pipeline (exposure,
  contrast, highlights/shadows/whites/blacks, WB, vibrance, saturation,
  split-tone, HSL mixer, tone curves), geometry (rotate/flip/straighten/crop),
  spatial ops (clarity, texture, sharpen, denoise, dehaze, vignette, grain),
  local-adjustment masks, JPEG decode/export, EXIF carry-over, ICC/P3 handling.
- **60fps preview**: proxy-resolution decode, split base/grade bakes, a baked
  65³ LUT sampled by one fragment shader; export grades at full resolution.
- **Crop tool** with aspect presets and rotate/flip.
- **Gallery**: date-grouped (newest first), album switching, multi-select batch
  paste/export, "edited" badges.
- **Non-destructive per-photo recipes**, persisted settings (theme, shell,
  export quality/size), preset import (`.cube`, Lightroom `.xmp`), shareable
  JSON looks, sidecar open.
- **On-device offline activity log** with a first-run guide and export.
- **Permissions**: asks on launch, re-prompts, and falls back to settings.
- Material 3 theming with neutral surfaces and a dynamic accent.

### Notes
- Android-first. iOS builds are not produced by the maintainers (no Xcode in
  CI) but the project targets both.
- RAW, Ultra HDR, and on-device ML are tracked and not in this release.
