import 'dart:typed_data';

import '../src/rust/api/engine.dart' as rust;
import '../src/rust/frb_generated.dart';

export '../src/rust/frb_generated.dart' show RustLib;

/// Thin, app-facing facade over the generated `flutter_rust_bridge` bindings.
///
/// Keeping the generated `src/rust/` package behind this wrapper means the rest
/// of the app depends on our own names, not on codegen symbols. The real engine
/// surface (decode/tile/colour) grows here from phase P1 onward.
class TesseraEngine {
  const TesseraEngine._();

  /// Initialises the Rust library. Must be awaited before any engine call.
  static Future<void> init() => RustLib.init();

  /// Engine crate version (typed `String` across the bridge).
  static Future<String> version() => rust.engineVersion();

  /// Adds [amount] to each RGB channel of an RGBA buffer (typed byte round-trip).
  static Future<Uint8List> brighten(Uint8List rgba, int amount) =>
      rust.brightenRgba(rgba: rgba, amount: amount);
}
