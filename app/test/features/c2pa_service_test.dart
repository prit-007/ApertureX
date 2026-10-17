import 'dart:io';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/features/c2pa/c2pa_service.dart';
import 'package:aperturex/src/rust/frb_generated.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final soPath = '${Directory.current.path}/rust/target/debug/librust_lib_aperturex.so';
    if (File(soPath).existsSync()) {
      await RustLib.init(externalLibrary: ExternalLibrary.open(soPath));
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('C2paService', () {
    test('initializes and generates a persistent device key', () async {
      final service = C2paService();
      final key1 = await service.getOrCreateDeviceKey();
      expect(key1.length, equals(32));

      final keyId1 = await service.getDeviceKeyId();
      expect(keyId1, startsWith('c2pa:apx:'));

      // Re-fetching should return the same persistent device key
      final key2 = await service.getOrCreateDeviceKey();
      expect(key2, equals(key1));

      final keyId2 = await service.getDeviceKeyId();
      expect(keyId2, equals(keyId1));
    });

    test('verifies image without C2PA manifest returns NoManifest status', () async {
      final service = C2paService();
      // 100 bytes of non-JPEG dummy data
      final dummy = Uint8List(100);
      final result = await service.verifyImage(dummy);

      expect(result.isValid, isFalse);
      expect(result.status, equals('NoManifest'));
      expect(result.statusMessage, contains('No C2PA Content Credentials manifest'));
    });
  });
}
