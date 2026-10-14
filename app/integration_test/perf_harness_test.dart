import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:aperturex/color/grade_spec.dart';
import 'package:aperturex/color/lut_atlas.dart';
import 'package:aperturex/color/lut_texture.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/engine/engine.dart';
import 'package:aperturex/viewport/viewport_transform.dart';

/// On-device perf harness for the P1 exit criteria (issue #17):
///   - steady ~60 fps while the live-grade LUT is rebuilt each scrub step
///   - peak RSS for open + pan + export stays within the ~512 MB budget
///
/// Run on a pinned device profile (issue #17's "pinned device"):
///   flutter test integration_test/perf_harness_test.dart -d device-id
///   PERF_STRICT=1 ...   # enforce the 60 fps frame gate (default: report-only)
///   PERF_IMAGE_MP=12 ...  # open size in megapixels (default 3)
///
/// The scrub loop here mirrors `ImageCanvas._rebuildLut` (bakeLut3d +
/// lutAtlasToImage per step) minus the shader, which needs a real scene.
/// Rust runs in profile/release on-device, so these numbers are the real
/// ones — unlike the Dart-only CI gate in test/perf/scrub_perf_test.dart.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(TesseraEngine.init);

  testWidgets('live grade scrub holds the frame budget (issue #17)',
      (tester) async {
    const lutSize = 33;
    final scrubSteps =
        int.tryParse(Platform.environment['PERF_SCRUB_STEPS'] ?? '') ?? 120;
    final timings = <FrameTiming>[];
    void onTiming(List<FrameTiming> list) => timings.addAll(list);
    final binding = WidgetsBinding.instance;
    binding.addTimingsCallback(onTiming);

    for (var i = 0; i < scrubSteps; i++) {
      final recipe = EditRecipe.neutral.copyWith(
        exposure: (i % 40) - 20,
        contrast: ((i % 20) - 10) / 10,
      );
      final data = await TesseraEngine.bakeLut3d(
        GradeSpec.fromRecipe(recipe),
        size: lutSize,
      );
      final image = await lutAtlasToImage(
        LutAtlas(size: data.size, rgba: data.rgba),
      );
      image.dispose();
      await tester.pump(const Duration(milliseconds: 16));
    }

    binding.removeTimingsCallback(onTiming);
    expect(timings, isNotEmpty, reason: 'no frames were timed during scrub');

    final rasterMs = timings
        .map((t) => t.rasterDuration.inMicroseconds / 1000.0)
        .toList()
      ..sort();
    final p95 = rasterMs[(rasterMs.length * 0.95).floor().clamp(0, rasterMs.length - 1)];
    final median = rasterMs[rasterMs.length ~/ 2];
    // ignore: avoid_print — the report is the harness's primary output.
    print('scrub frames: n=${rasterMs.length} '
        'median=${median.toStringAsFixed(2)}ms '
        'p95=${p95.toStringAsFixed(2)}ms '
        'budget=${(1000 / 60).toStringAsFixed(2)}ms (60 fps)');

    if (Platform.environment['PERF_STRICT'] == '1') {
      expect(p95, lessThan(1000 / 60),
          reason: 'p95 raster over the 60 fps budget on the pinned profile');
    }
  });

  testWidgets('open + pan + export stays under the memory budget (issue #17)',
      (tester) async {
    final mp = int.tryParse(Platform.environment['PERF_IMAGE_MP'] ?? '') ?? 3;
    final side = math.sqrt(mp * 1000000).round();
    final budgetBytes = 512 * 1024 * 1024;

    int rss() => ProcessInfo.currentRss;
    final before = rss();

    final jpeg = await TesseraEngine.syntheticJpeg(width: side, height: side);
    final decoded = await TesseraEngine.decodeJpegRgba(jpeg);
    final afterOpen = rss();

    var transform = ViewportTransform(scale: 1, offset: Offset.zero);
    for (var i = 0; i < 1000; i++) {
      transform = transform.panned(const Offset(2, 1));
    }
    final afterPan = rss();

    final exported = await TesseraEngine.exportJpeg(
      rgba: decoded.rgba,
      width: decoded.width,
      height: decoded.height,
      spec: const GradeSpec(exposure: 0.5),
    );
    final afterExport = rss();

    final peak = math.max(
      afterExport,
      math.max(afterOpen, math.max(afterPan, before)),
    );
    // ignore: avoid_print — the report is the harness's primary output.
    print('rss: before=${mb(before)} open=${mb(afterOpen)} '
        'pan=${mb(afterPan)} export=${mb(afterExport)} '
        'peak=${mb(peak)} budget=${mb(budgetBytes)}');

    expect(exported, isNotEmpty);
    expect(peak, lessThan(budgetBytes),
        reason: 'peak RSS over the 512 MB device budget');
  });
}

String mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
