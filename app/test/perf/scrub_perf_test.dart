import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/color/grade_spec.dart';
import 'package:aperturex/color/lut_atlas.dart';
import 'package:aperturex/color/lut_texture.dart';
import 'package:aperturex/edit/recipe.dart';

/// CI regression gate for the live-grading scrub hot path (issue #17).
///
/// A scrub step in ImageCanvas._rebuildLut costs:
///   GradeSpec.fromRecipe(recipe)  →  AxEngine.bakeLut3d (Rust, device)
///   →  lutAtlasToImage (Dart + engine texture upload).
///
/// The Rust bake only runs on a device (see integration_test/perf_harness_test.dart);
/// this gate covers the Dart-side half under the same conditions CI already
/// runs (`flutter test`), so a catastrophic regression in recipe mapping or
/// the atlas upload path fails the PR without hardware. Budgets are medians
/// with large headroom over the debug-VM baseline — they gate order-of-
/// magnitude regressions, not microseconds.
void main() {
  const lutSize = 33; // ImageCanvas._previewLutSize
  const steps = 30;

  test('a scrub step stays within the debug-VM budget (issue #17)', () async {
    // 33^3 RGBA atlas, exactly what bakeLut3d returns (width = size * size).
    final rgba = Uint8List(lutSize * lutSize * lutSize * 4);

    EditRecipe recipeFor(int i) =>
        EditRecipe.neutral.copyWith(exposure: (i % 20) - 10);

    Future<void> scrubStep(int i) async {
      final spec = GradeSpec.fromRecipe(recipeFor(i));
      // Content varies per step so nothing unrealistically short-circuits.
      rgba[i % rgba.length] = (i * 37) & 0xff;
      final image = await lutAtlasToImage(
        LutAtlas(size: lutSize, rgba: Uint8List.fromList(rgba)),
      );
      expect(spec.exposure, recipeFor(i).exposure);
      image.dispose();
    }

    // Warm up the engine's image decode path before timing.
    for (var i = 0; i < 3; i++) {
      await scrubStep(i);
    }

    final samples = <int>[];
    for (var i = 0; i < steps; i++) {
      final sw = Stopwatch()..start();
      await scrubStep(i);
      sw.stop();
      samples.add(sw.elapsedMilliseconds);
    }

    samples.sort();
    final median = samples[samples.length ~/ 2];
    final p95 = samples[(samples.length * 0.95).floor().clamp(0, samples.length - 1)];

    // ignore: avoid_print — the numbers double as a CI trend line.
    print('scrub step (Dart side, $lutSize^3): '
        'median ${median}ms, p95 ${p95}ms');

    // Generous ceiling (~50x the measured ~1ms baseline): catches accidental
    // per-texel Dart loops or repeated re-uploads, immune to VM pauses via median.
    expect(median, lessThan(50), reason: 'median scrub-step cost regressed');
    expect(p95, lessThan(200), reason: 'p95 scrub-step cost regressed');
  });
}
