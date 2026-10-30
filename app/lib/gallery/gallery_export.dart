import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../color/blur_spec.dart';
import '../color/grade_spec.dart';
import '../color/optics_spec.dart';
import '../color/spatial_spec.dart';
import '../edit/adjustment_layer.dart';
import '../edit/geometry_spec.dart';
import '../edit/recipe.dart';
import '../edit/xmp_sidecar.dart';
import '../engine/engine.dart';
import '../engine/image_format.dart';
import '../features/editor/export_progress.dart';
import '../platform/file_saver.dart';
import '../platform/photo_saver.dart';
import '../settings/export_settings.dart';
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

/// Aggregates per-item start/finish/fraction events into a single monotonic
/// 0..1 bar value for a batch: `(done + Σ in-flight fractions) / total`. The
/// fractions let the bar creep forward *within* a long item instead of
/// freezing until it finishes.
class BatchProgressAggregator {
  BatchProgressAggregator({required this.total});

  final int total;

  /// Fraction (0..1) reported for each in-flight id.
  final Map<String, double> _inFlight = {};

  /// Items that have finished (successfully or not).
  int done = 0;

  /// Marks [id] as started with zero progress.
  void start(String id) => _inFlight[id] = 0;

  /// Records a within-item fraction for [id] (0..1).
  void fraction(String id, double value) => _inFlight[id] = value.clamp(0, 1);

  /// Marks [id] finished; its fraction no longer contributes.
  void finish(String id) {
    _inFlight.remove(id);
    done++;
  }

  /// Overall bar value: `(done + Σ in-flight) / total`, clamped to 0..1.
  /// An empty batch reports 1 (nothing to do = complete).
  double get overall {
    if (total <= 0) return 1;
    final sum = _inFlight.values.fold<double>(0, (a, b) => a + b);
    return ((done + sum) / total).clamp(0.0, 1.0);
  }
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
      AxEngine.exportCancelSet(token);
    }
  }

  /// Connects the currently running full-res export's cancel token.
  Future<void> attach(int token) async {
    _token = token;
    if (_requested) await AxEngine.exportCancelSet(token);
  }

  /// Releases [token] once its export finishes.
  Future<void> detach(int token) async {
    if (_token == token) _token = null;
    await AxEngine.exportCancelDrop(token);
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
    required this.blur,
    required this.layers,
    this.maskGroups = const [],
  });

  final GradeSpec grade;
  final SpatialSpec spatial;
  final OpticsSpec optics;
  final GeometrySpec geometry;
  final LensBlurSpec blur;
  final List<AdjustmentLayer> layers;
  final List<MaskGroup> maskGroups;
}

/// Maps the user's [ExportSettings] onto the engine's full-res JPEG options,
/// mirroring the editor path exactly: `maxDim == 0` means "original
/// resolution" (engine `null`).
({int quality, int? maxDim, int colorSpace, bool ultraHdr, double hdrHeadroom})
fullExportOptions(ExportSettings s) => (
  quality: s.quality,
  maxDim: s.maxDim == 0 ? null : s.maxDim,
  colorSpace: s.colorSpace,
  ultraHdr: s.ultraHdr,
  hdrHeadroom: s.hdrHeadroom,
);

ExportSpecs specsFor(EditRecipe recipe) => ExportSpecs(
  grade: GradeSpec.fromRecipe(recipe),
  spatial: SpatialSpec.fromRecipe(recipe),
  optics: OpticsSpec.fromRecipe(recipe),
  geometry: GeometrySpec.fromRecipe(recipe),
  blur: LensBlurSpec.fromRecipe(recipe),
  layers: recipe.layers,
  maskGroups: recipe.maskGroups,
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
    this.settings = const ExportSettings(),
    this.isDesktop = false,
    this.sink = const RealGalSink(),
    this.pickDirectory,
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

  /// User export preferences (quality / max size / color space / HDR);
  /// defaults to [ExportSettings] defaults so bare constructions (tests)
  /// keep their meaning.
  final ExportSettings settings;

  /// Desktop (#104): gal has no Linux implementation, so a desktop batch
  /// asks for a destination folder once (via [pickDirectory]) and every item
  /// writes `aperturex_<id>.jpg` there. Mobile keeps gal through [sink].
  final bool isDesktop;

  /// Where mobile exports land (gal). Desktop batches never touch it — the
  /// recording fakes in tests fail loudly if they do.
  final GallerySink sink;

  /// Folder picker for [isDesktop] batches; `null` falls back to the real
  /// `file_picker` directory dialog.
  final DirectoryPickDialog? pickDirectory;

  /// Grades and saves one asset with [recipe]; returns true when the bytes
  /// reached the gallery (false = failed or cancelled). [onFraction], when
  /// set, receives the render fraction (0..1) polled from the engine's
  /// progress cell while the full-res export runs. [destinationDirectory]
  /// (desktop batch, #104) redirects the write to
  /// `<destinationDirectory>/aperturex_<assetId>.jpg` instead of gal.
  Future<bool> exportAsset(
    String assetId,
    EditRecipe recipe, {
    BatchCancel? cancel,
    void Function(double fraction)? onFraction,
    String? destinationDirectory,
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
      final decoded = await AxEngine.decodeRawRgba(src);
      rgba = decoded.rgba;
      width = decoded.width;
      height = decoded.height;
    } else {
      final decoded = await AxEngine.decodeImageRgba(src);
      exif = await AxEngine.extractExif(src);
      // Normalize wide-gamut input (Display P3 -> sRGB) so colours are faithful.
      final space = await AxEngine.detectColorspace(src);
      rgba = space == 2
          ? await AxEngine.p3ToSrgb(
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
    final token = cancel == null ? 0 : await AxEngine.exportCancelNew();
    if (cancel != null) await cancel.attach(token);
    ExportProgressPoller? poller;
    if (onFraction != null && token != 0) {
      poller = ExportProgressPoller(
        token: token,
        read: AxEngine.exportProgressFraction,
        onValue: onFraction,
      )..start();
    }
    try {
      final specs = specsFor(recipe);
      final opts = fullExportOptions(settings);
      final out = await AxEngine.exportJpegFull(
        rgba: rgba,
        width: width,
        height: height,
        spec: specs.grade,
        spatial: specs.spatial,
        optics: specs.optics,
        geometry: specs.geometry,
        blur: specs.blur,
        layers: specs.layers,
        maskGroups: specs.maskGroups,
        exif: exif,
        cancelToken: token,
        quality: opts.quality,
        maxDim: opts.maxDim,
        colorSpace: opts.colorSpace,
        ultraHdr: opts.ultraHdr,
        hdrHeadroom: opts.hdrHeadroom,
      );
      if (out == null) return false; // cancelled at a band boundary
      if (destinationDirectory != null) {
        // Desktop batch: plain filesystem write — gal has no Linux impl.
        final file = File(
          '$destinationDirectory${Platform.pathSeparator}'
          'aperturex_$assetId.jpg',
        );
        await file.writeAsBytes(out, flush: true);
      } else {
        await sink.putImageBytes(out, name: 'aperturex_$assetId');
      }
      await emitXmpSidecar(sidecar, 'aperturex_$assetId', recipe);
      return true;
    } finally {
      poller?.stop();
      if (cancel != null) await cancel.detach(token);
    }
  }

  /// Exports many assets with bounded parallelism, live progress and
  /// cooperative cancel. Each id maps to its recipe via [recipeFor]; one
  /// failing id is collected in [BatchExportResult.failed] and never aborts
  /// the batch. [onItemProgress], when set, receives live within-item
  /// render fractions (0..1) for ids running through the real pipeline
  /// (the test [item] seam cannot report them).
  Future<BatchExportResult> exportBatch(
    Iterable<String> assetIds,
    EditRecipe Function(String id) recipeFor, {
    void Function(BatchExportProgress progress)? onProgress,
    void Function(String id, double fraction)? onItemProgress,
    BatchCancel? cancel,
  }) async {
    final ids = assetIds.toList(growable: false);
    final total = ids.length;
    // Desktop (#104): one folder dialog for the whole batch, asked before
    // any worker starts — cancelling it aborts the batch (cancelled result,
    // no items rendered), matching the cooperative-cancel contract.
    String? destinationDirectory;
    if (isDesktop) {
      destinationDirectory = await (pickDirectory ?? filePickerDirectoryPath)();
      if (destinationDirectory == null) {
        return const BatchExportResult(
          exported: 0,
          failed: <String>[],
          cancelled: true,
        );
      }
    }
    final BatchExportItem run =
        item ?? _runCancellable(cancel, onItemProgress, destinationDirectory: destinationDirectory);
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

  BatchExportItem _runCancellable(
    BatchCancel? cancel,
    void Function(String id, double fraction)? onItemProgress, {
    String? destinationDirectory,
  }) => (assetId, recipe) => exportAsset(
    assetId,
    recipe,
    cancel: cancel,
    onFraction: onItemProgress == null
        ? null
        : (fraction) => onItemProgress(assetId, fraction),
    destinationDirectory: destinationDirectory,
  );
}

/// Provider seam so tests (and future surfaces) can swap the exporter.
final galleryExporterProvider = Provider<GalleryExporter>(
  (ref) => GalleryExporter(
    ref.watch(gallerySourceProvider),
    sidecar: ref.watch(exportSidecarSinkProvider),
    settings: ref.watch(exportSettingsProvider),
    isDesktop: ref.watch(isDesktopPlatformProvider),
    sink: ref.watch(gallerySinkProvider),
    pickDirectory: ref.watch(pickDirectoryProvider),
  ),
);
