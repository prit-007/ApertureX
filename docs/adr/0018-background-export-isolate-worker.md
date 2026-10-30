# ADR 0018 — Background Export via Dedicated Isolate Worker

- **Status:** Accepted
- **Date:** 2026-10-30
- **Deciders:** Developer's Paradise
- **Consults:** ADR 0001 (Flutter UI & Rust Engine), ADR 0003 (Non-destructive Recipe Model), Issue #80

---

## 1. Context

Exporting high-resolution photographs (especially when applying complex adjustments, 3D LUTs, multi-scale spatial filters, and 8+ adjustment layers) is computationally intensive. In previous iterations:
- Synchronous or main-thread exports over `flutter_rust_bridge` risked UI micro-stutters during heavy memory allocations.
- If the user switched apps or locked their screen during a high-resolution export, the OS mobile lifecycle manager could terminate or suspend the process, causing corrupt or half-written output files.
- Batch exports of multiple images required sustained CPU work that could exceed mobile foreground limits.

## 2. Decision

Introduce a decoupled background export queue managed by `BackgroundExportWorker` (`app/lib/features/editor/background_export_worker.dart`):

1. **Independent Dart Isolate Execution**:
   - Long-running export pipelines run inside a detached background Dart Isolate spawned via `Isolate.spawn` / `compute`.
   - The worker receives the decoded RGBA buffer (or file reference), target dimensions, and the serializable `EditRecipe`.
   - The UI thread remains completely responsive at 120 FPS.

2. **Wake-Lock & Process Persistence**:
   - The worker maintains background persistence hooks during active export batches, preventing process suspension when the user minimizes the application.
   - Status updates are streamed back via `SendPort`/`ReceivePort` and surfaced as real-time notifications and in-app progress snacks.

3. **Disk Streaming & Clean Temp Lifecycle**:
   - Output files are written directly to temporary storage (`getTemporaryDirectory`) before atomic rename or dispatch to gallery providers.
   - Any cancelled or failed tasks cleanly purge incomplete target files to avoid flash storage bloat.

## 3. Consequences

### Positive
- **Rock-Solid Reliability**: Multi-image batch exports and large megapixel exports complete reliably even when the device is locked or foreground focus changes.
- **Uncompromised UI Ergonomics**: Users can queue an export and immediately continue editing another photo or navigating the library.
- **Unified Surface**: Surfaced in `ExportOptionsSheet` as "Background Queue Export" with direct telemetry.

### Negative
- Isolate memory boundary requires serializable payloads across message ports, necessitating careful buffer management.
