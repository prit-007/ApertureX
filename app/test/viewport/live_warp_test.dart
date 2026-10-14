import 'package:aperturex/viewport/live_warp.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  group('calculateLiveGeometry', () {
    test('neutral parameters produce identity', () {
      final m = calculateLiveGeometry(
        straightenAngle: 0,
        perspectiveX: 0,
        perspectiveY: 0,
        skewX: 0,
        skewY: 0,
      );
      expect(m, Matrix4.identity());
    });

    test('perspective writes the homogeneous w-row (real keystone)', () {
      final m = calculateLiveGeometry(
        straightenAngle: 0,
        perspectiveX: 0.5,
        perspectiveY: 0,
        skewX: 0,
        skewY: 0,
      );
      expect(m.entry(3, 2), isNot(0)); // enables the perspective divide
      expect(m.entry(3, 2), greaterThan(0.0005)); // ~0.001, post-rotated

      // Apply the w-divide the way the GPU does (transform3 skips it).
      // Column-major storage: column j is [4j..4j+3].
      List<double> project(double x, double y) {
        final s = m.storage;
        final xp = s[0] * x + s[4] * y + s[12];
        final yp = s[1] * x + s[5] * y + s[13];
        final wp = s[3] * x + s[7] * y + s[15];
        return [xp / wp, yp / wp];
      }

      final left = project(-1, 0);
      final right = project(1, 0);
      expect((right[0] - left[0]).abs(), lessThan(2)); // foreshortened span
      // Asymmetric around centre = keystone, not translation.
      expect(right[0], isNot(closeTo(-left[0], 1e-6)));
    });

    test('skew shears x by y (off-diagonal entries)', () {
      final m = calculateLiveGeometry(
        straightenAngle: 0,
        perspectiveX: 0,
        perspectiveY: 0,
        skewX: 0.3,
        skewY: 0,
      );
      // x' = s[0]·x + s[4]·y + s[12]; y row must stay identity.
      final s = m.storage;
      expect(s[4], closeTo(0.3, 1e-9)); // column 1, row 0 = shear x by y
      expect(s[1], closeTo(0, 1e-9)); // no y-leak into x
      expect(s[5], closeTo(1, 1e-9)); // y' = y
    });

    test('straighten rotates about z', () {
      final m = calculateLiveGeometry(
        straightenAngle: 90,
        perspectiveX: 0,
        perspectiveY: 0,
        skewX: 0,
        skewY: 0,
      );
      final s = m.storage;
      // 90° rotation: (1,0) maps to (0,1) in the matrix's x/y rows.
      expect(s[0], closeTo(0, 1e-9)); // x·cos
      expect(s[1], closeTo(1, 1e-9)); // x·sin → y
    });
  });

  group('calculateAutoCropScale', () {
    test('zero angle needs no scale', () {
      expect(calculateAutoCropScale(0, 400, 300), 1);
    });

    test('45° on a square scales by √2', () {
      expect(
        calculateAutoCropScale(45 * 3.141592653589793 / 180, 300, 300),
        closeTo(1.41421, 1e-4),
      );
    });

    test('wide images need more horizontal headroom', () {
      final wide = calculateAutoCropScale(0.2, 1600, 900);
      final tall = calculateAutoCropScale(0.2, 900, 1600);
      expect(wide, greaterThan(1));
      expect(tall, greaterThan(1));
      expect(wide, closeTo(tall, 0.4)); // both bounded
    });

    test('degenerate sizes fall back to 1', () {
      expect(calculateAutoCropScale(0.5, 0, 300), 1);
    });
  });
}
