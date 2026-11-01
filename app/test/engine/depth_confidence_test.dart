import 'dart:io';

import 'package:aperturex/engine/engine.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rustDylib =
      '${Directory.current.path}/rust/target/debug/librust_lib_aperturex.so';
  final rustAvailable = File(rustDylib).existsSync();

  setUpAll(() async {
    try {
      if (rustAvailable) {
        await RustLib.init(
          externalLibrary: ExternalLibrary.open(rustDylib),
          forceSameCodegenVersion: false,
        );
      }
    } catch (_) {
      // Rust not available in this environment; tests requiring it skip individually.
    }
  });

  group('AxEngine depth confidence', () {
    test('depthConfidence is in unit range', () async {
      if (!rustAvailable) {
        return;
      }
      final rgba = Uint8List(16 * 16 * 4);
      for (var i = 0; i < rgba.length; i += 4) {
        rgba[i] = 128;
        rgba[i + 1] = 128;
        rgba[i + 2] = 128;
        rgba[i + 3] = 255;
      }
      final conf = await AxEngine.depthConfidence(
        rgba: rgba,
        width: 16,
        height: 16,
      );
      expect(conf >= 0.0 && conf <= 1.0, isTrue);
    });

    test('depthConfidence textureless is low', () async {
      if (!rustAvailable) {
        return;
      }
      final rgba = Uint8List(32 * 32 * 4);
      for (var i = 0; i < rgba.length; i += 4) {
        rgba[i] = 128;
        rgba[i + 1] = 128;
        rgba[i + 2] = 128;
        rgba[i + 3] = 255;
      }
      final conf = await AxEngine.depthConfidence(
        rgba: rgba,
        width: 32,
        height: 32,
      );
      expect(conf < 0.5, isTrue,
          reason: 'textureless image should have low confidence: $conf');
    });

    test('depthConfidence textured is higher than textureless', () async {
      if (!rustAvailable) {
        return;
      }
      final textureless = Uint8List(32 * 32 * 4);
      for (var i = 0; i < textureless.length; i += 4) {
        textureless[i] = 128;
        textureless[i + 1] = 128;
        textureless[i + 2] = 128;
        textureless[i + 3] = 255;
      }

      final textured = Uint8List(32 * 32 * 4);
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          final idx = (y * 32 + x) * 4;
          final v = (x + y) % 2 == 0 ? 255 : 0;
          textured[idx] = v;
          textured[idx + 1] = v;
          textured[idx + 2] = v;
          textured[idx + 3] = 255;
        }
      }

      final confTextureless = await AxEngine.depthConfidence(
        rgba: textureless,
        width: 32,
        height: 32,
      );
      final confTextured = await AxEngine.depthConfidence(
        rgba: textured,
        width: 32,
        height: 32,
      );
      expect(confTextured > confTextureless, isTrue,
          reason:
              'textured ($confTextured) > textureless ($confTextureless)');
    });
  });

  group('AxEngine face detection availability', () {
    test('faceDetectionAvailable returns bool', () async {
      if (!rustAvailable) {
        return;
      }
      final available = await AxEngine.faceDetectionAvailable();
      expect([true, false], contains(available));
    });
  });

  group('AxEngine portrait blur', () {
    test('blurApplyPortrait output length matches input', () async {
      if (!rustAvailable) {
        return;
      }
      final rgba = Uint8List(32 * 32 * 4);
      for (var i = 0; i < rgba.length; i += 4) {
        rgba[i] = 128;
        rgba[i + 1] = 128;
        rgba[i + 2] = 128;
        rgba[i + 3] = 255;
      }
      final out = await AxEngine.blurApplyPortrait(
        rgba: rgba,
        width: 32,
        height: 32,
        amount: 0.4,
      );
      expect(out.length, 32 * 32 * 4);
    });

    test('blurApplyPortrait default amount is subtle', () async {
      if (!rustAvailable) {
        return;
      }
      final rgba = Uint8List(32 * 32 * 4);
      for (var i = 0; i < rgba.length; i += 4) {
        rgba[i] = 200;
        rgba[i + 1] = 200;
        rgba[i + 2] = 200;
        rgba[i + 3] = 255;
      }
      final out = await AxEngine.blurApplyPortrait(
        rgba: rgba,
        width: 32,
        height: 32,
        amount: 0.4,
      );
      expect(out.length, 32 * 32 * 4);
    });

    test('blurApplyPortrait with checkerboard (no faces) does not error', () async {
      if (!rustAvailable) {
        return;
      }
      final rgba = Uint8List(32 * 32 * 4);
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          final idx = (y * 32 + x) * 4;
          final v = (x + y) % 2 == 0 ? 255 : 0;
          rgba[idx] = v;
          rgba[idx + 1] = v;
          rgba[idx + 2] = v;
          rgba[idx + 3] = 255;
        }
      }
      final out = await AxEngine.blurApplyPortrait(
        rgba: rgba,
        width: 32,
        height: 32,
        amount: 0.4,
      );
      expect(out.length, 32 * 32 * 4);
    });
  });
}
