import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../src/rust/api/c2pa.dart';
import '../../src/rust/api/export.dart';

const _kDeviceKeyPrefKey = 'c2pa_device_private_key_b64';
const _kDeviceKeyIdPrefKey = 'c2pa_device_key_id';

/// Service managing offline C2PA Content Credentials signing keys and provenance verification.
class C2paService {
  Uint8List? _cachedPrivateKey;
  String? _cachedKeyId;

  /// Retrieves the existing device signing key, or deterministically generates
  /// and persists a new 32-byte key seed on this device.
  Future<Uint8List> getOrCreateDeviceKey() async {
    if (_cachedPrivateKey != null) return _cachedPrivateKey!;

    final prefs = await SharedPreferences.getInstance();
    final storedB64 = prefs.getString(_kDeviceKeyPrefKey);

    if (storedB64 != null && storedB64.isNotEmpty) {
      final key = base64Decode(storedB64);
      _cachedPrivateKey = key;
      _cachedKeyId = prefs.getString(_kDeviceKeyIdPrefKey);
      return key;
    }

    // Generate fresh entropy seed
    final random = Random.secure();
    final seed = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      seed[i] = random.nextInt(256);
    }

    final info = await c2PaGenerateDeviceKey(deviceSeed: seed);
    final keyBytes = Uint8List.fromList(info.privateKey);

    await prefs.setString(_kDeviceKeyPrefKey, base64Encode(keyBytes));
    await prefs.setString(_kDeviceKeyIdPrefKey, info.keyId);

    _cachedPrivateKey = keyBytes;
    _cachedKeyId = info.keyId;
    return keyBytes;
  }

  /// Returns the human-readable public identifier for this device's signer key.
  Future<String> getDeviceKeyId() async {
    if (_cachedKeyId != null) return _cachedKeyId!;
    await getOrCreateDeviceKey();
    return _cachedKeyId ?? 'c2pa:apx:unknown';
  }

  /// Verifies the cryptographic provenance, pixel hash, and signature of an image.
  Future<C2paVerifyResult> verifyImage(Uint8List imageBytes) async {
    final key = await getOrCreateDeviceKey();
    return c2PaVerifyImage(
      imageBytes: imageBytes,
      devicePrivateKey: key,
    );
  }

  /// Constructs a C2paExportSpec for embedding credentials into an exported JPEG.
  Future<C2paExportSpec> buildExportSpec({
    required bool enabled,
    required String recipeJson,
    required String exifSummary,
  }) async {
    if (!enabled) {
      return C2paExportSpec(
        enableC2Pa: false,
        devicePrivateKey: Uint8List(0),
        recipeJson: '',
        exifSummary: '',
      );
    }

    final key = await getOrCreateDeviceKey();
    return C2paExportSpec(
      enableC2Pa: true,
      devicePrivateKey: key,
      recipeJson: recipeJson,
      exifSummary: exifSummary,
    );
  }
}

/// Riverpod provider for C2paService.
final c2paServiceProvider = Provider<C2paService>((ref) {
  return C2paService();
});

/// Riverpod future provider for the active device key ID.
final c2paDeviceKeyIdProvider = FutureProvider<String>((ref) {
  return ref.watch(c2paServiceProvider).getDeviceKeyId();
});
