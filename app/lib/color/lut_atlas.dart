import 'dart:math' as math;
import 'dart:typed_data';

/// A baked 3D LUT packed as a 2D RGBA8 atlas (P2 Slice D).
///
/// **Layout** (matches Rust `bake_lut3d` and `shaders/lut.frag`):
///   width  = `size * size`
///   height = `size`
///   the blue slice `b ∈ [0,size)` occupies columns `[b*size, b*size+size)`;
///   within a slice `x = red index`, `y = green index`.
class LutAtlas {
  LutAtlas({required this.size, required this.rgba})
    : assert(size >= 2),
      assert(rgba.length == size * size * size * 4);

  final int size;
  final Uint8List rgba;

  int get width => size * size;
  int get height => size;

  /// CPU reference of the shader's manual trilinear lookup — the ground truth
  /// the GPU path is checked against.
  ///
  /// Samples land on **texel centres** (`+0.5`), so the result is independent of
  /// the GPU sampler's filter mode (bilinear at a texel centre returns that
  /// texel exactly).
  List<double> sample(double r, double g, double b) {
    final n = size;
    final last = (n - 1).toDouble();
    final sr = r.clamp(0.0, 1.0) * last;
    final sg = g.clamp(0.0, 1.0) * last;
    final sb = b.clamp(0.0, 1.0) * last;

    final b0 = sb.floorToDouble();
    final b1 = math.min(b0 + 1, last);
    final fb = sb - b0;

    final x0 = sr.floorToDouble();
    final x1 = math.min(x0 + 1, last);
    final y0 = sg.floorToDouble();
    final y1 = math.min(y0 + 1, last);
    final fx = sr - x0;
    final fy = sg - y0;

    List<double> texel(double ri, double gi, double bi) {
      final idx = (gi.toInt() * width + (bi.toInt() * n + ri.toInt())) * 4;
      return [rgba[idx] / 255, rgba[idx + 1] / 255, rgba[idx + 2] / 255];
    }

    List<double> slice(double bi) {
      final c00 = texel(x0, y0, bi);
      final c10 = texel(x1, y0, bi);
      final c01 = texel(x0, y1, bi);
      final c11 = texel(x1, y1, bi);
      return _mix(_mix(c00, c10, fx), _mix(c01, c11, fx), fy);
    }

    return _mix(slice(b0), slice(b1), fb);
  }

  static List<double> _mix(List<double> a, List<double> b, double t) => [
    a[0] + (b[0] - a[0]) * t,
    a[1] + (b[1] - a[1]) * t,
    a[2] + (b[2] - a[2]) * t,
  ];
}
