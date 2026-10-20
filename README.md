# ApertureX

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Status](https://img.shields.io/badge/status-v0.2.4-blue.svg)](docs/ROADMAP.md)
[![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS-lightgrey.svg)](#)
[![Website](https://img.shields.io/badge/website-prit--007.github.io%2FApertureX-6BEAF7)](https://prit-007.github.io/ApertureX/)
[![100% Offline](https://img.shields.io/badge/100%25-Offline-green.svg)](#privacy)

**A mobile-native, non-destructive, free-and-open-source photo editor — the Snapseed/Lightroom replacement the FOSS world never built.**

> *ApertureX* — a photo editor that opens like a camera aperture and edits like a darkroom. It ships **two UIs over one recipe**: a Lightroom-style precision panel UI (default) and a Snapseed-style gesture UI. Internally, every large photo is still edited as a field of **tiles**, never one giant bitmap — the engine's atomic unit.

<p align="center">
  <img src="app/icons/app_icon.png" alt="ApertureX app icon — a camera-aperture shutter mark on a dark field" width="192">
</p>

> **Status: v0.2.4 (Release).** Both UI shells
> (Lightroom panels + Snapseed gestures) run over one shared recipe; the Rust
> engine carries the full color/spatial/geometry pipeline plus the **complete
> local-adjustment stack**: 8 mask kinds (linear/radial/luminance/brush/bitmap/
> color-range + AI subject/sky), **mask group algebra** (Add/Subtract/
> Intersect, ADR 0013),
> Amount 0–200%, Zone-System luminosity masks, per-mask 3-way color wheels +
> Highlights/Shadows, and a guided-filter **Refine Edge brush**.
>
> **Industry-Grade Pro Capabilities:**
> - **ApertureX Neural Forge (BYOM Plugins):** Declarative ONNX plugins via GitHub/HuggingFace links with auto-generated native parameter sliders.
> - **Lossless DNG & CFA Passthrough + 16-bit TIFF (#79):** Zero-loss Bayer CFA raw preservation with injected non-destructive XMP metadata, plus full-edit 16-bit TIFF export.
> - **Lensfun Optics Database & EXIF Inspector (#85):** Hardware camera/lens profile matching with distortion/vignette compensation and deep EXIF shooting telemetry.
> - **YuNet + U²-NetP AI Subject Detection:** Face-first auto-subject placement runs entirely on-device through ONNX Runtime 1.24.3, with saliency fallback.
> - **ApertureX Academy & Interactive Guide:** Full tool-by-tool masterclasses, search filter, and pro workflow tips.
> - **In-App GitHub Releases OTA Updater:** Seamless automatic updates with live progress bar and release notes changelog.
> - **Staggered Media Gallery & Virtual Copies:** Google Photos-style date-grouped staggered layout with dedicated edited-versions catalog.
> - **Selective Recipe Copy/Paste:** Granular control over which adjustment categories to batch paste across photos.
> - **Translucent Glassmorphism:** Real-time backdrop-blur HUD overlays that preserve uninhibited photo viewing.
> - **Zero-Telemetry Offline Integrity:** 100% local SQLite/Drift database, zero network calls unless explicitly requested by the user.
>
> Verified across 1047 Dart tests, 353 Rust tests (including 7 golden fixture corpus tests), and 0 analyzer lints. See [`docs/ROADMAP.md`](docs/ROADMAP.md), [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), and [`docs/PARITY.md`](docs/PARITY.md).

> **Naming:** the product is **ApertureX** and every identifier is canonical:
> Dart package `aperturex`, applicationId/bundle id `com.devparadise.aperturex`,
> Rust crate `rust_lib_aperturex`. The historical name survives only in git
> history and ADRs.

---

## Privacy

**100% Offline. Zero Cloud Analytics. No AI training on your photos. You own
your data.**

ApertureX has no accounts, no servers, no telemetry and no analytics SDK —
every edit, export and log stays on your device. The claim is *enforced*, not
just written down: [`app/test/core/offline_guard_test.dart`](app/test/core/offline_guard_test.dart)
fails CI if a network or analytics package (`http`, `dio`, `firebase_*`,
`sentry_*`, `supabase`, …) is ever added to `pubspec.yaml`, unless it is
consciously whitelisted with a written justification. The same line is shown
in-app under **Settings → About**.

---

## Why this exists

The mobile photo-editing landscape is a ghost town for free software:

- **Krita** runs on Android but ships a desktop UI that is unusable on a phone.
- **Phimp.me** is abandoned and buggy.
- A fluid, touch-first, **non-destructive** editor with a real color pipeline? It does not exist as FOSS.

Four technical walls explain why nobody has built it. ApertureX is architected to climb all four:

| # | Wall | ApertureX's answer |
|---|------|------------------|
| 1 | RAW decoding is heavy C/C++ (`LibRaw`, `lensfun`) | A Rust core behind `flutter_rust_bridge`, with a pluggable `RawDecoder` |
| 2 | Real-time adjustment needs GPU shaders | A chained GLSL pipeline via Flutter/Impeller fragment shaders |
| 3 | 48–200 MP images blow the OS texture/RAM budget | A **tile-based viewport** with ROI decode + LRU byte budget |
| 4 | FOSS UIs are built for function, not feel | Material 3 + a dedicated Snapseed-style **gesture FSM** |

---

## Architecture at a glance

```
┌─────────────────────────────────────────────────────────────┐
│ UI (Flutter, Material 3)                                     │
│   gesture FSM · tool trays · film strip · histogram          │
├─────────────────────────────────────────────────────────────┤
│ Viewport (Flutter/Impeller)                                  │
│   tile compositor · zoom/pan · fragment-shader chain · cache │
├─────────────────────────────────────────────────────────────┤
│ Edit core (Dart)                                             │
│   non-destructive recipe · undo/redo · mask groups · presets  │
│   · sidecars (project + XMP)                                  │
├─────────────────────────────────────────────────────────────┤
│ Engine (Rust via flutter_rust_bridge v2)                     │
│   decode (RAW/JPEG) · ROI tiles · demosaic · colour ·        │
│   lens correction · masks/local adj · retouch · export       │
├─────────────────────────────────────────────────────────────┤
│ Platform glue                                                │
│   scoped storage · camera · share · F-Droid metadata         │
└─────────────────────────────────────────────────────────────┘
```

Full detail: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## Documentation map

| Doc | Contents |
|-----|----------|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Layers, data flow, tile engine, shader pipeline, dual-UI shells, recipe schema, masking, ML module, memory budget |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Phases P-1→P6 + P2.5/P3.5, v0.1 ship gate, exit criteria |
| [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md) | Current status audit, file-by-file workstreams, perf tiers, and the issue carrying each remaining task |
| [`docs/PARITY.md`](docs/PARITY.md) | Feature parity matrix (Snapseed/Lightroom × status × phase) |
| [`docs/RISKS.md`](docs/RISKS.md) | The four walls, each risk, and its mitigation |
| [`docs/GOLDEN.md`](docs/GOLDEN.md) | Golden-image corpus, delta E tolerance gates, update workflow |
| [`docs/FORK-STRATEGY.md`](docs/FORK-STRATEGY.md) | How we fork and maintain `pro_image_editor` |
| [`docs/adr/`](docs/adr/) | Architecture Decision Records 0001–0014 |
| [`THIRD_PARTY.md`](THIRD_PARTY.md) | Third-party components, licenses, ML-model ledger, notices |

---

## Building the app

The application lives in [`app/`](app/) (Flutter UI + Rust engine). You need Flutter 3.44.x, the Android SDK (and/or Xcode for iOS), and a Rust toolchain.

```sh
cd app
flutter pub get
flutter run                # on a connected device/emulator
flutter test               # Dart unit tests
(cd rust && cargo test)    # Rust unit tests
flutter build apk          # Android APK (cargokit cross-compiles the Rust crate)
flutter build ios --no-codesign   # unsigned iOS build (Xcode required)
```

The golden-image RAW fixtures in `app/rust/tests/golden_fixtures/` are tracked
with **Git LFS** — a fresh clone needs `git lfs install` once (CI's `actions/checkout`
does it automatically).

The Dart↔Rust bridge is generated by `flutter_rust_bridge_codegen`. After changing `rust/src/api/*`, regenerate the bindings with `flutter_rust_bridge_codegen generate`.

### App icon

The launcher icon is generated from two committed 1024×1024 masters in
[`app/icons/`](app/icons/): `app_icon.png` (the full-colour shutter mark) and
`app_icon_monochrome.png` (a white silhouette for Android 13+ themed icons).
Everything else — Android legacy mipmaps, adaptive-icon layers, and the iOS
`AppIcon.appiconset` — is produced by
[`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons)
from the config block in [`app/pubspec.yaml`](app/pubspec.yaml). After editing
a master, regenerate and commit the outputs:

```sh
cd app
dart run flutter_launcher_icons
```

## CI & releases

Continuous by design ([`.github/workflows/ci.yml`](.github/workflows/ci.yml),
modelled on [`nook`](https://github.com/prit-007/nook)):

- **Every push/PR** — `flutter analyze` + Dart tests, `cargo fmt/clippy/test`,
  then signed per-ABI + universal release APKs built inside the **F-Droid
  buildserver container** (GitHub artifacts and F-Droid builds share one recipe
  and the same `tool/ci/*` scripts), plus an **unsigned `flutter build ios` on
  macOS** (deployment target 14.0; the job auto-retries with `xcodebuild -v`
  so hidden failures surface instead of Flutter's canned Xcode diagnosis).
- **Tags** — push `vX.Y.Z` (must match `app/pubspec.yaml` and a
  `## [X.Y.Z]` section in [`app/CHANGELOG.md`](app/CHANGELOG.md)) and CI
  publishes a GitHub Release with the APKs and the changelog notes.
- **Signing** — maintainers run [`tool/ci/make_release_keystore.sh`](tool/ci/make_release_keystore.sh)
  once; the keystore stays on their machine (gitignored, back it up) and the
  passwords live as secrets on the `ci` environment. Builds without secrets
  stay unsigned, so fork PRs never break.
- **F-Droid** — the metadata draft is [`docs/fdroid-metadata.yml`](docs/fdroid-metadata.yml);
  submission tracked in [#69](https://github.com/prit-007/ApertureX/issues/69).

---

## Scope

**In scope (v1):** Android + iOS. Non-destructive editing. JPEG/PNG/HEIC import. RAW import (phased). Tile-based viewport for very large images. Material You theming. GPL-3.0, F-Droid-ready.

**Out of scope (v1):** web and desktop targets, cloud sync, accounts, telemetry, AI generative features.

---

## Team — Developer's Paradise

| Name | Role |
|------|------|
| **Prit Vasani** | Builder |
| **Nilay** | AI/ML |
| **Rajvi Adesara** | UX |
| **Vivek Khunt** | Game Dev |
| **Bhargav** | Animation |
| **Meet** | UI |

---

## Contributing

Development is under way. Design review, ADR feedback, and identification of prior art are still welcome, as are bug reports and PRs. The project follows a trunk-`main` + feature-branch workflow with green CI as the bar; see [`docs/ROADMAP.md`](docs/ROADMAP.md) for current phase priorities.

---

## License

GNU General Public License v3.0 — see [`LICENSE`](LICENSE). Third-party components are documented in [`THIRD_PARTY.md`](THIRD_PARTY.md).
