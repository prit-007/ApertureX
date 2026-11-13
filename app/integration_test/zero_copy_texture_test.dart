import 'package:aperturex/color/grade_spec.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/engine/engine.dart';
import 'package:aperturex/engine/preview_texture.dart';
import 'package:aperturex/viewport/base_spec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// On-device proof of the zero-copy delivery path (spike B / #54):
/// create → bind → render → frameAvailable → dispose against the real
/// platform texture registry, JNI `ANativeWindow` bind (Android) and Rust
/// `write_rgba` — the chain the old `_tryBindTexture` stub skipped.
///
/// Also reports the per-frame cost of a texture-path scrub so it can be
/// compared against the shader path's LUT rebuild loop in
/// `perf_harness_test.dart`.
///
/// Run: `flutter test integration_test/zero_copy_texture_test.dart -d <device>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(AxEngine.init);

  test('zero-copy texture chain works end to end on-device', () async {
    const width = 640;
    const height = 480;
    final jpeg = await AxEngine.syntheticJpeg(width: width, height: height);
    final handle = await AxEngine.previewOpenJpeg(
      jpegBytes: jpeg,
      maxDim: width,
    );
    addTearDown(() => AxEngine.previewClose(handle));

    final textureId = await PreviewTextureChannel.create(
      width: width,
      height: height,
    );
    expect(
      textureId,
      isNotNull,
      reason: 'platform texture registry must be available on-device',
    );
    addTearDown(() => PreviewTextureChannel.dispose(textureId!));

    final bound = await PreviewTextureChannel.bind(
      textureId: textureId!,
      handle: handle,
    );
    expect(
      bound,
      isTrue,
      reason: 'ANativeWindow/CVPixelBuffer bind must succeed on-device '
          '(a false here means the whole path falls back to the shader)',
    );

    final spec = baseSpecFromRecipe(EditRecipe.neutral);
    const grade = GradeSpec(exposure: 0.5);
    final size = await AxEngine.previewRender(
      handle,
      spec: spec,
      layers: const [],
      grade: grade,
      baseChanged: true,
    );
    expect(size.width, width, reason: 'frame must match the bound buffer');
    expect(size.height, height);

    await PreviewTextureChannel.frameAvailable(textureId);

    // Scrub-shaped loop: grade-only ticks with the cached base (the hot path
    // while a slider moves). Report only — the gate lives in perf_harness.
    const steps = 120;
    final timings = <double>[];
    for (var i = 0; i < steps; i++) {
      final sw = Stopwatch()..start();
      await AxEngine.previewRender(
        handle,
        spec: spec,
        layers: const [],
        grade: GradeSpec(exposure: ((i % 40) - 20).toDouble()),
        baseChanged: false,
      );
      sw.stop();
      timings.add(sw.elapsedMicroseconds / 1000.0);
      await PreviewTextureChannel.frameAvailable(textureId);
    }
    timings.sort();
    final median = timings[timings.length ~/ 2];
    final p95 = timings[(timings.length * 0.95).floor().clamp(
      0,
      timings.length - 1,
    )];
    // ignore: avoid_print — the report is the harness's primary output.
    print(
      'texture-path scrub: n=$steps '
      'median=${median.toStringAsFixed(2)}ms '
      'p95=${p95.toStringAsFixed(2)}ms',
    );
  });
}
