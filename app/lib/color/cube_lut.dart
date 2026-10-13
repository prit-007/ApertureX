import 'dart:typed_data';

/// A parsed Adobe `.cube` 3D LUT.
///
/// Data is stored `size³` × RGB, in the `.cube` order (red fastest):
/// `index = r + g*size + b*size²`, each channel in `[0,1]`.
class CubeLut {
  CubeLut({required this.size, required this.data, this.title})
    : assert(size >= 2, 'size must be >= 2'),
      assert(data.length == size * size * size * 3);

  final int size;
  final Float32List data;
  final String? title;

  /// Packs the LUT into the RGBA8 atlas layout our `lut.frag` samples:
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

  /// Parses `.cube` text. Supports `TITLE`, `LUT_3D_SIZE`, and `DOMAIN_MIN/MAX`
  /// (values are assumed to already lie in `[0,1]`, the common case).
  static CubeLut parse(String text) {
    var size = 0;
    String? title;
    final values = <double>[];
    final ws = RegExp(r'\s+');

    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final upper = line.toUpperCase();

      if (upper.startsWith('TITLE')) {
        title = RegExp(r'"(.*)"').firstMatch(line)?.group(1);
        continue;
      }
      if (upper.startsWith('LUT_3D_SIZE')) {
        size = int.parse(line.split(ws).last);
        continue;
      }
      if (upper.startsWith('DOMAIN_MIN') || upper.startsWith('DOMAIN_MAX')) {
        continue; // assume 0..1 (documented limitation)
      }
      if (upper.startsWith('LUT_1D_SIZE')) {
        throw const FormatException('1D LUTs are not supported');
      }

      final parts = line.split(ws);
      if (parts.length >= 3) {
        values
          ..add(double.parse(parts[0]))
          ..add(double.parse(parts[1]))
          ..add(double.parse(parts[2]));
      }
    }

    if (size <= 0) {
      throw const FormatException('missing LUT_3D_SIZE');
    }
    final expected = size * size * size * 3;
    if (values.length != expected) {
      throw FormatException(
        'expected ${size * size * size} entries, got ${values.length ~/ 3}',
      );
    }
    return CubeLut(
      size: size,
      data: Float32List.fromList(values),
      title: title,
    );
  }
}
