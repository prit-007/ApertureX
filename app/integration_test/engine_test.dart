import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tessera/color/grade_spec.dart';
import 'package:tessera/engine/engine.dart';

/// On-device proof that the Dart <-> Rust bridge works end to end.
/// Run with: `flutter test integration_test/engine_test.dart -d <device>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(TesseraEngine.init);

  test('engine_version returns a non-empty version string', () async {
    final version = await TesseraEngine.version();
    expect(version, isNotEmpty);
  });

  test('brighten round-trips an RGBA byte buffer and preserves alpha', () async {
    final out = await TesseraEngine.brighten(
      Uint8List.fromList([10, 20, 30, 40]),
      5,
    );
    expect(out, equals([15, 25, 35, 40]));
  });

  test('synthetic JPEG decodes to dimensions and supports ROI crop', () async {
    final jpeg = await TesseraEngine.syntheticJpeg(width: 64, height: 48);

    final dims = await TesseraEngine.jpegDimensions(jpeg);
    expect(dims.width, 64);
    expect(dims.height, 48);

    final full = await TesseraEngine.decodeJpegRgba(jpeg);
    expect(full.rgba.length, 64 * 48 * 4);

    final roi = await TesseraEngine.decodeJpegRoi(
      jpeg,
      x: 8,
      y: 8,
      width: 16,
      height: 16,
    );
    expect(roi.width, 16);
    expect(roi.height, 16);
    expect(roi.rgba.length, 16 * 16 * 4);
  });

  test('exportJpeg grades and encodes a decodable JPEG', () async {
    double meanLuma(Uint8List buf) {
      var sum = 0.0;
      for (var i = 0; i + 3 < buf.length; i += 4) {
        sum += 0.2126 * buf[i] + 0.7152 * buf[i + 1] + 0.0722 * buf[i + 2];
      }
      return sum / (buf.length ~/ 4);
    }

    final jpeg = await TesseraEngine.syntheticJpeg(width: 64, height: 48);
    final decoded = await TesseraEngine.decodeJpegRgba(jpeg);
    final rgba = decoded.rgba;

    final neutral = await TesseraEngine.exportJpeg(
      rgba: rgba,
      width: decoded.width,
      height: decoded.height,
      spec: const GradeSpec(),
    );
    final brighter = await TesseraEngine.exportJpeg(
      rgba: rgba,
      width: decoded.width,
      height: decoded.height,
      spec: const GradeSpec(exposure: 1.0), // +1 EV must brighten the export
    );

    final nImg = await TesseraEngine.decodeJpegRgba(neutral);
    final bImg = await TesseraEngine.decodeJpegRgba(brighter);

    expect(nImg.width, 64);
    expect(nImg.height, 48);
    expect(neutral, isNotEmpty);
    expect(meanLuma(bImg.rgba), greaterThan(meanLuma(nImg.rgba)));
  });
}
