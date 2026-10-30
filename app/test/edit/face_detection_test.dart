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
        await RustLib.init(externalLibrary: ExternalLibrary.open(rustDylib));
      }
    } catch (_) {}
  });

  group('Face Detection (YuNet integration)', () {
    test('detectFaces returns empty list on invalid/empty proxy image', () async {
      if (!rustAvailable) return;
      final faces = await AxEngine.detectFaces(
        Uint8List(0),
        width: 0,
        height: 0,
      );
      expect(faces, isEmpty);
    });

    test('detectFace returns null when no faces are detected in uniform grey proxy', () async {
      if (!rustAvailable) return;
      final solidGrey = Uint8List(64 * 64 * 4)..fillRange(0, 64 * 64 * 4, 128);
      final face = await AxEngine.detectFace(
        solidGrey,
        width: 64,
        height: 64,
      );
      expect(face, isNull);
    });
  });
}
