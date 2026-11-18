import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/depth_sidecar.dart';

void main() {
  group('DepthSidecar', () {
    test('encode/decode round-trips depth sidecar payload accurately', () {
      final plane = Float32List.fromList([0.1, 0.25, 0.75, 0.9]);
      final data = DepthSidecarData(
        width: 2,
        height: 2,
        confidence: 0.88,
        source: DepthSourceType.neural,
        contentHash: 123456789012345678,
        plane: plane,
      );

      final bytes = DepthSidecar.encode(data);
      expect(bytes.length, 27 + 2 * 2 * 4);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'AXDF');

      final decoded = DepthSidecar.decode(bytes);
      expect(decoded.width, 2);
      expect(decoded.height, 2);
      expect(decoded.confidence, closeTo(0.88, 1e-4));
      expect(decoded.source, DepthSourceType.neural);
      expect(decoded.contentHash, 123456789012345678);
      expect(decoded.plane.length, 4);
      expect(decoded.plane[0], closeTo(0.1, 1e-5));
      expect(decoded.plane[1], closeTo(0.25, 1e-5));
      expect(decoded.plane[2], closeTo(0.75, 1e-5));
      expect(decoded.plane[3], closeTo(0.9, 1e-5));
    });

    test('fileNameFor replaces image extension with .axdf', () {
      expect(DepthSidecar.fileNameFor('IMG_4021.JPG'), 'IMG_4021.axdf');
      expect(DepthSidecar.fileNameFor('raw_shot.DNG'), 'raw_shot.axdf');
    });

    test('decode rejects non-AXDF magic or truncated payloads', () {
      expect(
        () => DepthSidecar.decode(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<FormatException>()),
      );

      final badMagic = Uint8List(27);
      expect(
        () => DepthSidecar.decode(badMagic),
        throwsA(isA<FormatException>()),
      );
    });

    test('DirectoryDepthSidecarSink writes and reads back sidecar', () async {
      final tempDir = await Directory.systemTemp.createTemp('depth_sidecar_test');
      try {
        final sink = DirectoryDepthSidecarSink(() async => tempDir);
        final plane = Float32List.fromList([0.05, 0.5, 0.95]);
        final data = DepthSidecarData(
          width: 3,
          height: 1,
          confidence: 0.92,
          source: DepthSourceType.approximate,
          contentHash: 987654321,
          plane: plane,
        );

        await sink.write('test_photo.jpg', data);
        final readBack = await sink.read('test_photo.jpg');

        expect(readBack, isNotNull);
        expect(readBack!.width, 3);
        expect(readBack.height, 1);
        expect(readBack.source, DepthSourceType.approximate);
        expect(readBack.plane.length, 3);
        expect(readBack.plane[1], closeTo(0.5, 1e-5));

        final nonExistent = await sink.read('non_existent.jpg');
        expect(nonExistent, isNull);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
