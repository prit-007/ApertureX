import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/viewport/exif_orientation.dart';

Uint8List _makeJpegWithExifOrientation(int orientation, {bool isLittleEndian = true}) {
  final header = <int>[0xFF, 0xD8]; // SOI
  final tiff = <int>[];
  if (isLittleEndian) {
    tiff.addAll([0x49, 0x49]); // 'II'
    tiff.addAll([42, 0]); // 42
    tiff.addAll([8, 0, 0, 0]); // offset to IFD0 (8 bytes)
    // IFD0: 1 tag
    tiff.addAll([1, 0]); // tag count
    // Tag 0x0112: Orientation, SHORT (3), count 1, value
    tiff.addAll([0x12, 0x01, 3, 0, 1, 0, 0, 0, orientation & 0xFF, (orientation >> 8) & 0xFF, 0, 0]);
    tiff.addAll([0, 0, 0, 0]); // next IFD offset
  } else {
    tiff.addAll([0x4D, 0x4D]); // 'MM'
    tiff.addAll([0, 42]); // 42
    tiff.addAll([0, 0, 0, 8]); // offset to IFD0 (8 bytes)
    // IFD0: 1 tag
    tiff.addAll([0, 1]); // tag count
    // Tag 0x0112: Orientation, SHORT (3), count 1, value
    tiff.addAll([0x01, 0x12, 0, 3, 0, 0, 0, 1, (orientation >> 8) & 0xFF, orientation & 0xFF, 0, 0]);
    tiff.addAll([0, 0, 0, 0]); // next IFD offset
  }

  final exifPayload = <int>[
    0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // "Exif\0\0"
    ...tiff,
  ];
  final app1Len = exifPayload.length + 2;
  final app1 = <int>[
    0xFF, 0xE1,
    (app1Len >> 8) & 0xFF, app1Len & 0xFF,
    ...exifPayload,
  ];
  final eoi = <int>[0xFF, 0xD9];

  return Uint8List.fromList([...header, ...app1, ...eoi]);
}

void main() {
  group('readExifOrientation', () {
    test('returns 1 for non-JPEG or empty bytes', () {
      expect(readExifOrientation(Uint8List(0)), 1);
      expect(readExifOrientation(Uint8List.fromList([1, 2, 3, 4])), 1);
    });

    test('returns 1 for JPEG without APP1 segment', () {
      final plainJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
      expect(readExifOrientation(plainJpeg), 1);
    });

    test('reads orientation correctly from Little Endian EXIF', () {
      for (var o = 1; o <= 8; o++) {
        final jpeg = _makeJpegWithExifOrientation(o, isLittleEndian: true);
        expect(readExifOrientation(jpeg), o, reason: 'failed for orientation $o (LE)');
      }
    });

    test('reads orientation correctly from Big Endian EXIF', () {
      for (var o = 1; o <= 8; o++) {
        final jpeg = _makeJpegWithExifOrientation(o, isLittleEndian: false);
        expect(readExifOrientation(jpeg), o, reason: 'failed for orientation $o (BE)');
      }
    });
  });

  group('exifSwapsDimensions', () {
    test('standard orientations (1..4) do not swap width and height', () {
      expect(exifSwapsDimensions(1), isFalse);
      expect(exifSwapsDimensions(2), isFalse);
      expect(exifSwapsDimensions(3), isFalse);
      expect(exifSwapsDimensions(4), isFalse);
    });

    test('90 and 270 degree orientations (5..8) swap width and height', () {
      expect(exifSwapsDimensions(5), isTrue); // transpose
      expect(exifSwapsDimensions(6), isTrue); // 90 CW (typical phone portrait photo)
      expect(exifSwapsDimensions(7), isTrue); // transverse
      expect(exifSwapsDimensions(8), isTrue); // 270 CW
    });
  });

  group('displayDimensions', () {
    test('preserves file dimensions for unrotated orientations', () {
      final dims = computeDisplayDimensions(rawWidth: 4000, rawHeight: 3000, orientation: 1);
      expect(dims.width, 4000);
      expect(dims.height, 3000);
    });

    test('swaps file dimensions for 90-degree phone portrait orientation 6', () {
      final dims = computeDisplayDimensions(rawWidth: 4000, rawHeight: 3000, orientation: 6);
      expect(dims.width, 3000);
      expect(dims.height, 4000);
    });

    test('computes decode targets that preserve aspect ratio and limit longest side to maxDim', () {
      // Phone portrait photo: raw file is 4000x3000, oriented as 3000x4000.
      // With maxDim 1440, display height should be target 1440, NOT width 1440!
      final target = computeDecodeTarget(
        rawWidth: 4000,
        rawHeight: 3000,
        orientation: 6,
        maxDim: 1440,
      );
      expect(target.targetWidth, isNull);
      expect(target.targetHeight, 1440);
    });

    test('computes decode targets for landscape photo orientation 1', () {
      final target = computeDecodeTarget(
        rawWidth: 4000,
        rawHeight: 3000,
        orientation: 1,
        maxDim: 1440,
      );
      expect(target.targetWidth, 1440);
      expect(target.targetHeight, isNull);
    });
  });
}
