# ApertureX

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Status](https://img.shields.io/badge/status-v0.1%20prep-blue.svg)](docs/ROADMAP.md)
[![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS-lightgrey.svg)](#)

**A mobile-native, non-destructive, free-and-open-source photo editor — the Snapseed/Lightroom replacement the FOSS world never built.**

> *ApertureX* — a photo editor that opens like a camera aperture and edits like a darkroom. It ships **two UIs over one recipe**: a Lightroom-style precision panel UI (default) and a Snapseed-style gesture UI. Internally, every large photo is still edited as a field of **tiles**, never one giant bitmap — the engine's atomic unit.

> **Status: pre-v0.1 (P1–P2 in progress).** Both UI shells (Lightroom panels +
> Snapseed gestures) and the bulk of the edit engine are built: a Rust
> color/spatial/geometry/mask pipeline, a 60fps preview (proxy-resolution + split
> bakes), crop, batch gallery, presets/LUT import, and on-device offline activity
> logs. The **banded full-res export** is now wired end-to-end (single Rust call
> with cancel). Several other parts are **built but not yet wired end-to-end** —
> the zero-copy preview texture, native ROI tiles for >100 MP, brush masks,
> sidecar persistence, and RAW lens corrections — each tracked by a
> GitHub issue. See [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md)
> for the current status and gaps, [`docs/ROADMAP.md`](docs/ROADMAP.md) for phase
> gates, and the [`docs/PARITY.md`](docs/PARITY.md) ledger.

> **Naming:** the product is **ApertureX**. The Dart package is now
> `aperturex`; the Android `applicationId` (`com.devparadise.tessera`) and the
> Rust crate (`rust_lib_tessera`) still carry the historical name and are the
> remaining rename step (changing the applicationId would break existing
> installs/keys).

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
│   non-destructive recipe · undo/redo · presets · sidecars    │
├─────────────────────────────────────────────────────────────┤
│ Engine (Rust via flutter_rust_bridge v2)                     │
│   decode (RAW/JPEG/HEIC) · ROI tiles · demosaic · color ·    │
│   lens correction · full-res export                          │
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
| [`docs/FORK-STRATEGY.md`](docs/FORK-STRATEGY.md) | How we fork and maintain `pro_image_editor` |
| [`docs/adr/`](docs/adr/) | Architecture Decision Records 0001–0011 |
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
```

The Dart↔Rust bridge is generated by `flutter_rust_bridge_codegen`. After changing `rust/src/api/*`, regenerate the bindings with `flutter_rust_bridge_codegen generate`.

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
