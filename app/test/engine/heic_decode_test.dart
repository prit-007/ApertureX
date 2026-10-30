import 'dart:typed_data';

import 'package:aperturex/engine/engine.dart';
import 'package:aperturex/engine/image_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('HEIC / HEIF & AVIF container decode', () {
    test('detectImageFormat identifies HEIC and AVIF signatures', () {
      final heicHeader = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x18, // size = 24
        0x66, 0x74, 0x79, 0x70, // 'ftyp'
        0x68, 0x65, 0x69, 0x63, // 'heic'
        0x00, 0x00, 0x00, 0x00, // minor_version
        0x6D, 0x69, 0x66, 0x31, // compatible_brand 'mif1'
      ]);
      expect(detectImageFormat(heicHeader), ImageFormat.heic);

      final avifHeader = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x1C, // size = 28
        0x66, 0x74, 0x79, 0x70, // 'ftyp'
        0x61, 0x76, 0x69, 0x66, // 'avif'
        0x00, 0x00, 0x00, 0x00,
        0x6D, 0x69, 0x66, 0x31,
      ]);
      expect(detectImageFormat(avifHeader), ImageFormat.avif);
    });

    test('decodeHeicRgba parses ispe box dimensions', () async {
      final builder = BytesBuilder();
      // ftyp box
      builder.add([
        0x00, 0x00, 0x00, 0x18,
        0x66, 0x74, 0x79, 0x70,
        0x68, 0x65, 0x69, 0x63,
        0x00, 0x00, 0x00, 0x00,
        0x6D, 0x69, 0x66, 0x31,
        0x68, 0x65, 0x69, 0x63,
      ]);
      // ispe box with width = 120, height = 80
      builder.add([
        0x00, 0x00, 0x00, 0x14, // size 20
        0x69, 0x73, 0x70, 0x65, // 'ispe'
        0x00, 0x00, 0x00, 0x00, // version/flags
        0x00, 0x00, 0x00, 0x78, // width = 120
        0x00, 0x00, 0x00, 0x50, // height = 80
      ]);

      final bytes = builder.toBytes();
      final decoded = await AxEngine.decodeHeicRgba(bytes);
      expect(decoded.width, 120);
      expect(decoded.height, 80);
      expect(decoded.rgba.length, 120 * 80 * 4);
    });

    test('decodeHeicRgba extracts and decodes embedded JPEG preview', () async {
      // Create a small synthetic JPEG using package:image
      final imgCanvas = img.Image(width: 16, height: 16);
      img.fill(imgCanvas, color: img.ColorRgba8(200, 200, 200, 255));
      final syntheticJpeg = Uint8List.fromList(img.encodeJpg(imgCanvas, quality: 80));

      final builder = BytesBuilder();
      // ftyp header
      builder.add([
        0x00, 0x00, 0x00, 0x18,
        0x66, 0x74, 0x79, 0x70,
        0x68, 0x65, 0x69, 0x63,
        0x00, 0x00, 0x00, 0x00,
      ]);
      // Embedded JPEG payload
      builder.add(syntheticJpeg);

      final bytes = builder.toBytes();
      final decoded = await AxEngine.decodeHeicRgba(bytes);
      expect(decoded.width, 16);
      expect(decoded.height, 16);
      expect(decoded.rgba.length, 16 * 16 * 4);
    });

    test('decodeImageRgba routes HEIC container through decodeHeicRgba', () async {
      final builder = BytesBuilder();
      builder.add([
        0x00, 0x00, 0x00, 0x18,
        0x66, 0x74, 0x79, 0x70,
        0x68, 0x65, 0x69, 0x63,
        0x00, 0x00, 0x00, 0x00,
        0x6D, 0x69, 0x66, 0x31,
        0x68, 0x65, 0x69, 0x63,
      ]);
      builder.add([
        0x00, 0x00, 0x00, 0x14,
        0x69, 0x73, 0x70, 0x65,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x20, // 32
        0x00, 0x00, 0x00, 0x20, // 32
      ]);
      final bytes = builder.toBytes();
      final decoded = await AxEngine.decodeImageRgba(bytes);
      expect(decoded.width, 32);
      expect(decoded.height, 32);
    });
  });
}
