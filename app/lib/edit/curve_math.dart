import 'dart:math' as math;

/// Monotone-cubic (Fritsch–Carlson) interpolation over control points in
/// `[0,1]²`, ported 1:1 from the engine (`rust/src/color.rs::curve_lut`) so
/// the tone-curve editor paints the exact curve the GPU LUT bakes. Fewer than
/// two points yields the identity.
List<double> curveLut(List<double> points, {int samples = 256}) {
  List<double> identity() =>
      List<double>.generate(samples, (i) => i / (samples - 1));
  final n = points.length ~/ 2;
  if (n < 2) return identity();

  final xs = List<double>.generate(n, (i) => points[i * 2]);
  final ys = List<double>.generate(n, (i) => points[i * 2 + 1]);

  final d = List<double>.generate(n - 1, (i) {
    final dx = xs[i + 1] - xs[i];
    return (ys[i + 1] - ys[i]) / (dx < 1e-6 ? 1e-6 : dx);
  });
  final m = List<double>.filled(n, 0);
  m[0] = d[0];
  m[n - 1] = d[n - 2];
  for (var i = 1; i < n - 1; i++) {
    m[i] = (d[i - 1] + d[i]) / 2;
  }
  for (var i = 0; i < n - 1; i++) {
    if (d[i].abs() < 1e-6) {
      m[i] = 0;
      m[i + 1] = 0;
    } else {
      final a = m[i] / d[i];
      final b = m[i + 1] / d[i];
      final s = a * a + b * b;
      if (s > 9) {
        final t = 3 / math.sqrt(s);
        m[i] = t * a * d[i];
        m[i + 1] = t * b * d[i];
      }
    }
  }

  return List<double>.generate(samples, (k) {
    final x = k / (samples - 1);
    if (x <= xs[0]) return ys[0].clamp(0.0, 1.0);
    if (x >= xs[n - 1]) return ys[n - 1].clamp(0.0, 1.0);
    var i = 0;
    while (i < n - 2 && x > xs[i + 1]) {
      i++;
    }
    final h = xs[i + 1] - xs[i];
    final t = (x - xs[i]) / h;
    final t2 = t * t;
    final t3 = t2 * t;
    final h00 = 2 * t3 - 3 * t2 + 1;
    final h10 = t3 - 2 * t2 + t;
    final h01 = -2 * t3 + 3 * t2;
    final h11 = t3 - t2;
    return (h00 * ys[i] + h10 * h * m[i] + h01 * ys[i + 1] + h11 * h * m[i + 1])
        .clamp(0.0, 1.0);
  });
}

/// Sampled curve evaluation matching the engine's `apply_curve` LUT lerp:
/// `x` in `[0,1]` → interpolated `y` in `[0,1]`.
double evalCurveLut(List<double> lut, double x) {
  final n = lut.length;
  final pos = x.clamp(0.0, 1.0) * (n - 1);
  final i = pos.floor();
  final f = pos - i;
  final a = lut[i.clamp(0, n - 1)];
  final b = lut[(i + 1).clamp(0, n - 1)];
  return a + (b - a) * f;
}
