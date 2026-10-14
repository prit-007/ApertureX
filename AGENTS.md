# ApertureX Agent Guide

## Project Overview
A mobile-native FOSS photo editor (Android + iOS) with Flutter UI + Rust engine via `flutter_rust_bridge`. Non-destructive editing with dual-UI shells (Lightroom-style precision panel + Snapseed-style gesture UI) over one shared recipe.

## Key Design Requirements
**Pro-level expectations from day one:**

### Responsive Layout (Cross-Device Native Feel)
- **Universal Coverage:** Compact phones to 14" Galaxy Tabs/iPad Pro
- **Portrait:** `ExtendedImage` top 75%, tools as `BottomSheet` with `SafeArea(bottom: true)`
- **Landscape/Tablet:** Split layout (image 70% left, controls 30% right sidebar with `SafeArea(right: true)`)
- **No hardcoded heights** - use `LayoutBuilder` + `OrientationBuilder`

### Advanced Stylus Input & Palm Rejection
- **Pressure Sensitivity:** `event.pressure` (0.0-1.0) for dynamic brush opacity/flow
- **Device Filtering:** `PointerDeviceKind` validation (accept only `stylus`, reject `touch` for brush tools)
- **Pro Pen Precision:** Support `invertedStylus` for eraser mode, pressure-graded masking

### Real-Time Geometry without Lag
- **GPU Offload:** Use Flutter `Matrix4` transforms for live crop/skew/perspective
- **Instant UI:** GPU warps rendered plane at 120FPS
- **Export Path:** Final `Matrix4` passed to Rust for CPU-intensive resampling

### Zero-Copy 60FPS Pipeline
- **Rust Holds:** Decoded image memory resident in Rust
- **Flutter Textures:** Zero-copy texture rendering for instant updates
- **3D LUT Magic:** Slider changes generate 33x33x33 LUTs (<1ms) rendered via Impeller shader
- **No Dart-Rust roundtrips** for edit previews

## Quick Start

### Environment Setup
- Flutter 3.44.x + Dart 3.12.x
- Rust 1.99.x (`. "$HOME/.cargo/env"`)
- Android SDK/NDK (for Android); Xcode only for iOS changes

### Core Commands
```sh
# Fresh clone setup
cd app
flutter pub get
flutter analyze

# Dart tests (unit tests)
flutter test

# Rust tests (engine tests)
cd rust
cargo test
cargo fmt --check
cargo clippy --all-targets -- -D warnings

# Android APK build
flutter build apk --debug

# Bridge regeneration (after changing rust/src/api/*)
flutter_rust_bridge_codegen generate
```

## Testing Strategy
**TDD is the house standard.** Write a failing test first.

### Test Organization
- **Dart tests**: `app/test/` (Flutter unit tests)
  - `app/test/edit/` – recipe/engine core logic
  - `app/test/ui/` – UI/shell behavior
  - `app/test/viewport/` – tile compositing, zoom/pan
  - Integration tests in `app/integration_test/`
- **Rust tests**: `app/rust/src/` (engine logic)
- **Platform tests**: `app/android/` + `app/ios/` (native behavior)

### CI Workflow (from `.github/workflows/ci.yml`)
1. `flutter analyze` → type correctness
2. `flutter test` → Dart unit tests
3. `cargo fmt --check` → Rust formatting
4. `cargo clippy --all-targets -- -D warnings` → Rust linting
5. `cargo test` → Rust unit tests
6. `flutter build apk --debug` → build verification

## Architecture Highlights

### Layer Model
```
UI (Flutter + Material 3)
├── Lightroom panel shell (default)
└── Snapseed gesture shell
    
Viewport (Flutter/Impeller)
├── Tile compositor
├── Zoom/pan transforms
└── Fragment-shader chain (grade.frag, lut.frag)
    
Edit Core (Pure Dart)
├── EditRecipe (Lightroom-aligned schema)
├── RecipeController (single source of truth)
└── Non-destructive operations

Engine (Rust via flutter_rust_bridge)
├── JPEG/HEIC decode
├── ROI tile decode
├── Color pipeline (demosaic, lens correction)
└── Full-res export (LUT + grading)
```

### Key Directories
- `app/lib/` – Flutter source (shaders in `app/shaders/`)
- `app/rust/src/` – Rust engine (API in `app/rust/src/api/`)
- `app/rust_builder/` – Flutter `rust_lib_tessera` package (Cargokit wrapper)
- `app/android/` / `app/ios/` – platform-specific native code

### Bridge Architecture
- Dart ↔ Rust boundary defined in `rust/src/api/*`
- Bindings generated to `lib/src/rust/` (Flutter)
- Config in `app/flutter_rust_bridge.yaml`
- Regenerate with `flutter_rust_bridge_codegen generate`

## Project Conventions

### Code Generation
- Engine API changes require bridge regeneration
- After editing `rust/src/api/*`, run `flutter_rust_bridge_codegen generate`

### Third-Party Management
- All external dependencies tracked in `THIRD_PARTY.md`
- New dependencies require THIRD_PARTY.md entry

### Testing Gotchas
- **Memory budget**: Tile LRU respects ~512MB device limit
- **Performance**: Debug Rust profile has 10-50x slower color/spatial math
- **Shader compilation**: `flutter build apk --debug` verifies shaders compile
- **Preview == Export**: Grading math lives once in Rust, shared by preview LUT and export path

### Release Process
- Trunk is `main`; feature branches: `feat/<issue>` or `fix/<issue>`
- Small, focused commits referencing issue numbers
- CI must pass before merging
- `flutter analyze`, `flutter test`, `cargo test/fmt/clippy` must all pass

## Migration Notes
- Application was renamed from `tessera` to `aperturex` in the Dart package
- Android `applicationId` (`com.devparadise.tessera`) and Rust crate (`rust_lib_tessera`) still carry historical name (pending rename)

## Documentation
- `docs/ARCHITECTURE.md` – Detailed layer model, data flow
- `docs/ROADMAP.md` – Phase priorities and exit criteria
- `docs/PARITY.md` – Feature parity against Snapseed/Lightroom
- `CONTRIBUTING.md` – TDD workflow and ground rules
- `THIRD_PARTY.md` – License compliance for all dependencies
