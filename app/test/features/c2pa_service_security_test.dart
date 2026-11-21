import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/features/c2pa/c2pa_service.dart';
import 'package:aperturex/settings/export_branding_settings.dart';
import 'package:aperturex/src/rust/api/c2pa.dart';
import 'package:aperturex/src/rust/frb_generated.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockRustLibApi extends Fake implements RustLibApi {
  int generateKeyCallCount = 0;
  List<int>? lastVerifyPrivateKey;

  @override
  Future<C2paDeviceInfo> crateApiC2PaC2PaGenerateDeviceKey({
    required List<int> deviceSeed,
  }) async {
    generateKeyCallCount++;
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
    lastVerifyPrivateKey = devicePrivateKey;
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
  late MockRustLibApi mockApi;

  setUpAll(() async {
    mockApi = MockRustLibApi();
    final soPath = '${Directory.current.path}/rust/target/debug/librust_lib_aperturex.so';
    if (File(soPath).existsSync()) {
      try {
        await RustLib.init(externalLibrary: ExternalLibrary.open(soPath));
        return;
      } catch (_) {}
    }
    RustLib.initMock(api: mockApi);
  });

  setUp(() {
    mockApi.generateKeyCallCount = 0;
    mockApi.lastVerifyPrivateKey = null;
    SharedPreferences.setMockInitialValues({});
  });

  group('C2PA Security & Key Boundary Auditing', () {
    test('verifyImage is strictly read-only and never generates or passes private key', () async {
      final service = C2paService();
      final dummyBytes = Uint8List(64);

      final result = await service.verifyImage(dummyBytes);

      expect(result.status, equals('NoManifest'));
      expect(mockApi.generateKeyCallCount, equals(0),
          reason: 'verifyImage must never invoke key generation');
      expect(mockApi.lastVerifyPrivateKey, isNull,
          reason: 'verifyImage must pass null devicePrivateKey to Rust');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('c2pa_device_private_key_b64'), isNull);
      expect(prefs.getString('c2pa_device_private_key_enc'), isNull);
    });

    test('getOrCreateDeviceKey encrypts key at rest and never writes plaintext b64 to SharedPreferences', () async {
      final service = C2paService();
      final key = await service.getOrCreateDeviceKey();
      expect(key.length, equals(32));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('c2pa_device_private_key_b64'), isNull,
          reason: 'Plaintext private key seed must never exist in SharedPreferences');
      expect(prefs.getString('c2pa_device_private_key_enc'), isNotNull,
          reason: 'Key must be encrypted at rest on device');
    });

    test('purges legacy plaintext private key if found in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'c2pa_device_private_key_b64': 'dGVzdF9wbGFpbnRleHRfc2VlZF9leHBvc2VkX2tleV8xMjM=',
      });

      final service = C2paService();
      await service.getOrCreateDeviceKey();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('c2pa_device_private_key_b64'), isNull,
          reason: 'Legacy plaintext key must be wiped');
    });

    test('getDeviceKeyId does not generate key when unconfigured', () async {
      final service = C2paService();
      final id = await service.getDeviceKeyId();
      expect(id, equals('c2pa:apx:unconfigured'));
      expect(mockApi.generateKeyCallCount, equals(0));
    });

    test('enableC2pa defaults to false (opt-in requirement)', () {
      const settings = ExportBrandingSettings();
      expect(settings.enableC2pa, isFalse,
          reason: 'C2PA identity signing must be opt-in, not enabled by default without consent');
    });
  });
}
