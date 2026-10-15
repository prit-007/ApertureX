import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// HALD CLUT (a 3D LUT stored as a square PNG) parsing.
///
/// Format reference (Eskil Steenberg / ImageMagick):
///   level `L` (>= 2) encodes a cube of `L*L` values per channel
///   (`size`), stored in a square image of side `L*L*L`.
///   2D pixel `(x, y)` ↔ 3D index `(r, g, b)`:
///     `x = r + (g % L) * size`
///     `y = b * L + g ~/ L`
///   with `r, g, b` in `[0, size)`.
///
/// The data is returned in `.cube` order (red fastest): `index = r + g*size + b*size²`.
class HaldClut {
  HaldClut({required this.level, required this.size, required this.data})
    : assert(level >= 2),
      assert(size == level * level),
      assert(data.length == size * size * size * 3);

  /// The HALD level (>= 2).
  final int level;

  /// Values per channel (`level²`) — the cube edge length.
  final int size;

  /// `size³` × RGB in `[0,1]`, red fastest.
  final Float32List data;

  /// Image side length for this level (`level³`).
  int get imageSize => level * level * level;

  /// True when [bytes] decodes as a PNG whose square side is a perfect cube
  /// `L³` for some integer level `L` in `[2, 16]`.
  static bool isHaldPng(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    final img.Image? decoded;
    try {
      decoded = img.decodePng(bytes);
    } catch (_) {
      return false;
    }
    if (decoded == null) return false;
    if (decoded.width != decoded.height) return false;
    return _levelFor(decoded.width) != null;
  }

  /// Parses a HALD CLUT PNG into its 3D LUT data.
  ///
  /// Throws [FormatException] when the image is not a valid HALD (not a PNG,
  /// not square, or its side is not `L³` for `L` in `[2, 16]`).
  static HaldClut extract(Uint8List bytes) {
    final img.Image? decoded;
    try {
      decoded = img.decodePng(bytes);
    } catch (_) {
      throw const FormatException('not a PNG');
    }
    if (decoded == null) {
      throw const FormatException('not a PNG');
    }
    if (decoded.width != decoded.height) {
      throw const FormatException('HALD image must be square');
    }
    final level = _levelFor(decoded.width);
    if (level == null) {
      throw FormatException(
        'image side ${decoded.width} is not a HALD level cube in [2, 16]',
      );
    }
    final size = level * level;
    final data = Float32List(size * size * size * 3);
    for (var b = 0; b < size; b++) {
      for (var g = 0; g < size; g++) {
        for (var r = 0; r < size; r++) {
          final x = r + (g % level) * size;
          final y = b * level + g ~/ level;
          final p = decoded.getPixel(x, y);
          final i = (r + g * size + b * size * size) * 3;
          data[i] = p.r / 255.0;
          data[i + 1] = p.g / 255.0;
          data[i + 2] = p.b / 255.0;
        }
      }
    }
    return HaldClut(level: level, size: size, data: data);
  }

  /// Packs the cube into the RGBA8 atlas layout our `lut.frag` samples:
  /// width = `size²`, height = `size`; the blue slice `b` occupies columns
  /// `[b*size, b*size+size)`; within a slice `x = red`, `y = green`.
  Uint8List toAtlasRgba() {
    final n = size;
    final w = n * n;
    final rgba = Uint8List(w * n * 4);
    for (var b = 0; b < n; b++) {
      for (var g = 0; g < n; g++) {
        for (var r = 0; r < n; r++) {
          final i = (r + g * n + b * n * n) * 3;
          final o = (g * w + (b * n + r)) * 4;
          rgba[o] = (data[i] * 255.0 + 0.5).clamp(0, 255).toInt();
          rgba[o + 1] = (data[i + 1] * 255.0 + 0.5).clamp(0, 255).toInt();
          rgba[o + 2] = (data[i + 2] * 255.0 + 0.5).clamp(0, 255).toInt();
          rgba[o + 3] = 255;
        }
      }
    }
    return rgba;
  }

  /// Returns the HALD level `L` when `side == L³` for integer `L` in `[2,16]`.
  static int? _levelFor(int side) {
    for (var l = 2; l <= 16; l++) {
      if (l * l * l == side) return l;
    }
    return null;
  }
}
