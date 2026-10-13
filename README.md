# Tessera

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Status: Design](https://img.shields.io/badge/status-design-orange.svg)](#status)
[![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS-lightgrey.svg)](#)

**A mobile-native, non-destructive, free-and-open-source photo editor — the Snapseed/Lightroom replacement the FOSS world never built.**

> *Tessera* (plural *tesserae*) is the individual tile of a mosaic. It is also the atomic unit of this app's rendering engine: every large photo is edited as a field of tiles, never as one giant bitmap.

> **Status: design.** This repository currently contains **planning documents only** — no application code. See [`docs/ROADMAP.md`](docs/ROADMAP.md).

---

## Why this exists

The mobile photo-editing landscape is a ghost town for free software:

- **Krita** runs on Android but ships a desktop UI that is unusable on a phone.
- **Phimp.me** is abandoned and buggy.
- A fluid, touch-first, **non-destructive** editor with a real color pipeline? It does not exist as FOSS.

Four technical walls explain why nobody has built it. Tessera is architected to climb all four:

| # | Wall | Tessera's answer |
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
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Layers, data flow, tile engine, shader pipeline, edit model, memory budget |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | P-1 spike + phases P0–P6 with exit criteria |
| [`docs/RISKS.md`](docs/RISKS.md) | The four walls, each risk, and its mitigation |
| [`docs/FORK-STRATEGY.md`](docs/FORK-STRATEGY.md) | How we fork and maintain `pro_image_editor` |
| [`docs/adr/`](docs/adr/) | Architecture Decision Records 0001–0007 |
| [`THIRD_PARTY.md`](THIRD_PARTY.md) | Third-party components, licenses, notices |

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

This is currently a design effort. Design review, ADR feedback, and identification of prior art are welcome. The implementation contribution guide will land with phase P0.

---

## License

GNU General Public License v3.0 — see [`LICENSE`](LICENSE). Third-party components are documented in [`THIRD_PARTY.md`](THIRD_PARTY.md).
