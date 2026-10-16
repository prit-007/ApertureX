import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../color/grade_spec.dart';
import '../color/optics_spec.dart';
import '../color/spatial_spec.dart';
import '../edit/adjustment_layer.dart';
import '../edit/geometry_spec.dart';
import '../edit/recipe.dart';
import '../edit/xmp_sidecar.dart';
import '../engine/engine.dart';
import '../engine/image_format.dart';
import 'gallery_controller.dart' show gallerySourceProvider;
import 'gallery_source.dart';

/// Per-item work for [GalleryExporter.exportBatch] (decode → full-res export →
/// save). Injectable so tests can drive the pool, progress and cancel without
/// the Rust engine or platform channels.
typedef BatchExportItem = Future<bool> Function(String assetId, EditRecipe recipe);

/// One progress tick: [started] true when [id] began, false when it finished
/// ([done] counts finished items). [label] is the "12/40" count.
class BatchExportProgress {
  const BatchExportProgress({
    required this.done,
    required this.total,
    required this.id,
    required this.started,
  });

  final int done;
  final int total;
  final String id;
  final bool started;

  String get label => '$done/$total';
}

/// Outcome of one [GalleryExporter.exportBatch] run.
class BatchExportResult {
  const BatchExportResult({
    required this.exported,
    required this.failed,
    required this.cancelled,
  });

  /// Items whose bytes reached the gallery (fakes may count freely).
  final int exported;

  /// Ids whose export threw or returned false — one failure never aborts the
  /// rest of the batch.
  final List<String> failed;

  /// True when [BatchCancel.request] stopped the queue (even if every started
  /// item finished cleanly).
  final bool cancelled;
}

/// Cooperative cancel for a batch: [request] stops the queue from pulling more
/// ids and, when a full-res export is in flight, aborts it at its next band
/// boundary via the Rust cancel token (#75).
class BatchCancel {
  bool _requested = false;
  int? _token;

  bool get isRequested => _requested;

  /// Signals stop: no further ids are dequeued and the in-flight export (if
  /// any token is attached) aborts at its next band boundary.
  void request() {
    _requested = true;
    final token = _token;
    if (token != null) {
      TesseraEngine.exportCancelSet(token);
    }
  }

  /// Connects the currently running full-res export's cancel token.
  Future<void> attach(int token) async {
    _token = token;
    if (_requested) await TesseraEngine.exportCancelSet(token);
  }

  /// Releases [token] once its export finishes.
  Future<void> detach(int token) async {
    if (_token == token) _token = null;
    await TesseraEngine.exportCancelDrop(token);
  }
}

/// Everything the full pipeline needs from a recipe — kept as one pure step so
/// tests can assert layers/optics ride along without touching Rust (#75).
class ExportSpecs {
  const ExportSpecs({
    required this.grade,
    required this.spatial,
    required this.optics,
    required this.geometry,
    required this.layers,
  });

  final GradeSpec grade;
  final SpatialSpec spatial;
  final OpticsSpec optics;
  final GeometrySpec geometry;
  final List<AdjustmentLayer> layers;
}

ExportSpecs specsFor(EditRecipe recipe) => ExportSpecs(
  grade: GradeSpec.fromRecipe(recipe),
  spatial: SpatialSpec.fromRecipe(recipe),
  optics: OpticsSpec.fromRecipe(recipe),
  geometry: GeometrySpec.fromRecipe(recipe),
  layers: recipe.layers,
);

/// Exports gallery assets to the device Photos/DCIM (batch or single), applying
/// each asset's recipe. Grading reuses the exact preview path, and the source
/// EXIF is preserved (#12/#13).
class GalleryExporter {
  const GalleryExporter(
    this.source, {
    this.maxConcurrent = 2,
    this.item,
    this.sidecar,
  });

  final GallerySource source;

  /// In-flight cap for [exportBatch] (#75): mobile export is RAM-bound —
  /// a ~24MP RGBA frame is ~100MB, so 2 slots keep a ~250MB envelope and a
  /// queue beyond that waits its turn.
  final int maxConcurrent;

  /// Test seam — when set, replaces the decode/full-res/save pipeline.
  final BatchExportItem? item;

  /// When set, every successful export also emits an `.xmp` sidecar next to it
  /// (#77); `null` skips the write (tests, or a caller that wants raw
  /// images only).
  final XmpSidecarSink? sidecar;

  /// Grades and saves one asset with [recipe]; returns true when the bytes
  /// reached the gallery (false = failed or cancelled).
  Future<bool> exportAsset(
    String assetId,
    EditRecipe recipe, {
    BatchCancel? cancel,
  }) async {
    final src = await source.loadImage(assetId);
    if (src.isEmpty) return false;

    // RAW/DNG sources go through the Rust RAW decode (already sRGB RGBA8);
    // wide-gamut/EXIF handling below is JPEG-specific.
    final Uint8List rgba;
    final int width;
    final int height;
    var exif = Uint8List(0);
    if (isRawImage(src)) {
      final decoded = await TesseraEngine.decodeRawRgba(src);
      rgba = decoded.rgba;
      width = decoded.width;
      height = decoded.height;
    } else {
      final decoded = await TesseraEngine.decodeJpegRgba(src);
      exif = await TesseraEngine.extractExif(src);
      // Normalize wide-gamut input (Display P3 -> sRGB) so colours are faithful.
      final space = await TesseraEngine.detectColorspace(src);
      rgba = space == 2
          ? await TesseraEngine.p3ToSrgb(
              decoded.rgba,
              width: decoded.width,
              height: decoded.height,
            )
          : decoded.rgba;
      width = decoded.width;
      height = decoded.height;
    }

    // One cancel token per item; BatchCancel routes a mid-batch request into
    // whichever item is in flight right now.
    final token = cancel == null ? 0 : await TesseraEngine.exportCancelNew();
    if (cancel != null) await cancel.attach(token);
    try {
      final specs = specsFor(recipe);
      final out = await TesseraEngine.exportJpegFull(
        rgba: rgba,
        width: width,
        height: height,
        spec: specs.grade,
        spatial: specs.spatial,
        optics: specs.optics,
        geometry: specs.geometry,
        layers: specs.layers,
        exif: exif,
        cancelToken: token,
      );
      if (out == null) return false; // cancelled at a band boundary
      await Gal.putImageBytes(out, name: 'aperturex_$assetId');
      await emitXmpSidecar(sidecar, 'aperturex_$assetId', recipe);
      return true;
    } finally {
      if (cancel != null) await cancel.detach(token);
    }
  }

  /// Exports many assets with bounded parallelism, live progress and
  /// cooperative cancel. Each id maps to its recipe via [recipeFor]; one
  /// failing id is collected in [BatchExportResult.failed] and never aborts
  /// the batch.
  Future<BatchExportResult> exportBatch(
    Iterable<String> assetIds,
    EditRecipe Function(String id) recipeFor, {
    void Function(BatchExportProgress progress)? onProgress,
    BatchCancel? cancel,
  }) async {
    final ids = assetIds.toList(growable: false);
    final total = ids.length;
    final BatchExportItem run = item ?? _runCancellable(cancel);
    var next = 0;
    var done = 0;
    var exported = 0;
    final failed = <String>[];

    Future<void> worker() async {
      while (true) {
        if (cancel != null && cancel.isRequested) return;
        final index = next++;
        if (index >= total) return;
        final id = ids[index];
        onProgress?.call(
          BatchExportProgress(
            done: done,
            total: total,
            id: id,
            started: true,
          ),
        );
        var ok = false;
        try {
          ok = await run(id, recipeFor(id));
        } catch (_) {
          ok = false;
        }
        if (ok) {
          exported++;
        } else {
          failed.add(id);
        }
        done++;
        onProgress?.call(
          BatchExportProgress(done: done, total: total, id: id, started: false),
        );
      }
    }

    final slots = maxConcurrent < total ? maxConcurrent : total;
    await Future.wait([for (var i = 0; i < slots; i++) worker()]);
    return BatchExportResult(
      exported: exported,
      failed: failed,
      cancelled: cancel?.isRequested ?? false,
    );
  }

  BatchExportItem _runCancellable(BatchCancel? cancel) =>
      (assetId, recipe) => exportAsset(assetId, recipe, cancel: cancel);
}

/// Provider seam so tests (and future surfaces) can swap the exporter.
final galleryExporterProvider = Provider<GalleryExporter>(
  (ref) => GalleryExporter(
    ref.watch(gallerySourceProvider),
    sidecar: ref.watch(exportSidecarSinkProvider),
  ),
);
