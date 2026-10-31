# ADR 0025 — Smart Collections, Perceptual Hash Duplicate Detection, Photo Quality Culling, and Auto-Import Folder Watching

- **Status:** Accepted
- **Date:** 2026-10-31
- **Deciders:** Developer's Paradise
- **Consults:** ADR 0014 (Library Catalog SQLite Drift), ADR 0023 (Studio Tethered Shooting)

---

## 1. Context

Large photo libraries (thousands to tens of thousands of RAW and JPEG assets) require scalable organizational and culling workflows:
- **Smart Collections**: Dynamic, query-driven collections that automatically gather photos meeting complex multi-rule criteria (ratings, flags, color labels, keywords, camera models, date ranges, and edit status) without requiring manual album maintenance.
- **Duplicate Detection**: Storage quickly accumulates duplicate files and rapid burst shots; event photographers need fast perceptual hashing to group near-identical photos for comparison and culling.
- **Blur & Closed-Eye Culling**: Event and wedding photographers need automated assistance to flag out-of-focus captures or blinking subjects across hundreds of group shots.
- **Auto-Import Folder Watching**: Desktop and tethered workflows require automatic ingestion of photos as they are saved into watched directories by memory card readers, tethering apps, or network shares.

## 2. Decision

### 1. Smart Collection Query Engine (`app/lib/gallery/smart_collection.dart`)
- Implemented `SmartRule` with target fields: `rating`, `flag`, `colorLabel`, `keyword`, `cameraModel`, `dateRange`, `hasEdits`.
- Supports comparison operators: `equals`, `notEquals`, `greaterThanOrEqual`, `lessThanOrEqual`, `contains`, `between`.
- Implemented `SmartCollection` with `SmartMatchMode.all` (AND) and `SmartMatchMode.any` (OR).
- Included factory presets: `5 Star Picks`, `Flagged Favorites`, `Recently Edited`, `Needs Review (Unrated)`, `Red Label Workflow`.
- Integrated filtering in `GalleryScreen` with dynamic filter chips and smart collection management bottom sheet.

### 2. Perceptual Difference Hashing & Clustering (`app/lib/gallery/duplicate_detector.dart`)
- Implemented 64-bit difference hashing (`dHash`):
  - Downsamples proxy images to a 9×8 grayscale matrix using box sampling.
  - Compares adjacent horizontal pixels: `grid[y][x] > grid[y][x+1]`, yielding 64 discrete binary bits.
  - Invariant to aspect ratio variations, scaling, and monotonic tonal curves.
- Computes bitwise population count (Hamming distance) via 64-bit unsigned shift logic.
- Implemented `findDuplicates(hashes, maxDistance = 6)`: clusters exact matches ($d = 0$) and burst near-duplicates ($d \le 6$) into `DuplicateGroup` records.
- Added duplicate review and batch selection bottom sheet in `GalleryScreen`.

### 3. Photo Quality Sharpness & Facial Culling (`app/lib/gallery/photo_quality_evaluator.dart`)
- **Optical Sharpness**: Convolves a standard 3×3 discrete Laplacian filter across the luminance plane and computes statistical variance: $\sigma^2(\nabla^2 I)$. Values below threshold ($45.0$) denote out-of-focus or motion-blurred captures.
- **Closed-Eye Detection**: Evaluates eye openness confidence from detected facial landmarks; flags blinks when confidence drops below $0.2$.
- Returns `QualityScore` with recommendation badge (`sharp`, `blurry`, `closed_eyes`).
- Renders visual quality warning badges on gallery photo tiles and offers batch catalog tagging.

### 4. Debounced Folder Watcher (`app/lib/gallery/folder_watcher.dart`)
- Listens to filesystem events (`Directory.watch()`) on specified target folders.
- Filters supported photographic extensions (`.jpg`, `.jpeg`, `.png`, `.heic`, `.dng`, `.cr2`, `.nef`, `.arw`, `.raf`).
- Debounces file system create/modify bursts (500ms window) to prevent premature reads while large RAW files are actively writing.
- Triggers background catalog refresh and toast notifications in `GalleryScreen`.

## 3. Consequences

### Positive
- **Streamlined Culling**: High-volume photographers can cull hundreds of duplicate, blurry, or blinking photos in minutes.
- **Zero Cloud Footprint**: All perceptual hashing, Laplacian convolutions, and facial analysis run 100% locally on device.
- **Continuous Ingestion**: Folder watching bridges the gap between desktop storage and mobile cataloging.

### Negative
- Evaluating perceptual hashes for very large albums (>500 photos) is batch-sliced across analysis proxies to preserve UI 60/120 FPS fluid interaction.
