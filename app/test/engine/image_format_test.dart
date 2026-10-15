import 'dart:typed_data';

import 'package:aperturex/engine/image_format.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _bytes(List<int> b) => Uint8List.fromList(b);

void main() {
  group('detectImageFormat', () {
    test('recognises JPEG', () {
      expect(
        detectImageFormat(_bytes([0xFF, 0xD8, 0xFF, 0xE0, 0x00])),
        ImageFormat.jpeg,
      );
    });

    test('recognises PNG, GIF, BMP and WebP', () {
      expect(
        detectImageFormat(_bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])),
        ImageFormat.png,
      );
      expect(
        detectImageFormat(_bytes([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])),
        ImageFormat.gif,
      );
      expect(detectImageFormat(_bytes([0x42, 0x4D, 0x00, 0x00])), ImageFormat.bmp);
      final webp = 'RIFF????WEBP'.codeUnits;
      expect(detectImageFormat(_bytes(webp)), ImageFormat.webp);
    });

    test('recognises little- and big-endian TIFF raws', () {
      expect(
        detectImageFormat(_bytes([0x49, 0x49, 0x2A, 0x00, 0x08])),
        ImageFormat.raw,
      );
      expect(
        detectImageFormat(_bytes([0x4D, 0x4D, 0x00, 0x2A, 0x00])),
        ImageFormat.raw,
      );
    });

    test('recognises CR3 (ISO-BMFF) and RAF', () {
      final cr3 = '????ftypcrx '.codeUnits;
      expect(detectImageFormat(_bytes(cr3)), ImageFormat.raw);
      expect(
        detectImageFormat(_bytes('FUJIFILM'.codeUnits)),
        ImageFormat.raw,
      );
    });

    test('isRawImage only for raw containers', () {
      expect(isRawImage(_bytes([0x49, 0x49, 0x2A, 0x00])), isTrue);
      expect(isRawImage(_bytes([0xFF, 0xD8, 0xFF])), isFalse);
      expect(isRawImage(_bytes([0x89, 0x50, 0x4E, 0x47])), isFalse);
    });

    test('unknown and short inputs are safe', () {
      expect(detectImageFormat(Uint8List(0)), ImageFormat.unknown);
      expect(detectImageFormat(_bytes([0x01, 0x02])), ImageFormat.unknown);
    });
  });
}
