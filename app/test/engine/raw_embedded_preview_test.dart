import 'dart:io';

import 'package:aperturex/engine/engine.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';

final rustDylib =
    '${Directory.current.path}/rust/target/debug/librust_lib_aperturex.so';
final rustAvailable = File(rustDylib).existsSync();

/// Builds a mock RAW container with an embedded JPEG preview stream.
///
/// Layout: [junk prefix][JPEG SOI(FFD8FF)...JPEG EOI(FFD9)][junk suffix]
/// This simulates the structure of a real RAW file (ARW/CR2/NEF/DNG/RW2)
/// which carries an embedded JPEG preview for fast viewport open.
Uint8List _buildMockRawWithEmbeddedJpeg({
  required int prefixSize,
  required int jpegSize,
  required int suffixSize,
}) {
  final mockRaw = <int>[];

  // Junk prefix (RAW header/TIFF data)
  mockRaw.addAll(List<int>.filled(prefixSize, 0xAA));

  // Embedded JPEG stream
  mockRaw.addAll([0xFF, 0xD8, 0xFF]); // SOI
  mockRaw.addAll(List<int>.filled(jpegSize - 4, 0x42)); // JPEG body
  mockRaw.addAll([0xFF, 0xD9]); // EOI

  // Junk suffix
  mockRaw.addAll(List<int>.filled(suffixSize, 0xBB));

  return Uint8List.fromList(mockRaw);
}

void main() {
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

  group('Raw embedded preview fast path', () {
    test('extractRawEmbeddedPreview returns null for non-RAW bytes', () async {
      final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      final result = await AxEngine.extractRawEmbeddedPreview(jpegBytes);
      expect(result, isNull);
    });

    test('extractRawEmbeddedPreview returns null for empty bytes', () async {
      final result = await AxEngine.extractRawEmbeddedPreview(Uint8List(0));
      expect(result, isNull);
    });

    test('extractRawEmbeddedPreview extracts embedded JPEG from mock RAW', () async {
      if (!rustAvailable) {
        // Skip if Rust library not available
        return;
      }
      final mockRaw = _buildMockRawWithEmbeddedJpeg(
        prefixSize: 2048,
        jpegSize: 17000,
        suffixSize: 1024,
      );
      final result = await AxEngine.extractRawEmbeddedPreview(mockRaw);
      expect(result, isNotNull);
      expect(result!.length, 17000);
      // Verify SOI marker
      expect(result[0], 0xFF);
      expect(result[1], 0xD8);
      // Verify EOI marker
      expect(result[result.length - 2], 0xFF);
      expect(result[result.length - 1], 0xD9);
    });

    test('extractRawEmbeddedPreview prefers larger embedded JPEG', () async {
      if (!rustAvailable) {
        return;
      }
      // Create a mock RAW with two embedded JPEGs - one small, one large
      final smallJpeg = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, // SOI + APP0 marker
        ...List<int>.filled(1000 - 4, 0x42),
        0xFF, 0xD9, // EOI
      ]);
      final largeJpeg = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0,
        ...List<int>.filled(50000 - 4, 0x42),
        0xFF, 0xD9,
      ]);

      final mockRaw = <int>[];
      mockRaw.addAll(List<int>.filled(512, 0xAA));
      mockRaw.addAll(smallJpeg);
      mockRaw.addAll(List<int>.filled(512, 0xAA));
      mockRaw.addAll(largeJpeg);
      mockRaw.addAll(List<int>.filled(512, 0xAA));

      final result = await AxEngine.extractRawEmbeddedPreview(
        Uint8List.fromList(mockRaw),
      );
      expect(result, isNotNull);
      expect(result!.length, 50000);
    });

    test('extractRawEmbeddedPreview returns null when no valid JPEG stream found', () async {
      if (!rustAvailable) {
        return;
      }
      final mockRaw = Uint8List.fromList(List<int>.filled(2048, 0xAA));
      final result = await AxEngine.extractRawEmbeddedPreview(mockRaw);
      expect(result, isNull);
    });

    test('extractRawEmbeddedPreview returns null when embedded JPEG too small', () async {
      if (!rustAvailable) {
        return;
      }
      // JPEG stream smaller than 16KB threshold should be ignored
      final mockRaw = _buildMockRawWithEmbeddedJpeg(
        prefixSize: 1024,
        jpegSize: 8 * 1024, // 8KB - below 16KB threshold
        suffixSize: 512,
      );
      final result = await AxEngine.extractRawEmbeddedPreview(mockRaw);
      expect(result, isNull);
    });
  });
}
