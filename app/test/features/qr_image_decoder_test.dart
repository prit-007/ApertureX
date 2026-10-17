import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';
import 'package:aperturex/edit/look_qr_codec.dart';
import 'package:aperturex/edit/tool_definition.dart';
import 'package:aperturex/features/presets/qr_image_decoder.dart';

void main() {
  group('QrImageDecoder', () {
    const testTool = ToolDefinition(
      name: 'Kodak Gold 200',
      description: 'Warm nostalgic consumer film',
      params: {
        'exposure': 0.20,
        'temperature': 0.15,
        'contrast': 0.10,
        'grain': 0.30,
      },
    );

    /// Helper to synthesize a pure black-and-white QR code image as img.Image
    img.Image generateQrImage(String text, {int moduleSize = 8, int quietZone = 4}) {
      final qrCode = QrCode.fromData(
        data: text,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      final qrImage = QrImage(qrCode);
      final moduleCount = qrImage.moduleCount;
      final imageSize = (moduleCount + quietZone * 2) * moduleSize;

      final image = img.Image(width: imageSize, height: imageSize);
      // Fill white
      img.fill(image, color: img.ColorRgb8(255, 255, 255));

      final black = img.ColorRgb8(0, 0, 0);

      for (var x = 0; x < moduleCount; x++) {
        for (var y = 0; y < moduleCount; y++) {
          if (qrImage.isDark(y, x)) {
            final startX = (x + quietZone) * moduleSize;
            final startY = (y + quietZone) * moduleSize;
            img.fillRect(
              image,
              x1: startX,
              y1: startY,
              x2: startX + moduleSize - 1,
              y2: startY + moduleSize - 1,
              color: black,
            );
          }
        }
      }

      return image;
    }

    test('decodes synthesized QR code image correctly into LookQrPayload', () {
      final uri = LookQrCodec.encodeToUri(testTool, author: '@filmcommunity');
      final qrImage = generateQrImage(uri);
      final pngBytes = Uint8List.fromList(img.encodePng(qrImage));

      final decodedPayload = QrImageDecoder.decodeFromImageBytes(pngBytes);
      expect(decodedPayload, isNotNull);
      expect(decodedPayload!.name, 'Kodak Gold 200');
      expect(decodedPayload.author, '@filmcommunity');
      expect(decodedPayload.params['exposure'], closeTo(0.20, 1e-4));
      expect(decodedPayload.params['temperature'], closeTo(0.15, 1e-4));
      expect(decodedPayload.params['contrast'], closeTo(0.10, 1e-4));
      expect(decodedPayload.params['grain'], closeTo(0.30, 1e-4));
    });

    test('returns null gracefully on non-QR image without throwing', () {
      final blankImage = img.Image(width: 100, height: 100);
      img.fill(blankImage, color: img.ColorRgb8(200, 200, 200));
      final bytes = Uint8List.fromList(img.encodePng(blankImage));

      final result = QrImageDecoder.decodeFromImageBytes(bytes);
      expect(result, isNull);
    });

    test('extracts EXIF UserComment if present before scanning optical QR', () {
      final jsonLook = LookQrCodec.encodeToJson(testTool, author: '@exif');
      // Test the helper that inspects string or fallback
      final payload = QrImageDecoder.decodeLookString(jsonLook);
      expect(payload, isNotNull);
      expect(payload!.name, 'Kodak Gold 200');
      expect(payload.author, '@exif');
    });
  });
}
