import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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
}
