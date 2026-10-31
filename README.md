# ApertureX

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Status](https://img.shields.io/badge/status-v0.3.7-blue.svg)](docs/ROADMAP.md)
[![Latest Release](https://img.shields.io/badge/release-v0.3.7-brightgreen.svg)](https://github.com/prit-007/ApertureX/releases/latest)
[![F-Droid](https://img.shields.io/badge/F--Droid-Ready%20for%20Publish-blue?logo=fdroid)](https://github.com/prit-007/ApertureX/releases/latest)
[![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Desktop-lightgrey.svg)](#)
[![Website](https://img.shields.io/badge/website-prit--007.github.io%2FApertureX-6BEAF7)](https://prit-007.github.io/ApertureX/)
[![100% Offline](https://img.shields.io/badge/100%25-Offline-green.svg)](#privacy)

**The mobile-native, non-destructive, 100% offline FOSS photo editor & darkroom — the Snapseed and Lightroom replacement the open-source community deserved.**

> *ApertureX* opens like a camera aperture and edits like a professional darkroom. It unifies **two swappable UIs over one non-destructive recipe**: a Lightroom-style precision panel inspector for studio fine-tuning and a Snapseed-style gesture HUD for lightning-fast thumb edits. Large RAWs and 200MP phone captures are processed through a **tile-based viewport with a zero-copy Rust engine**, delivering 120 FPS slider response without memory crashes.
>
> **100% on-device. Zero telemetry. Zero accounts. Zero subscriptions. You own your photos and your edits.**

<p align="center">
  <img src="app/icons/app_icon.png" alt="ApertureX app icon — a camera-aperture shutter mark on a dark field" width="192">
</p>

<p align="center">
  <a href="https://github.com/prit-007/ApertureX/releases/latest"><b>📥 Download Latest APK (v0.3.7)</b></a> •
  <a href="https://prit-007.github.io/ApertureX/"><b>🌐 Interactive Website &amp; Studio Tour</b></a> •
  <a href="docs/ROADMAP.md"><b>🗺️ Roadmap &amp; Features</b></a> •
  <a href="THIRD_PARTY.md"><b>📜 Open-Source Licenses</b></a>
</p>

---

## 🚀 Quick Install (Ready to Use Right Now)

ApertureX is production-ready for Android devices and available for sideloading, direct APK install, and F-Droid:

| Package | Architecture | Description | Download |
|---------|--------------|-------------|----------|
| **Universal APK** | ARM64 + ARMv7 + x86_64 | All-in-one signed APK compatible with any Android 8.0+ device | [**Download `app-release.apk`**](https://github.com/prit-007/ApertureX/releases/latest/download/app-release.apk) |
| **ARM64 APK** | `arm64-v8a` | Smallest download size optimized for modern phones and tablets | [**Download `app-arm64-v8a-release.apk`**](https://github.com/prit-007/ApertureX/releases/latest/download/app-arm64-v8a-release.apk) |
| **ARMv7 APK** | `armeabi-v7a` | Compatible with legacy 32-bit Android hardware | [**Download `app-armeabi-v7a-release.apk`**](https://github.com/prit-007/ApertureX/releases/latest/download/app-armeabi-v7a-release.apk) |
| **x86_64 APK** | `x86_64` | Intel/AMD Chromebooks and Android virtual device emulators | [**Download `app-x86_64-release.apk`**](https://github.com/prit-007/ApertureX/releases/latest/download/app-x86_64-release.apk) |
| **F-Droid** | Multi-ABI | Verified container build metadata (`docs/fdroid-metadata.yml`) | [Track F-Droid Publish #69](https://github.com/prit-007/ApertureX/issues/69) |

*iOS and Desktop (Linux GTK, macOS, Windows) can be compiled directly from source in minutes using standard Flutter and Cargo tooling.*

---

## 🌟 Why Photographers Choose ApertureX

### 1. Dual-UI Shells Over One Non-Destructive Recipe
- **Lightroom Panel Shell (Default):** Precision numeric sliders, tap-to-type input, RGB tone curves, per-channel tone curves, 3-way color grading wheels, and split-toning.
- **Snapseed Gesture Shell:** Vertical swipe to select parameters, horizontal drag to adjust, clean HUD overlay, and zero screen clutter.
- **Switch mid-edit with zero penalty:** Both shells read and write the exact same versioned `EditRecipe`.

### 2. 55+ Curated Master Presets & Searchable Looks Sheet
- **Cinema Masterworks:** *Oppenheimer*, *Interstellar*, *Pulp Fiction*, *Fight Club*, *La La Land*, *Blade Runner (1982 & 2049)*, *The Batman trilogy* (Bale, Pattinson, Affleck), *John Wick 1–4*, *The Terminator*, *Avatar*, *Ready Player One*, *The Matrix*, *Dunkirk*, *Inception*, *The Godfather*.
- **Anime & Studio Styles:** *Anime: Shinkai Sky*, *Anime: Spirited Away*, *Anime: Ghibli Garden*, *Anime: Neo-Tokyo Akira*, *Anime: 90s Retro Cel*, *Anime: Cyberpunk Edgerunners*.
- **Nature & Landscape Scenarios:** *Greenery Forest*, *Beach & Ocean*, *Alpine Mountains*, *Golden Outdoors*, *Dramatic Backlight*, *Action & Sports*.
- **Indian Cultural Heritage & Festive:** *Universal Brilliance*, *Royal Indian Wedding*, *Desi Festive: Diwali & Holi*, *Royal Heritage: Rajasthan*, *Kerala Monsoon & Backwaters*, *Bollywood Golden Hour*.
- **Legendary Analog Film Stocks:** *Leica M Monochrom*, *Vintage Kodachrome 64*, *Fuji Velvia 50*, *Cinestill 800T*, *Kodak Portra 160/400*, *Ilford HP5 Plus*.
- **Every preset includes:** Complete 3-way color grading wheels, 8-band HSL vectors, film grain/bloom, and Depth Anything V2 optical parameters.

### 3. Depth Anything V2 Monocular Bokeh & 7 Optical Apertures
- Powered by bundled **Depth Anything V2 ONNX INT8** monocular depth estimation.
- Physical thin-lens **Circle-of-Confusion (CoC)** simulation baked in Rust.
- 7 parametric iris blade bokeh apertures: **Circle**, **Pentagon**, **Hexagon**, **Septagon**, **Cat's Eye (Anamorphic)**, **Soap Bubble (Optical Bloom)**, and **Swirl (Petzval)**.
- Real-time false color **Depth Visualizer Heatmap** overlay for focal plane inspection.

### 4. Complete Local Masking Stack with Boolean Algebra
- **10 Mask Kinds:** AI Subject, AI Sky, Inverted Background, Brush, Auto-Brush, Linear Gradient, Radial Gradient, Zone-System Luminance, Color-Range (HSV), and Depth Range.
- **Stylus & Palm Rejection:** Full pressure sensitivity (`event.pressure` 0.0–1.0), hardware device filtering, and inverted-stylus eraser mode.
- **Auto-Brush Edge Snapping:** Euclidean color-distance gating stops strokes automatically at subject boundaries.
- **Mask Group Algebra:** Add, Subtract, and Intersect masks with 0–200% Amount scaling and per-mask 3-way color wheels.

### 5. Pro Studio Tools & Colorist Workflows
- **Targeted Output Sharpening:** Media-specific convolution kernels for Screen (3×3 unsharp), Print Matte (5×5 broad high-boost), Print Glossy (3×3 micro-contrast), and Web Compression.
- **Upright Auto Geometry:** Sobel vertical convergence detection automatically straightens horizons and rectifies architectural keystone perspective.
- **Smart Collections & Perceptual Culling:** Multi-rule catalog queries (ratings, flags, EXIF telemetry), 64-bit dHash duplicate clustering, Laplacian variance blur detection, and YuNet closed-eye culling.
- **Pro Print Studio:** Pure-Dart vector PDF 1.4 generator with multi-up contact sheets and printer ICC profile soft-proofing.
- **Video Color Studio:** Non-destructive 3D LUT video grading and Hollywood `.CUBE` LUT export for DaVinci Resolve and Premiere Pro.
- **C2PA Cryptographic Provenance:** On-device Content Credentials embedding verifiable digital authorship and edit transparency manifests.
- **Studio Tethered Shooting:** USB/PTP live telemetry streaming, remote shutter release, and automatic recipe application.

---

> **Status: v0.3.7 (Release).** Verified across 1,360+ Dart tests, 363 Rust tests (including 7 golden fixture corpus tests), and 0 analyzer issues. See [`docs/ROADMAP.md`](docs/ROADMAP.md), [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), and [`docs/PARITY.md`](docs/PARITY.md).

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
| [`docs/adr/`](docs/adr/) | Architecture Decision Records 0001–0025 |
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
flutter build linux --release     # Linux GTK bundle (host deps: ninja-build, cmake, libgtk-3-dev)
flutter build windows --release   # Windows host only
flutter build macos --release     # macOS host only
```

The golden-image RAW fixtures in `app/rust/tests/golden_fixtures/` are tracked
with **Git LFS** — a fresh clone needs `git lfs install` once (CI's `actions/checkout`
does it automatically).

The Dart↔Rust bridge is generated by `flutter_rust_bridge_codegen`. After changing `rust/src/api/*`, regenerate the bindings with `flutter_rust_bridge_codegen generate`.

### App icon

The launcher icon is generated from two committed 1024×1024 masters in
[`app/icons/`](app/icons/): `app_icon.png` (the full-colour shutter mark) and
`app_icon_monochrome.png` (a white silhouette for Android 13+ themed icons).
Everything else — Android legacy mipmaps, adaptive-icon layers, the iOS
`AppIcon.appiconset`, the Windows `app_icon.ico`, and the macOS app icon set —
is produced by
[`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons)
from the config block in [`app/pubspec.yaml`](app/pubspec.yaml). After editing
a master, regenerate and commit the outputs:

```sh
cd app
dart run flutter_launcher_icons
```

Linux has no `flutter_launcher_icons` support, so the window icon is a manual
re-copy of the master after each regeneration (the top-level
`linux/CMakeLists.txt` installs it into `bundle/data/`, and
`gtk_window_set_icon_from_file` loads it at startup):

```sh
cp icons/app_icon.png linux/runner/icon.png   # from app/
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

## Creators & Organization — Developer's Paradise

ApertureX is engineered and maintained by **Developer's Paradise**, an open-source software collective dedicated to building professional-grade creative software with zero compromises on privacy, performance, or user ownership.

| Contributor | Focus & Contribution |
|-------------|----------------------|
| **Prit Vasani** | **Lead Architect & Creator** — Dual-UI shells, zero-copy Rust engine, Depth Anything V2 monocular bokeh, 55+ master preset catalog, and Look QR open standard. |
| **Nilay** | AI/ML Models & Neural Inference |
| **Rajvi Adesara** | User Experience & Design Ergonomics |
| **Vivek Khunt** | Graphics & Shaders Pipeline |
| **Bhargav** | Motion & Interactive Animations |
| **Meet** | Material 3 Component Systems |

---

## Contributing

Development is under way. Design review, ADR feedback, and identification of prior art are still welcome, as are bug reports and PRs. The project follows a trunk-`main` + feature-branch workflow with green CI as the bar; see [`docs/ROADMAP.md`](docs/ROADMAP.md) for current phase priorities.

---

## License

GNU General Public License v3.0 — see [`LICENSE`](LICENSE). Third-party components are documented in [`THIRD_PARTY.md`](THIRD_PARTY.md).
