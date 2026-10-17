import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

import '../../edit/look_qr_codec.dart';

/// Offline, pure-FOSS QR code reader for images and screenshots using zxing2.
class QrImageDecoder {
  const QrImageDecoder._();

  /// Attempts to decode an ApertureX Look from decoded [imageBytes] (PNG/JPEG/WebP).
  /// Returns `null` if no valid QR code or Look payload was found.
  static LookQrPayload? decodeFromImageBytes(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return null;
    return decodeFromImage(image);
  }

  /// Decodes directly from an in-memory [img.Image].
  static LookQrPayload? decodeFromImage(img.Image image) {
    try {
      final width = image.width;
      final height = image.height;

      // Extract ARGB int array for RGBLuminanceSource
      final pixels = Int32List(width * height);
      var idx = 0;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          pixels[idx++] = (0xFF << 24) | (r << 16) | (g << 8) | b;
        }
      }

      final source = RGBLuminanceSource(width, height, pixels);
      final bitmap = BinaryBitmap(HybridBinarizer(source));
      final reader = QRCodeReader();
      final result = reader.decode(bitmap);

      if (result.text.isNotEmpty) {
        return decodeLookString(result.text);
      }
    } catch (_) {
      // Not a QR code or unreadable; return null gracefully
    }
    return null;
  }

  /// Parses a raw string (e.g. from a QR scan or EXIF UserComment) into a [LookQrPayload].
  static LookQrPayload? decodeLookString(String text) {
    try {
      return LookQrCodec.decode(text);
    } catch (_) {
      return null;
    }
  }
}
