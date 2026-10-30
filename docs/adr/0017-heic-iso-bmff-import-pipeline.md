# ADR 0017 — HEIC / AVIF ISO-BMFF Import Pipeline

- **Status:** Accepted
- **Date:** 2026-10-30
- **Deciders:** Developer's Paradise
- **Consults:** ADR 0001 (Flutter UI & Rust Engine), ADR 0004 (GPL-3 & F-Droid Distribution), Issue #128

---

## 1. Context

Modern mobile camera rolls frequently store photographs in High Efficiency Image File Format (HEIF/HEIC) and AV1 Image File Format (AVIF). While platform native photo pickers on iOS and Android can transcode these to JPEG upon selection, this approach introduces significant limitations:
- **Loss of Source Data Fidelity**: Recompressing to lossy 8-bit JPEG degrades subtle tonal gradients and introduces compression artifacts.
- **Transcoding Overhead**: Transcoding on device causes observable delays when opening the photo editor.
- **Desktop Incompatibility**: Desktop targets (Linux, Windows, macOS) lack unified OS-level transcoding mechanisms, breaking folder-backed gallery workflows.
- **Dependency & Licensing Constraints**: Traditional C/C++ libraries (such as `libheif` or `libde265`) introduce complex patent pooling constraints and difficult F-Droid reproducible cross-compilation builds.

## 2. Decision

Implement an in-tree, zero-dependency ISO-BMFF (ISO Base Media File Format) parser and embedded payload extractor in `AxEngine.decodeHeicRgba()` (`app/lib/engine/engine.dart`):

1. **Box Header & Spatial Extent Extraction**:
   - Parse top-level and nested ISO-BMFF boxes (`ftyp`, `meta`, `hdlr`, `iprp`, `ipco`, `ispe`).
   - Read spatial dimension extents (`ispe` FullBox) directly to establish native canvas aspect ratio and orientation bounds before full pixel rasterization.

2. **Embedded Proxy & Payload Extraction**:
   - Scan container segments for embedded master/preview bitstreams (JPEG/EXIF).
   - If an embedded JPEG preview is found, extract and decode it directly into an uncompressed RGBA pixel buffer.
   - For standalone HEIC bitstreams, fall back to pure-Dart bitstream decompression.

3. **Seam Integration**:
   - Route `ImageFormat.heic` and `ImageFormat.avif` in `AxEngine.decodeImageRgba` directly to `AxEngine.decodeHeicRgba`.
   - Update `FolderGallerySource` (`loadThumbnail` and `loadPreview`) to support `.heic`, `.heif`, and `.avif` extensions out-of-the-box across mobile and desktop.

## 3. Consequences

### Positive
- **100% Offline & F-Droid Compliant**: Zero external C/C++ shared library dependencies; builds out of the box without special NDK/toolchain flags.
- **Cross-Platform Parity**: Identical decoding behavior across Android, iOS, macOS, Linux, and Windows.
- **Fast Preview Generation**: Extracts embedded JPEG previews in milliseconds, enabling smooth gallery scrolling for HEIC-heavy photo libraries.

### Negative
- Ultra-high resolution (>48 MP) full-frame raw bitstreams in HEVC main profile without embedded previews require auxiliary hardware acceleration.
