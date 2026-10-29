import 'package:flutter_test/flutter_test.dart';

import 'package:aperturex/edit/wb_contrast_shader_math.dart';

void main() {
  group('WB + Contrast shader math (ported to grade.frag)', () {
    test('warm white balance raises red over blue', () {
      // Neutral grey should stay neutral at zero temp/tint.
      final neutral = applyWhiteBalance([0.5, 0.5, 0.5], 0.0, 0.0);
      for (var k = 0; k < 3; k++) {
        expect(neutral[k], closeTo(0.5, 1e-4));
      }

      // Warm: red/blue ratio increases.
      final warm = applyWhiteBalance([0.5, 0.5, 0.5], 0.5, 0.0);
      expect(warm[0] / warm[2], greaterThan(1.0));

      // Cool: red/blue ratio decreases.
      final cool = applyWhiteBalance([0.5, 0.5, 0.5], -0.5, 0.0);
      expect(cool[0] / cool[2], lessThan(1.0));
    });

    test('tint pushes green vs magenta', () {
      final greenish = applyWhiteBalance([0.5, 0.5, 0.5], 0.0, -0.5);
      expect(greenish[1] / greenish[0], greaterThan(1.0));

      final magentaish = applyWhiteBalance([0.5, 0.5, 0.5], 0.0, 0.5);
      expect(magentaish[1] / magentaish[0], lessThan(1.0));
    });

    test('contrast positive pushes away from mid-grey', () {
      final mid = applyContrast(0.5, 0.5);
      expect(mid, closeTo(0.5, 1e-4)); // mid-grey stays put

      final bright = applyContrast(0.8, 0.5);
      expect(bright, greaterThan(0.8));

      final dark = applyContrast(0.2, 0.5);
      expect(dark, lessThan(0.2));
    });

    test('contrast negative pulls toward mid-grey', () {
      final bright = applyContrast(0.8, -0.5);
      expect(bright, lessThan(0.8));
      expect(bright, greaterThan(0.5));

      final dark = applyContrast(0.2, -0.5);
      expect(dark, greaterThan(0.2));
      expect(dark, lessThan(0.5));
    });

    test('contrast is monotone', () {
      const p = 0.5;
      for (var i = 0; i < 100; i++) {
        final v1 = i / 100.0;
        final v2 = (i + 1) / 100.0;
        expect(applyContrast(v2, p), greaterThanOrEqualTo(applyContrast(v1, p) - 1e-6));
      }
    });

    test('wb gains clamp at zero', () {
      // Extreme cool temperature (-1.0): L gain = 1 + 0.20*(-1) = 0.8, S gain = 1 - 0.30*(-1) = 1.3
      // But with max(0.0) guard, no negative gains.
      final extreme = applyWhiteBalance([0.3, 0.5, 0.7], -1.0, -1.0);
      for (var k = 0; k < 3; k++) {
        expect(extreme[k], greaterThanOrEqualTo(0.0));
        expect(extreme[k], lessThanOrEqualTo(1.0));
      }
    });
  });
}
