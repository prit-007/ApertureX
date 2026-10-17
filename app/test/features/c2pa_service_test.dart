import 'dart:io';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/features/c2pa/c2pa_service.dart';
import 'package:aperturex/src/rust/api/c2pa.dart';
import 'package:aperturex/src/rust/frb_generated.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockRustLibApi extends Fake implements RustLibApi {
  @override
  Future<C2paDeviceInfo> crateApiC2PaC2PaGenerateDeviceKey({
    required List<int> deviceSeed,
  }) async {
    return C2paDeviceInfo(
      privateKey: Uint8List.fromList(deviceSeed),
      keyId: 'c2pa:apx:${deviceSeed.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
    );
  }

  @override
  Future<C2paVerifyResult> crateApiC2PaC2PaVerifyImage({
    required List<int> imageBytes,
    Uint8List? devicePrivateKey,
  }) async {
    return const C2paVerifyResult(
      status: 'NoManifest',
      isValid: false,
      title: '',
      claimGenerator: '',
      signerKeyId: '',
      actions: [],
      cameraMetadata: '',
      recipeHash: '',
      pixelHash: '',
      statusMessage: 'No C2PA Content Credentials manifest found in JPEG APP11 segments',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final soPath = '${Directory.current.path}/rust/target/debug/librust_lib_aperturex.so';
    if (File(soPath).existsSync()) {
      try {
        await RustLib.init(externalLibrary: ExternalLibrary.open(soPath));
        return;
      } catch (_) {}
    }
    RustLib.initMock(api: MockRustLibApi());
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
