import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:aperturex/src/rust/api/decode.dart';
import 'package:aperturex/src/rust/frb_generated.dart';
import 'package:aperturex/ui/common/mask_controls.dart';

/// Captures the params the default [maskRefinerProvider] actually sends
/// across the bridge, without needing the native library.
class _CapturingApi extends Fake implements RustLibApi {
  List<double>? lastParams;

  @override
  Future<RgbaImage> crateApiDecodeDecodeJpegRgba({required List<int> jpeg}) async =>
      RgbaImage(width: 2, height: 2, rgba: Uint8List(16));

  @override
  Future<Float32List> crateApiMaskRefineMask({
    required List<int> rgba,
    required int width,
    required int height,
    required int kind,
    required List<double> params,
    required List<double> strokePoints,
    required double brushRadius,
    required int filterRadius,
    required double eps,
  }) async {
    lastParams = List<double>.from(params);
    return Float32List(width * height);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final api = _CapturingApi();
  late ProviderContainer container;

  setUpAll(() {
    RustLib.initMock(api: api);
  });

  setUp(() {
    container = ProviderContainer();
    api.lastParams = null;
  });

  tearDown(() {
    container.dispose();
  });

  // JPEG magic so decodeAnalysisProxy routes to the (mocked) JPEG path.
  final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

  test('default refiner expands bitmap layers to the Rust [w, h, alpha…] contract', () async {
    final layer = AdjustmentLayer.bitmap(
      width: 2,
      height: 2,
      alphas: const [0.1, 0.2, 0.8, 0.9],
    );
    // Storage keeps only [w, h]; the alphas live in maskBlob (#86).
    expect(layer.maskParams.length, 2);

    final refiner = container.read(maskRefinerProvider);
    final refined = await refiner(layer, jpegBytes);

    expect(refined, isNotNull);
    expect(refined!.maskKind, MaskKind.bitmap);
    expect(api.lastParams, isNotNull);
    // Old bug: raw layer.maskParams ([w, h]) was sent — Rust rejects it
    // because the contract wants 2 + w*h values.
    expect(api.lastParams!.length, 2 + 4);
    expect(api.lastParams!.sublist(0, 2), [2.0, 2.0]);
    expect(api.lastParams![2], closeTo(0.1, 0.01));
    expect(api.lastParams![3], closeTo(0.2, 0.01));
  });

  test('analytic layers pass their params through the bridge unchanged', () async {
    const layer = AdjustmentLayer(
      maskKind: MaskKind.linear,
      maskParams: [0.2, 0.1, 0.2, 0.9],
    );

    final refiner = container.read(maskRefinerProvider);
    await refiner(layer, jpegBytes);

    expect(api.lastParams, hasLength(4));
    for (final (i, got) in api.lastParams!.indexed) {
      expect(got, closeTo([0.2, 0.1, 0.2, 0.9][i], 1e-6),
          reason: 'float32 bridge round-trip');
    }
  });
}
