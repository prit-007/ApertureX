import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:aperturex/edit/curve_math.dart';

void main() {
  List<double> flat(List<(double, double)> pts) => [
    for (final (x, y) in pts) ...[x, y],
  ];

  test('fewer than two control points yields the identity LUT', () {
    expect(curveLut(<double>[]), List<double>.generate(256, (i) => i / 255));
    expect(
      curveLut(flat([(0.4, 0.6)])),
      List<double>.generate(256, (i) => i / 255),
    );
  });

  test('control points lie exactly on the curve (within 1/255)', () {
    final pts = flat([(0, 0), (0.25, 0.2), (0.75, 0.85), (1, 1)]);
    final lut = curveLut(pts);
    for (final (x, y) in [(0.0, 0.0), (0.25, 0.2), (0.75, 0.85), (1.0, 1.0)]) {
      final i = (x * 255).round();
      expect(lut[i], closeTo(y, 1 / 255), reason: 'x=$x');
    }
  });

  test('the curve is monotone (non-decreasing) between points', () {
    final lut = curveLut(flat([(0, 0), (0.3, 0.55), (0.6, 0.6), (1, 1)]));
    for (var i = 1; i < lut.length; i++) {
      expect(lut[i] >= lut[i - 1] - 1e-6, isTrue, reason: 'bin $i');
    }
  });

  test('no straight segments: samples deviate from the polyline', () {
    final pts = flat([(0, 0), (0.5, 0.2), (1, 1)]);
    final lut = curveLut(pts);
    // At x = 0.25 the straight polyline gives 0.1; the smooth curve must not.
    final i = (0.25 * 255).round();
    expect((lut[i] - 0.1).abs() > 0.01, isTrue, reason: 'y=${lut[i]}');
  });

  test('matches the Rust curve_lut fixtures within 1/255', () {
    // Shared fixtures generated from rust/src/color.rs::curve_lut (f32).
    // Control points (x, y): (0,0), (0.25,0.2), (0.75,0.85), (1,1).
    const xs = <double>[0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1];
    // Regenerate with: cargo test curve_lut_fixture -- --nocapture
    const rustLut = <double>[
      0.0,
      0.09254913,
      0.20103107,
      0.3551304,
      0.5340928,
      0.7043178,
      0.8490669,
      0.9356861,
      1.0,
    ];
    final lut = curveLut(flat([(0, 0), (0.25, 0.2), (0.75, 0.85), (1, 1)]));
    for (var k = 0; k < xs.length; k++) {
      final i = math.min(255, (xs[k] * 255).round());
      expect(lut[i], closeTo(rustLut[k], 1 / 255), reason: 'sample x=${xs[k]}');
    }
  });
}
