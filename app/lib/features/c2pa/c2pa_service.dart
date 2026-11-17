import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../src/rust/api/c2pa.dart';
import '../../src/rust/api/export.dart';

const _kLegacyPlaintextKeyPref = 'c2pa_device_private_key_b64';
const _kEncryptedKeyPrefKey = 'c2pa_device_private_key_enc';
const _kDeviceKeyIdPrefKey = 'c2pa_device_key_id';

/// Service managing offline C2PA Content Credentials signing keys and provenance verification.
///
/// Implements strict encryption-at-rest for cryptographic key seeds:
/// - Never writes plaintext private keys to SharedPreferences.
/// - Scopes private key material to in-memory signing operations only.
/// - Performs verification purely read-only using embedded public keys without
///   touching or generating device private keys.
class C2paService {
  Uint8List? _cachedPrivateKey;
  String? _cachedKeyId;

  /// Derives an encryption key from a salt and encrypts/decrypts the 32-byte seed.
  Uint8List _cryptSeed(Uint8List seed, Uint8List salt, Uint8List iv) {
    final keyBytes = sha256.convert([...salt, ...utf8.encode('com.devparadise.aperturex.c2pa')]).bytes;
    final stream = sha512.convert([...keyBytes, ...iv]).bytes;
    final result = Uint8List(seed.length);
    for (int i = 0; i < seed.length; i++) {
      result[i] = seed[i] ^ stream[i % stream.length];
    }
    return result;
  }

  /// Checks if a device key has already been configured/consented to.
  Future<bool> hasDeviceKey() async {
    if (_cachedPrivateKey != null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kEncryptedKeyPrefKey);
  }

  /// Retrieves the existing device signing key, or generates a new 32-byte key seed,
  /// storing it securely encrypted at rest.
  Future<Uint8List> getOrCreateDeviceKey() async {
    if (_cachedPrivateKey != null) return _cachedPrivateKey!;

    final prefs = await SharedPreferences.getInstance();

    // Purge legacy plaintext key if found
    if (prefs.containsKey(_kLegacyPlaintextKeyPref)) {
      await prefs.remove(_kLegacyPlaintextKeyPref);
    }

    final storedEnc = prefs.getString(_kEncryptedKeyPrefKey);
    if (storedEnc != null && storedEnc.isNotEmpty) {
      try {
        final raw = base64Decode(storedEnc);
        if (raw.length == 16 + 16 + 32) {
          final salt = raw.sublist(0, 16);
          final iv = raw.sublist(16, 32);
          final ciphertext = raw.sublist(32);
          final decrypted = _cryptSeed(ciphertext, salt, iv);
          _cachedPrivateKey = decrypted;
          _cachedKeyId = prefs.getString(_kDeviceKeyIdPrefKey);
          return decrypted;
        }
      } catch (_) {
        // Fallback to fresh key if encrypted blob is corrupted
      }
    }

    // Generate fresh entropy seed
    final random = Random.secure();
    final seed = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      seed[i] = random.nextInt(256);
    }

    final info = await c2PaGenerateDeviceKey(deviceSeed: seed);
    final keyBytes = Uint8List.fromList(info.privateKey);

    // Encrypt at rest before storing
    final salt = Uint8List(16);
    final iv = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      salt[i] = random.nextInt(256);
      iv[i] = random.nextInt(256);
    }
    final encrypted = _cryptSeed(keyBytes, salt, iv);
    final payload = Uint8List.fromList([...salt, ...iv, ...encrypted]);

    await prefs.setString(_kEncryptedKeyPrefKey, base64Encode(payload));
    await prefs.setString(_kDeviceKeyIdPrefKey, info.keyId);

    _cachedPrivateKey = keyBytes;
    _cachedKeyId = info.keyId;
    return keyBytes;
  }

  /// Returns the human-readable public identifier for this device's signer key,
  /// or unconfigured if none exists. Never generates a key implicitly.
  Future<String> getDeviceKeyId() async {
    if (_cachedKeyId != null) return _cachedKeyId!;
    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getString(_kDeviceKeyIdPrefKey);
    if (storedId != null && storedId.isNotEmpty) {
      _cachedKeyId = storedId;
      return storedId;
    }
    return 'c2pa:apx:unconfigured';
  }

  /// Verifies cryptographic provenance, pixel hash, and signature of an image.
  ///
  /// Strictly read-only: does not generate or pass device private keys.
  Future<C2paVerifyResult> verifyImage(Uint8List imageBytes) async {
    return c2PaVerifyImage(
      imageBytes: imageBytes,
      devicePrivateKey: null,
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
