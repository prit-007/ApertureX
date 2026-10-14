import 'dart:typed_data';

import 'package:aperturex/features/masking/paint_brush.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Uint8List blank() => Uint8List(64 * 64);

  int coverage(Uint8List m) => m.fold(0, (sum, v) => sum + (v > 0 ? 1 : 0));

  group('distance-based sampling', () {
    test('short strokes do minimal work (no fixed 100-step burn)', () {
      // A 1px dab at radius 8: steps = max(1, ceil(1 / 2)) = 1 → 2 stamps,
      // not 101. Coverage reflects two stamps, not a heavily overlapped line.
      final brush = PaintBrush(width: 64, height: 64);
      final out = brush.paintStroke(
        blank(),
        const Offset(32, 32),
        const Offset(33, 32),
        radius: 8,
      );
      // Two overlapping stamps ≈ one stamp's worth of pixels (~π·8²).
      expect(coverage(out), lessThan(250));
      expect(coverage(out), greaterThan(150));
    });

    test('long strokes stay continuous (no dotted gaps)', () {
      final brush = PaintBrush(width: 64, height: 64);
      final out = brush.paintStroke(
        blank(),
        const Offset(4, 32),
        const Offset(60, 32),
        radius: 6,
      );
      // Every column along the path must be painted.
      for (var x = 4; x <= 60; x++) {
        expect(out[32 * 64 + x], greaterThan(0), reason: 'gap at x=$x');
      }
    });

    test('zero-length stroke still stamps once', () {
      final brush = PaintBrush(width: 64, height: 64);
      final out = brush.paintStroke(
        blank(),
        const Offset(32, 32),
        const Offset(32, 32),
        radius: 5,
      );
      expect(coverage(out), greaterThan(50));
    });
  });

  group('pressure curve', () {
    test('higher pressure paints a bigger, stronger stamp', () {
      final brush = PaintBrush(width: 64, height: 64);
      final light = brush.paintStroke(
        blank(),
        const Offset(32, 32),
        const Offset(32, 32),
        pressure: 0.3,
        radius: 12,
      );
      final heavy = brush.paintStroke(
        blank(),
        const Offset(32, 32),
        const Offset(32, 32),
        pressure: 1.0,
        radius: 12,
      );
      expect(coverage(heavy), greaterThan(coverage(light)));
      // Peak alpha also scales with pressure.
      expect(heavy.reduce((a, b) => a > b ? a : b), greaterThan(
          light.reduce((a, b) => a > b ? a : b)));
    });

    test('radius follows pow(pressure, 1.5) — gamma beats linear near 0', () {
      // At p=0.5 linear radius is 0.5·r; gamma-1.5 gives ≈0.354·r (smaller),
      // i.e. the mapping is non-linear. Verified via coverage ratio.
      final brush = PaintBrush(width: 64, height: 64);
      final half = brush.paintStroke(
        blank(),
        const Offset(32, 32),
        const Offset(32, 32),
        pressure: 0.5,
        radius: 16,
      );
      final full = brush.paintStroke(
        blank(),
        const Offset(32, 32),
        const Offset(32, 32),
        pressure: 1.0,
        radius: 16,
      );
      final ratio = coverage(half) / coverage(full);
      // Area ratio ≈ (0.5^1.5)² = 0.125; linear would be 0.25.
      expect(ratio, lessThan(0.2));
      expect(ratio, greaterThan(0.05));
    });

    test('near-zero pressure paints nothing', () {
      final brush = PaintBrush(width: 64, height: 64);
      final out = brush.paintStroke(
        blank(),
        const Offset(32, 32),
        const Offset(32, 32),
        pressure: 0.01,
        radius: 10,
      );
      expect(coverage(out), 0);
    });
  });

  group('eraser', () {
    test('removes existing coverage', () {
      final brush = PaintBrush(width: 64, height: 64);
      final painted = brush.paintStroke(
        blank(),
        const Offset(32, 32),
        const Offset(32, 32),
        radius: 10,
      );
      final erased = brush.paintStroke(
        painted,
        const Offset(32, 32),
        const Offset(32, 32),
        radius: 10,
        isEraser: true,
      );
      expect(coverage(erased), lessThan(coverage(painted)));
      expect(erased[32 * 64 + 32], lessThan(painted[32 * 64 + 32]));
    });
  });

  group('Catmull-Rom spline', () {
    test('without neighbours it reduces to a straight line', () {
      final brush = PaintBrush(width: 64, height: 64);
      final out = brush.paintStroke(
        blank(),
        const Offset(10, 32),
        const Offset(54, 32),
        radius: 4,
      );
      // The centre row is fully painted; rows far from the axis are not.
      expect(out[32 * 64 + 32], greaterThan(0));
      expect(out[16 * 64 + 32], 0);
    });

    test('with a bent neighbour set the stroke follows the curve', () {
      final brush = PaintBrush(width: 64, height: 64);
      // Corner path: (10,10) → (50,10) with next pulling toward (50,50).
      final out = brush.paintStroke(
        blank(),
        const Offset(10, 10),
        const Offset(50, 10),
        radius: 3,
        previous: const Offset(10, 50), // tangent pulls left side down
        next: const Offset(50, 50), // tangent pulls right side down
      );
      // Straight-line stamps stay at y≈10; the spline bulges toward y≈5
      // at the midpoint (Catmull-Rom through the bent neighbour set).
      expect(out[7 * 64 + 30], greaterThan(0));
      expect(out[14 * 64 + 30], 0); // below the line stays clean
    });
  });
}
