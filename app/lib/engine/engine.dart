import 'dart:typed_data';

import '../src/rust/api/decode.dart' show ImageDims, RgbaImage;
import '../src/rust/api/decode.dart' as rust_decode;
import '../src/rust/api/engine.dart' as rust_engine;
import '../src/rust/api/export.dart' as rust_export;
import '../src/rust/frb_generated.dart';

export '../src/rust/api/decode.dart' show ImageDims, RgbaImage;
export '../src/rust/frb_generated.dart' show RustLib;

/// Thin, app-facing facade over the generated `flutter_rust_bridge` bindings.
///
/// Keeping the generated `src/rust/` package behind this wrapper means the rest
/// of the app depends on our own names, not on codegen symbols. The engine
/// surface grows here phase by phase (decode in P1, tiles/colour/export later).
class TesseraEngine {
  const TesseraEngine._();

  /// Initialises the Rust library. Must be awaited before any engine call.
  static Future<void> init() => RustLib.init();

  // --- engine introspection -------------------------------------------------

  /// Engine crate version (typed `String` across the bridge).
  static Future<String> version() => rust_engine.engineVersion();

  /// Generates a synthetic JPEG gradient of the given size (demo/test image).
  static Future<Uint8List> syntheticJpeg({
    required int width,
    required int height,
  }) => rust_engine.syntheticJpeg(width: width, height: height);

  /// Adds [amount] to each RGB channel of an RGBA buffer (typed byte round-trip).
  static Future<Uint8List> brighten(Uint8List rgba, int amount) =>
      rust_engine.brightenRgba(rgba: rgba, amount: amount);

  // --- JPEG decode (P1) -----------------------------------------------------

  /// Reads JPEG dimensions without decoding pixels.
  static Future<ImageDims> jpegDimensions(Uint8List jpeg) =>
      rust_decode.jpegDimensions(jpeg: jpeg);

  /// Decodes a JPEG into a full RGBA8 buffer.
  static Future<RgbaImage> decodeJpegRgba(Uint8List jpeg) =>
      rust_decode.decodeJpegRgba(jpeg: jpeg);

  /// Decodes only the RGBA pixels inside the region of interest — the tile
  /// decode path.
  static Future<RgbaImage> decodeJpegRoi(
    Uint8List jpeg, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) => rust_decode.decodeJpegRoi(
    jpeg: jpeg,
    x: x,
    y: y,
    width: width,
    height: height,
  );

  // --- JPEG export (P1) -----------------------------------------------------

  /// Grades [rgba] on the CPU (mirroring the preview shader) and encodes a
  /// JPEG. [exposure] is in EV; [contrast] and [saturation] are unitless —
  /// both fed straight from [GradeUniforms.fromRecipe] so preview and export
  /// can never disagree on the inputs.
  static Future<Uint8List> exportJpeg({
    required Uint8List rgba,
    required int width,
    required int height,
    int quality = 90,
    double exposure = 0,
    double contrast = 0,
    double saturation = 0,
  }) => rust_export.encodeJpegExport(
    rgba: rgba,
    width: width,
    height: height,
    quality: quality,
    exposure: exposure,
    contrast: contrast,
    saturation: saturation,
  );
}
