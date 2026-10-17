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
| [`drift`](https://pub.dev/packages/drift) | ^2.35.2 | MIT | Local SQLite database abstraction & reactive query layer for catalog and edits gallery | ✅ |
| [`extended_image`](https://pub.dev/packages/extended_image) | ^10.1.0 | MIT | Gallery grid, pinch/pan gesture layer, `ExtendedRawImage.sourceRect` tile blits | ✅ |
| [`file_picker`](https://pub.dev/packages/file_picker) | ^13.1.0 | MIT | Native SAF file picker for importing HALD CLUT PNGs (federated: `android_file_picker` etc.; no Android permissions required — SAF user grant) | ✅ |
| [`flutter_rust_bridge`](https://pub.dev/packages/flutter_rust_bridge) | v2.x | MIT / Apache-2.0 | Dart ↔ Rust FFI codegen | ✅ |
| [`image`](https://pub.dev/packages/image) | ^4.12.0 | MIT | Pure-Dart PNG decode for HALD CLUT LUT import (ADR 0009) | ✅ |
| [`jpeg-encoder`](https://crates.io/crates/jpeg-encoder) | ^0.7.1 | (MIT OR Apache-2.0) AND IJG | Rust JPEG encode for full-res export | ✅ |
| [`rawler`](https://crates.io/crates/rawler) | ^0.8.0 | LGPL-2.1 | Pure-Rust RAW/DNG decode (ADR 0005, `rawler`-first) | ✅ |
| [`share_plus`](https://pub.dev/packages/share_plus) | ^13.3.1 | BSD-3-Clause | System share sheet for exported JPEGs and activity logs | ✅ |
| [`sqlite3_flutter_libs`](https://pub.dev/packages/sqlite3_flutter_libs) | ^0.6.0 | MIT | Bundles latest native SQLite binary across Android / iOS platforms | ✅ |
| [`qr_flutter`](https://pub.dev/packages/qr_flutter) | ^4.1.0 | BSD-3-Clause | QR code generation and rendering for Look/QR open standard sharing | ✅ |
| [`zxing2`](https://pub.dev/packages/zxing2) | ^0.2.4 | Apache-2.0 | Pure-Dart port of ZXing for offline QR code detection and decoding from image buffers | ✅ |
| [`miniz_oxide`](https://crates.io/crates/miniz_oxide) | ^0.8.9 | MIT OR Zlib OR Apache-2.0 | Pure-Rust DEFLATE decompression for watermark PNG decoding & C2PA payload decompression | ✅ |
| [`zune-jpeg`](https://crates.io/crates/zune-jpeg) | ^0.5.15 | MIT OR Apache-2.0 OR Zlib | Rust JPEG decode for the ROI/proxy path | ✅ |

Apache-2.0 and GPL-3.0 are mutually compatible (both are modern, patent-granting
licenses); the Apache NOTICE must be carried through, which we do here.

`rawler` is **LGPL-2.1**. LGPL-2.1 §3 permits converting the covered code to
GPL-2.0-or-later, which is compatible with this project's GPL-3.0-or-later
outbound license, so the combined work may be distributed under GPL-3 while
preserving rawler's notice.

`jpeg-encoder` is `(MIT OR Apache-2.0) AND IJG`: it embeds the IJG
(Independent JPEG Group) JPEG reference implementation, whose permissive license
permits use in free and proprietary software provided the IJG notice is carried.
The IJG notice must be included in the app's license bundle.

### Optional native fallback (LibRaw / lensfun) — not in the default build

`raw-libraw` (feature) links the Rust `libraw` crate (MIT) against the underlying
C++ **LibRaw** library (**LGPL-2.1/CDDL**). LibRaw is **not** part of the default
build (the default is pure-Rust `rawler`, see ADR 0005). If the optional feature
is ever shipped, LibRaw — and any lensfun-class profile library (**LGPL**) —
**must be dynamically linked** (`.so`/`.dylib`) so the GPL-3 app can link it
compatibly, with notices carried through. This packaging work is tracked in issue
#67; the `THIRD_PARTY.md` rows for those native libs are added only when the
feature is enabled.

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
| U²-NetP | Salient object / subject mask | ONNX RT / in-tree | Apache-2.0 | Apache-2.0 | xuebinqin/U-2-Net | Adopted (#87) |

Candidate models (verify each model's weights license before adoption):
MobileSAM / SAM 2 small (tap-select), U²-Net-style salient (auto subject), sky
segmentation, MODNet-class matting, Depth Anything V2 small (depth), YuNet (face,
MIT). Explicitly avoided: RMBG (non-commercial).

---

## License text availability

- Apache-2.0: https://www.apache.org/licenses/LICENSE-2.0
- MIT: https://opensource.org/license/mit
- BSD-3-Clause: https://opensource.org/license/bsd-3-clause
- Zlib: https://opensource.org/license/zlib
- IJG (libjpeg): https://www.ijg.org/files/README (IJG license)
- LGPL-2.1: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html
- GPL-3.0: see [`LICENSE`](LICENSE)
