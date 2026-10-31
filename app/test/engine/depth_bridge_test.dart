import 'dart:io';

import 'package:aperturex/engine/engine.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final rustDylib =
        '${Directory.current.path}/rust/target/debug/librust_lib_aperturex.so';
    if (File(rustDylib).existsSync()) {
      await RustLib.init(
        externalLibrary: ExternalLibrary.open(rustDylib),
        forceSameCodegenVersion: false,
      );
    }
  });

  group('AxEngine depth bridge', () {
    test('generateDepthVisualizerRgba maps near/focus/far to amber/gray/teal', () async {
      final heatmap = await AxEngine.generateDepthVisualizerRgba(
        depth: [0.0, 0.5, 1.0],
        width: 3,
        height: 1,
        focalPoint: 0.5,
        focalRange: 0.1,
      );
      expect(heatmap.length, 12);
      // Near: Warm Amber (255, 179, 0), opaque
      expect(heatmap[0], 255);
      expect(heatmap[1], 179);
      expect(heatmap[2], 0);
      expect(heatmap[3], 255);
      // Focus: Neutral Gray (180, 180, 180), opaque
      expect(heatmap[4], 180);
      expect(heatmap[5], 180);
      expect(heatmap[6], 180);
      expect(heatmap[7], 255);
      // Far: Cool Teal (0, 180, 200), opaque
      expect(heatmap[8], 0);
      expect(heatmap[9], 180);
      expect(heatmap[10], 200);
      expect(heatmap[11], 255);
    });

    test('setActiveMlModel returns false for nonexistent model path', () async {
      final ok = await AxEngine.setActiveMlModel(
        task: 'depth',
        path: '/nonexistent/depth_anything_v2_vits.onnx',
      );
      expect(ok, isFalse);
    });

    test('estimateDepthMapWithModel falls back to synthetic depth plane for missing model', () async {
      final rgba = Uint8List(16 * 16 * 4);
      for (var i = 0; i < rgba.length; i += 4) {
        rgba[i] = 128;
        rgba[i + 1] = 128;
        rgba[i + 2] = 128;
        rgba[i + 3] = 255;
      }
      final depth = await AxEngine.estimateDepthMapWithModel(
        rgba: rgba,
        width: 16,
        height: 16,
        modelPath: '/nonexistent/depth_anything_v2_vits.onnx',
      );
      expect(depth.length, 16 * 16);
      for (final d in depth) {
        expect(d >= 0.0 && d <= 1.0, isTrue);
      }
    });
  });
}
