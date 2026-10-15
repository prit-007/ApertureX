import 'package:flutter/services.dart';

import '../engine/engine.dart';

/// A decoded source band: full-width strip of the original frame, RGBA.
class RoiBand {
  const RoiBand({
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int width;
  final int height;
  final Uint8List rgba;
}

/// Tier probe (#16): below this full-frame RGBA size the in-process Rust
/// decoder (full decode + crop) is cheap enough; above it the decode peak is
/// what blows the memory budget, so the platform's streaming region decoder
/// (`BitmapRegionDecoder` / `CGImageSource`) must be used.
const int kNativeRoiThresholdBytes = 64 << 20; // 64 MiB ≈ 16.7 MP

/// Whether [imageW]×[imageH] should decode bands natively rather than through
/// the Rust full-decode-and-crop fallback.
bool needsNativeRoiDecoder(int imageW, int imageH) =>
    imageW * imageH * 4 > kNativeRoiThresholdBytes;

/// Decodes full-width source bands for the high-zoom ROI overlay (#55/#16).
///
/// Large frames go through the `aperturex/roi_decode` platform channel
/// (Android's `BitmapRegionDecoder`, iOS's `CGImageSource`); small frames —
/// and every platform failure, including widget tests where no plugin is
/// registered — fall back to the Rust decoder, which decodes the frame
/// in-process and crops.
class RoiDecoder {
  RoiDecoder({Future<RoiBand> Function({
    required Uint8List bytes,
    required int x,
    required int y,
    required int width,
    required int height,
  })?
  rustFallback})
    : _rustFallback = rustFallback ?? _rustDecodeBand;

  final Future<RoiBand> Function({
    required Uint8List bytes,
    required int x,
    required int y,
    required int width,
    required int height,
  })
  _rustFallback;

  static const MethodChannel _channel = MethodChannel('aperturex/roi_decode');

  static Future<RoiBand> _rustDecodeBand({
    required Uint8List bytes,
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    final img = await TesseraEngine.decodeJpegRoi(
      bytes,
      x: x,
      y: y,
      width: width,
      height: height,
    );
    return RoiBand(
      width: img.width.toInt(),
      height: img.height.toInt(),
      rgba: img.rgba,
    );
  }

  /// Decodes the full-width band `[bandTop, bandBottom)` of [imageW]×[imageH],
  /// or returns null when the band is empty or outside the image.
  Future<RoiBand?> decodeBand({
    required Uint8List bytes,
    required int imageW,
    required int imageH,
    required int bandTop,
    required int bandBottom,
  }) async {
    if (imageW <= 0 || imageH <= 0) return null;
    if (bandTop < 0 || bandBottom > imageH || bandBottom <= bandTop) {
      return null;
    }
    return _decode(
      bytes: bytes,
      imageW: imageW,
      imageH: imageH,
      x: 0,
      y: bandTop,
      width: imageW,
      height: bandBottom - bandTop,
    );
  }

  /// Decodes the arbitrary rect `(x, y, width, height)` of [imageW]×[imageH]
  /// — the tile fetch path (#16). Same tier probe, platform contract and
  /// fallbacks as [decodeBand]: the native handlers take any rect
  /// (`BitmapRegionDecoder.decodeRegion` on Android, `CGImageSource` crop on
  /// iOS), and small frames stay on the in-process Rust decoder.
  Future<RoiBand?> decodeRect({
    required Uint8List bytes,
    required int imageW,
    required int imageH,
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    if (imageW <= 0 || imageH <= 0 || width <= 0 || height <= 0) return null;
    if (x < 0 || y < 0 || x + width > imageW || y + height > imageH) {
      return null;
    }
    return _decode(
      bytes: bytes,
      imageW: imageW,
      imageH: imageH,
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }

  Future<RoiBand?> _decode({
    required Uint8List bytes,
    required int imageW,
    required int imageH,
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    if (!needsNativeRoiDecoder(imageW, imageH)) {
      return _rustFallback(
        bytes: bytes,
        x: x,
        y: y,
        width: width,
        height: height,
      );
    }
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'decodeBand',
        <String, Object?>{
          'jpeg': bytes,
          'x': x,
          'y': y,
          'width': width,
          'height': height,
        },
      );
      if (result == null) return null;
      final rgba = result['rgba'];
      if (rgba is! Uint8List) return null;
      return RoiBand(
        width: (result['width'] as num?)?.toInt() ?? 0,
        height: (result['height'] as num?)?.toInt() ?? 0,
        rgba: rgba,
      );
    } on MissingPluginException {
      return _rustFallback(
        bytes: bytes,
        x: x,
        y: y,
        width: width,
        height: height,
      );
    } on PlatformException {
      return _rustFallback(
        bytes: bytes,
        x: x,
        y: y,
        width: width,
        height: height,
      );
    }
  }
}
