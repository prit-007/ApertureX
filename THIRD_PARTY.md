# Third-Party Components

ApertureX is licensed **GPL-3.0-or-later**. This file records the third-party
components we adopt or fork, their licenses, and the compatibility reasoning.
It is the human-readable companion to the machine license bundle that will ship
in the app (`flutter_licenses` / `LicenseRegistry`) once code exists.

> License-compatibility rule of thumb: permissive licenses (MIT, BSD, Apache-2.0)
> are **inbound-compatible** with a GPL-3 outbound project. The combined work is
> distributed under GPL-3; the original notices must be preserved.

---

## Adopted dependencies

| Component | Version | License | Use | Compatible |
|-----------|---------|---------|-----|------------|
| [`dynamic_color`](https://pub.dev/packages/dynamic_color) | ^2.1.0 | Apache-2.0 | Material You wallpaper theming (Android S+; seed fallback elsewhere) | ✅ |
| [`extended_image`](https://pub.dev/packages/extended_image) | ^10.1.0 | MIT | Gallery grid, pinch/pan gesture layer, `ExtendedRawImage.sourceRect` tile blits | ✅ |
| [`file_picker`](https://pub.dev/packages/file_picker) | ^11.0.3 | MIT | Native file picker for importing HALD CLUT PNGs | ✅ |
| [`flutter_rust_bridge`](https://pub.dev/packages/flutter_rust_bridge) | v2.x | MIT / Apache-2.0 | Dart ↔ Rust FFI codegen | ✅ |
| [`image`](https://pub.dev/packages/image) | ^4.12.0 | MIT | Pure-Dart PNG decode for HALD CLUT LUT import (ADR 0009) | ✅ |

Apache-2.0 and GPL-3.0 are mutually compatible (both are modern, patent-granting
licenses); the Apache NOTICE must be carried through, which we do here.

## Forked component

| Component | Upstream | Version pinned | License | Role |
|-----------|----------|----------------|---------|------|
| `pro_image_editor` (fork) | [`hm21/pro_image_editor`](https://github.com/hm21/pro_image_editor) | 14.13.1 | BSD-3-Clause | Base for the Material 3 grading toolbar / slider / state scaffolding |

**BSD-3-Clause obligations we must honor in the fork and its binary distribution:**

1. Retain the upstream copyright notice, the list of conditions, and the
   disclaimer in source and documentation.
2. Do **not** use the upstream author's or contributors' names to endorse or
   promote our fork without permission.
3. Reproduce the notice in the app's license screen / NOTICE bundle.

The fork's provenance, strip-list, and update cadence are specified in
[`docs/FORK-STRATEGY.md`](docs/FORK-STRATEGY.md).

> The upstream README and package metadata advertise sponsor links. These are
> upstream references retained for attribution; they are not endorsements of
> ApertureX.

---

## Reference-only (not linked, not copied)

The following are studied for ideas only. No code is copied, so no license
obligation attaches. If that ever changes, they move to the fork/adopt tables
above with their notices.

| Project | License | What we study |
|---------|---------|---------------|
| Image Toolbox | Apache-2.0 | Material 3 visual language / layout density (Kotlin + Compose) |
| Snapseed (proprietary) | — | The invisible gesture interaction model (behavioral reference only) |
| darktable | GPL-3.0 | Color-op ordering and non-destructive pipeline design |

---

## Machine-learning models (planned — ADR 0010)

No model ships yet. Every model added to the optional AI module **must** get a
row here — with its **weights** license verified (not just the code) — before it
is adopted. This is a hard gate (ADR 0010).

| Model | Purpose | Runtime | Code license | Weights license | Source | Status |
|---|---|---|---|---|---|---|
| _(none yet)_ | — | ONNX RT / ncnn | — | — | — | — |

Candidate models (verify each model's weights license before adoption):
MobileSAM / SAM 2 small (tap-select), U²-Net-style salient (auto subject), sky
segmentation, MODNet-class matting, Depth Anything V2 small (depth), YuNet (face,
MIT). Explicitly avoided: RMBG (non-commercial).

---

## License text availability

- Apache-2.0: https://www.apache.org/licenses/LICENSE-2.0
- MIT: https://opensource.org/license/mit
- BSD-3-Clause: https://opensource.org/license/bsd-3-clause
- GPL-3.0: see [`LICENSE`](LICENSE)
