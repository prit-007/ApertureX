import 'package:flutter/services.dart';

/// Platform bridge for spike B's zero-copy texture delivery.
///
/// Android registers a `SurfaceTexture`-backed texture through
/// `TextureRegistry`, hands its `Surface` to Rust (via the JNI
/// `bindPreviewSurface` entry point), and Rust writes graded frames straight
/// into it. Every method degrades gracefully — iOS and the widget-test
/// binding have no plugin, so callers fall back to the spike-A return-frame
/// path.
class PreviewTextureChannel {
  const PreviewTextureChannel._();

  static const MethodChannel _channel = MethodChannel(
    'aperturex/preview_texture',
  );

  /// Registers a `width`×`height` platform texture and returns its Flutter
  /// texture id, or `null` when unsupported (iOS, tests) or creation failed.
  static Future<int?> create({required int width, required int height}) async {
    try {
      return await _channel.invokeMethod<int>('create', <String, Object?>{
        'width': width,
        'height': height,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Binds [handle]'s resident preview to the texture's native surface. Rust
  /// then owns the write path; returns `false` when unsupported or on failure.
  static Future<bool> bind({
    required int textureId,
    required int handle,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('bind', <String, Object?>{
        'textureId': textureId,
        'handle': handle,
      });
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Releases the platform texture. Safe to call after a failed [create].
  static Future<void> dispose(int textureId) async {
    try {
      await _channel.invokeMethod<void>('dispose', <String, Object?>{
        'textureId': textureId,
      });
    } on MissingPluginException {
      // No plugin (iOS/tests) — nothing to release.
    } on PlatformException {
      // Best-effort teardown.
    }
  }
}
