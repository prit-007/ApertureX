import 'dart:typed_data';

/// A parsed Adobe `.cube` 3D LUT (or a 1D curve expanded to 3D).
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

  /// Largest cube axis a 1D curve is expanded to (matches the engine's 65³ LUT).
  static const int max1DExpand = 65;

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

  /// Serializes this 3D LUT to standard Adobe `.cube` format (DaVinci Resolve / Premiere compliant).
  String toCubeText({String? title}) {
    final buf = StringBuffer();
    buf.writeln('# Created by ApertureX');
    buf.writeln('TITLE "${title ?? this.title ?? 'ApertureX Grade'}"');
    buf.writeln('LUT_3D_SIZE $size');
    buf.writeln('DOMAIN_MIN 0.0 0.0 0.0');
    buf.writeln('DOMAIN_MAX 1.0 1.0 1.0');
    buf.writeln('');
    for (var i = 0; i < data.length; i += 3) {
      buf.writeln(
        '${data[i].toStringAsFixed(6)} ${data[i + 1].toStringAsFixed(6)} ${data[i + 2].toStringAsFixed(6)}',
      );
    }
    return buf.toString();
  }

  /// Expands a per-channel 1D `curve` (`size1D` × RGB) into a separable 3D LUT.
  ///
  /// The cube is resampled to `min(size1D, max1DExpand)` per axis (or `resample`
  /// when given) so oversized curves (1024-point is typical) stay memory-cheap.
  factory CubeLut.from1D({
    required Float32List curve,
    required int size1D,
    String? title,
    int? resample,
  }) {
    if (size1D < 2 || curve.length != size1D * 3) {
      throw FormatException('expected $size1D 1D entries');
    }
    final cap = size1D < max1DExpand ? size1D : max1DExpand;
    final n = (resample ?? cap).clamp(2, cap);
    double sample(int channel, double t) {
      final pos = t * (size1D - 1);
      final k0 = pos.floor();
      final k1 = k0 >= size1D - 1 ? size1D - 1 : k0 + 1;
      final f = pos - k0;
      return curve[k0 * 3 + channel] * (1 - f) + curve[k1 * 3 + channel] * f;
    }

    final out = Float32List(n * n * n * 3);
    for (var b = 0; b < n; b++) {
      for (var g = 0; g < n; g++) {
        for (var r = 0; r < n; r++) {
          final i = (r + g * n + b * n * n) * 3;
          out[i] = sample(0, n == 1 ? 0 : r / (n - 1));
          out[i + 1] = sample(1, n == 1 ? 0 : g / (n - 1));
          out[i + 2] = sample(2, n == 1 ? 0 : b / (n - 1));
        }
      }
    }
    return CubeLut(size: n, data: out, title: title);
  }

  /// Parses `.cube` text. Supports `TITLE`, `LUT_3D_SIZE`, `LUT_1D_SIZE`
  /// (expanded per channel) and `DOMAIN_MIN/MAX` (values are assumed to already
  /// lie in `[0,1]`, the common case).
  static CubeLut parse(String text) {
    var size3d = 0;
    var size1d = 0;
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
        size3d = int.parse(line.split(ws).last);
        continue;
      }
      if (upper.startsWith('LUT_1D_SIZE')) {
        size1d = int.parse(line.split(ws).last);
        continue;
      }
      if (upper.startsWith('DOMAIN_MIN') || upper.startsWith('DOMAIN_MAX')) {
        continue; // assume 0..1 (documented limitation)
      }

      final parts = line.split(ws);
      if (parts.length >= 3) {
        values
          ..add(double.parse(parts[0]))
          ..add(double.parse(parts[1]))
          ..add(double.parse(parts[2]));
      }
    }

    if (size1d > 0) {
      if (values.length != size1d * 3) {
        throw FormatException(
          'expected $size1d 1D entries, got ${values.length ~/ 3}',
        );
      }
      return CubeLut.from1D(
        curve: Float32List.fromList(values),
        size1D: size1d,
        title: title,
      );
    }

    if (size3d <= 0) {
      throw const FormatException('missing LUT_3D_SIZE');
    }
    final expected = size3d * size3d * size3d * 3;
    if (values.length != expected) {
      throw FormatException(
        'expected ${size3d * size3d * size3d} entries, got ${values.length ~/ 3}',
      );
    }
    return CubeLut(
      size: size3d,
      data: Float32List.fromList(values),
      title: title,
    );
  }

  /// Parses an Autodesk `.3dl` LUT.
  ///
  /// `.3dl` lists integer RGB triplets ordered **blue fastest**, then green,
  /// then red. The grid size comes from a `Mesh L` / `LATTICE L` / `3DMESH`
  /// header or a coordinate-ladder line; the scale is `2^bits − 1` when a bit
  /// depth is declared (default 10), else the ladder's maximum code.
  static CubeLut parse3dl(String text) {
    var size = 0;
    var bits = 0;
    var ladderMax = 0;
    final values = <double>[];
    final ws = RegExp(r'\s+');

    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#')) {
        final m = RegExp(r'^#\s*(\d{1,2})\s*$').firstMatch(line);
        if (m != null) bits = int.parse(m.group(1)!);
        continue;
      }

      final header = RegExp(
        r'^(?:3D)?MESH|^LATTICE',
        caseSensitive: false,
      ).firstMatch(line);
      if (header != null) {
        final ints = RegExp(r'\d+')
            .allMatches(line.replaceRange(0, header.end, ''))
            .map((m) => int.parse(m.group(0)!))
            .toList();
        if (ints.isNotEmpty) size = ints[0];
        if (ints.length > 1) bits = ints[1];
        continue;
      }

      if (!RegExp('[A-Za-z]').hasMatch(line)) {
        final parts = line.split(ws);
        if (parts.length == 3) {
          values
            ..add(double.parse(parts[0]))
            ..add(double.parse(parts[1]))
            ..add(double.parse(parts[2]));
        } else {
          // Coordinate ladder: its length is the cube size, its max the scale.
          size = parts.length;
          for (final p in parts) {
            final v = int.tryParse(p) ?? 0;
            if (v > ladderMax) ladderMax = v;
          }
        }
      }
    }

    if (size < 2) {
      throw const FormatException('missing .3dl grid size');
    }
    final expected = size * size * size * 3;
    if (values.length != expected) {
      throw FormatException(
        'expected ${size * size * size} entries, got ${values.length ~/ 3}',
      );
    }

    final scale = bits > 0
        ? (1 << bits) - 1
        : (ladderMax > 0 ? ladderMax : _maxValue(values));
    final s = scale <= 0 ? 1.0 : scale.toDouble();

    // Convert blue-fastest source order into our red-fastest storage order.
    final out = Float32List(expected);
    for (var r = 0; r < size; r++) {
      for (var g = 0; g < size; g++) {
        for (var b = 0; b < size; b++) {
          final src = (b + g * size + r * size * size) * 3;
          final dst = (r + g * size + b * size * size) * 3;
          out[dst] = values[src] / s;
          out[dst + 1] = values[src + 1] / s;
          out[dst + 2] = values[src + 2] / s;
        }
      }
    }
    return CubeLut(size: size, data: out);
  }

  /// Parses either `.cube` or `.3dl` text, sniffing by the file header.
  static CubeLut parseAuto(String text) {
    final isCube = RegExp(
      r'LUT_(?:1D|3D)_SIZE',
      caseSensitive: false,
    ).hasMatch(text);
    return isCube ? parse(text) : parse3dl(text);
  }

  static double _maxValue(List<double> values) {
    var max = 0.0;
    for (final v in values) {
      if (v > max) max = v;
    }
    return max;
  }
}
