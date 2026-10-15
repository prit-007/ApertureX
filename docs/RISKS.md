# Tessera — Risks

The four "walls" (why FOSS mobile editors don't exist), plus delivery risks, with
the mitigation each one demands. Severity is an estimate of how likely the risk
is to sink a phase.

---

## Wall 1 — RAW decoding

**Risk:** RAW support requires heavy native libraries; compiling them for mobile
ARM without wrecking battery/build times is hard. Wrong engine choice creates a
lock-in we cannot escape cheaply.

- **Likelihood:** high · **Impact:** high
- **Status:** *substantially retired.* ADR 0005 decided **rawler-first** (pure
  Rust, LGPL-2.1, F-Droid from-source friendly); LibRaw is optional behind
  `--features raw-libraw`. `raw::decode`/`metadata`/`color`/`lens` implement
  Bayer/CFA demosaic, camera matrices, orientation, and DCraw-class lens
  primitives, with RAW ROI + export wired through Dart. **Remaining risk:** real
  multi-vendor corpus coverage, and that LibRaw/lensfun (if ever enabled) are
  LGPL and must be dynamically linked (issue #67).
- **Mitigations:**
  - Engine choice deferred behind the fixed `ImageSource` trait (ADR 0005) —
    **done**; either implementation drops in.
  - Ship the embedded-preview fast path first so RAW "works" before full
    demosaic lands. *(Deferred deliberately: a camera preview as the graded base
    would break preview==export; must be a transient placeholder.)*
  - Test against a fixed multi-vendor RAW corpus in CI. *(Pending — issue #19.)*

## Wall 2 — GPU shaders

**Risk:** Flutter's fragment-shader surface is constrained (no UBO/SSBO, no
uint/bool, `sampler2D` only, GLES y-flip). `ImageFilter.shader` is Impeller-only.
A shader that works on one Android GPU may break or misbehave on another;
compilation can stall first use.

- **Likelihood:** medium · **Impact:** medium
- **Status:** *partially retired.* `grade.frag` + a 65³ LUT-atlas shader hold
  display refresh on a mid-tier Android device (P-1 met). The Rust-owned
  `ANativeWindow` **zero-copy texture** path is now **mounted by the viewport on
  Android** (`PreviewSurface`, issue #54): delivery switches to the shader path
  while compare/peek crossfades or imported-LUT sessions are active and returns
  to zero-copy when idle. The shader/atlas path remains the universal fallback;
  the remaining gap is **no iOS texture registration**.
- **Mitigations:**
  - Constrain the shader dialect to the documented safe subset; centralize UV
    handling (incl. GLES un-flip) in one helper.
  - Feature-detect Impeller-only paths; provide non-shader fallbacks.
  - Precach shader programs at startup; reuse `FragmentShader` instances.
  - Carry golden-image tests across at least two GPU vendor families.
  - ~~Finish the zero-copy texture wiring (#54)~~ **landed on Android**
    (`PreviewSurface` + delivery switching); remaining: iOS texture registration
    or an explicit Android-only gate, plus cross-vendor on-device validation.
  - P-1 spike is the early kill-switch: if the shader path cannot hold frame
    rate, pivot to `flutter_gpu` before committing.

## Wall 3 — Memory / huge images

**Risk:** 200 MP images blow past Flutter's `ImageCache` (default ~100 MB),
Impeller's max texture size (8192–16384 px, else silent downscale), and the OS
memory killer. A single full-res decode can be hundreds of MB.

- **Likelihood:** high · **Impact:** high
- **Status:** *open, partly mitigated.* The tile compositor + byte-budgeted LRU exist; native ROI
  decoders and the tile pyramid do **not** (JPEG/RAW ROI currently decode-full-
  then-crop), so a >100 MP open still materializes more than it should. The
  banded, overlap-padded, cancellable export is **wired end-to-end to Dart**
  (`export_pipeline.rs` → `exportFull` → editor Cancel, #68 wiring done), but it
  has **no hard memory cap**: `jpeg_encoder` has no streaming API, so the peak
  stays ~2 frames (source + output) regardless of banding.
- **Mitigations:**
  - Tile-based viewport with ROI decode; **never** materialize full-res as one
    texture (ARCHITECTURE §5). *(Native ROI + pyramid pending — issue #16.)*
  - Byte-budgeted LRU tile cache + device-tier probe; cap decode parallelism.
  - Streamed export that frees tiles after encode; hard peak-RSS cap.
  - Explicit handling of `ImageCache.maxByteSize` to avoid thrash.
  - Regression benchmark on a low-tier device in CI (>50 MP export RSS gate).

## Wall 4 — The FOSS UI curse

**Risk:** A capable engine with an unpleasant UI fails the same way Krita-on-
Android does. Gesture interactions that fight pan/zoom feel broken.

- **Likelihood:** medium · **Impact:** high
- **Mitigations:**
  - Material 3 / Material You visual system for a native-feeling shell.
  - A dedicated, unit-tested gesture FSM with axis-lock and gesture-arena
    arbitration (ADR 0006) — not ad-hoc `GestureDetector`s.
  - Fork a proven editor UI (`pro_image_editor`) rather than build chrome from
    zero.
  - P-1 spike validates feel before P1 invests in the viewport.

---

## Delivery risks

| Risk | L/I | Mitigation |
|------|-----|------------|
| Team has no prior Rust experience | high/med | `flutter_rust_bridge` does the glue; start with a thin Rust surface; pair in P0. |
| Fork drift from upstream `pro_image_editor` | med/med | Pinned tag, documented strip-list, scheduled rebases (see FORK-STRATEGY.md). |
| Scope creep (AI, video, cloud) | high/high | Explicit non-goals in README; new scope requires an ADR. |
| GPU fragmentation across Android vendors | med/med | Safe shader subset + fallbacks + multi-vendor goldens. |
| Battery/thermal on long edits | med/med | Progressive refinement, throttle background decode, avoid per-frame LUT rebuilds. |
| No initial Rust unit-test harness | med/low | CI adds `cargo test`/`clippy` in P0. — **retired** |
| F-Droid reproducibility | med/med | Follow the org's existing `nook` F-Droid recipe; pin toolchains (ADR 0004). |
| **Built-but-unwired features** (lens corrections #66, brush masks #63, sidecar #61) | high/med | Each has a tracked issue; verify "wired + demoable + tested" before closing — presence of a Rust function is not shipped. |
| **LGPL surface if LibRaw/lensfun enabled** | med/high | Dynamically link (`.so`/`.dylib`) + notices; keep rawler the default (issue #67). |

---

## Kill criteria / pivots

Revisit the architecture if any of these hold at the end of a phase:

- P-1: shaders cannot hold frame rate → pivot render path (e.g. `flutter_gpu`).
  *(Not triggered: shader path holds refresh; zero-copy display is wired on
  Android (#54) with the shader path as the fallback.)*
- P1: ROI decode on low-tier devices cannot meet budget at any tile size →
  re-scope huge-image support (proxy-only beyond a megapixel ceiling).
  *(Watch item: native ROI #16 not landed yet.)*
- P3: RAW ROI decode is infeasible on the target hardware → ship RAW as
  proxy-edit + deferred full decode at export. *(rawler ROI is decode+crop;
  revisit if tiles are needed.)*
