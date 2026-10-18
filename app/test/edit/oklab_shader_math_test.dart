import 'package:flutter_test/flutter_test.dart';

import 'package:aperturex/edit/oklab_shader_math.dart';

void main() {
  group('Oklab shader math (ported to grade.frag)', () {
    test('saturation on grey is a no-op', () {
      final grey = [0.5, 0.5, 0.5];
      final out = saturateOklab(grey, 1.0);
      expect(out[0], closeTo(0.5, 1e-4));
      expect(out[1], closeTo(0.5, 1e-4));
      expect(out[2], closeTo(0.5, 1e-4));
    });

    test('saturation preserves hue angle', () {
      final blue = [0.2, 0.35, 0.8];
      final h0 = oklabHue(blue);
      final out = saturateOklab(blue, 0.5);
      final h1 = oklabHue(out);
      expect((h1 - h0).abs(), lessThan(0.05), reason: 'hue shifted: $h0 -> $h1');
    });

    test('saturation raises chroma', () {
      final blue = [0.2, 0.35, 0.8];
      final c0 = oklabChroma(blue);
      final out = saturateOklab(blue, 0.5);
      final c1 = oklabChroma(out);
      expect(c1, greaterThan(c0), reason: 'chroma did not increase: $c0 -> $c1');
    });

    test('negative saturation reduces chroma', () {
      final blue = [0.2, 0.35, 0.8];
      final c0 = oklabChroma(blue);
      final out = saturateOklab(blue, -0.5);
      final c1 = oklabChroma(out);
      expect(c1, lessThan(c0), reason: 'chroma did not decrease: $c0 -> $c1');
    });

    test('round trip identity at zero amount', () {
      for (final c in [[0.2, 0.4, 0.8], [0.1, 0.9, 0.3], [0.5, 0.5, 0.5]]) {
        final out = saturateOklab(c, 0.0);
        for (var k = 0; k < 3; k++) {
          expect(out[k], closeTo(c[k], 5e-4), reason: '$c -> $out');
        }
      }
    });
  });
}
