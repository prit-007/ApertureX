import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/ui/common/slider_math.dart';

void main() {
  group('bidirectional (exposure: -4..4, neutral 0)', () {
    final m = SliderMath(specOf(Parameter.exposure));

    test('is bidirectional with the neutral at the middle', () {
      expect(m.bidirectional, isTrue);
      expect(m.neutralFraction, closeTo(0.5, 1e-9));
    });

    test('fraction <-> value round-trips at the endpoints and centre', () {
      expect(m.fractionOf(-4), 0);
      expect(m.fractionOf(0), closeTo(0.5, 1e-9));
      expect(m.fractionOf(4), 1);
      expect(m.valueAt(0), closeTo(-4, 1e-9));
      expect(m.valueAt(0.5), closeTo(0, 1e-9));
      expect(m.valueAt(1), closeTo(4, 1e-9));
    });

    test('fill range grows outward from neutral', () {
      final (s1, e1) = m.fillRange(2);
      expect(s1, closeTo(0.5, 1e-9));
      expect(e1, closeTo(0.75, 1e-9));

      final (s2, e2) = m.fillRange(-2);
      expect(s2, closeTo(0.25, 1e-9));
      expect(e2, closeTo(0.5, 1e-9));

      final (s3, e3) = m.fillRange(0);
      expect(s3, closeTo(0.5, 1e-9));
      expect(e3, closeTo(0.5, 1e-9));
    });

    test('clamps out-of-range fractions and values', () {
      expect(m.valueAt(-1), closeTo(-4, 1e-9));
      expect(m.valueAt(2), closeTo(4, 1e-9));
      expect(m.fractionOf(99), 1);
      expect(m.fractionOf(-99), 0);
    });
  });

  group('non-linear response (issue #51)', () {
    // Piecewise-sqrt on the neutral half: sign(v) * (|v|/max)^0.5. With
    // ±5 EV range this puts ±1.25 EV at 75% of the track — i.e. ~50% of the
    // track covers roughly ±1 EV (documented curve; issue says "or similar").
    const spec = ParameterSpec(
      id: Parameter.exposure,
      section: RecipeSection.light,
      label: 'Exposure',
      min: -5,
      max: 5,
      response: ResponseCurve.squareRootHalf,
    );
    const m = SliderMath(spec);

    test('sqrt curve: ±1.25 EV sits at the quarter/three-quarter marks', () {
      expect(m.fractionOf(0), closeTo(0.5, 1e-9));
      expect(m.fractionOf(1.25), closeTo(0.75, 1e-9));
      expect(m.fractionOf(-1.25), closeTo(0.25, 1e-9));
    });

    test('fine near neutral: 0.1 EV uses more track than linear would', () {
      // Linear (±5) would give 0.1/10 = 1% of track; sqrt gives ~7% — more
      // resolution where subtle grades live.
      final d = m.fractionOf(0.1) - m.fractionOf(0);
      expect(d, greaterThan(0.01), reason: 'finer than linear near neutral');
      expect(d, lessThan(0.1), reason: 'not jumpy');
    });

    test('round-trips valueAt(fractionOf(v)) == v for 1000 samples', () {
      for (var i = 0; i <= 1000; i++) {
        final v = -5 + i / 1000 * 10;
        expect(m.valueAt(m.fractionOf(v)), closeTo(v, 1e-9), reason: 'v=$v');
      }
    });

    test('still clamps out-of-range fractions and values', () {
      expect(m.valueAt(-1), closeTo(-5, 1e-9));
      expect(m.valueAt(2), closeTo(5, 1e-9));
      expect(m.fractionOf(99), 1);
      expect(m.fractionOf(-99), 0);
    });

    test('neutralFraction stays at the midpoint of a symmetric curve', () {
      expect(m.neutralFraction, closeTo(0.5, 1e-9));
    });
  });

  group('linear default (regression, no declared curve)', () {
    final m = SliderMath(specOf(Parameter.exposure));

    test('behaves exactly as before: fractionOf(v) = (v-min)/span', () {
      for (var i = 0; i <= 100; i++) {
        final v = -4 + i / 100 * 8;
        expect(m.fractionOf(v), closeTo((v + 4) / 8, 1e-9));
        expect(m.valueAt(m.fractionOf(v)), closeTo(v, 1e-9));
      }
    });
  });

  group('unidirectional (synthetic spec: 0..1, neutral 0)', () {
    const spec = ParameterSpec(
      id: Parameter.whites,
      section: RecipeSection.detail,
      label: 'Sharpening',
      min: 0,
      max: 1,
    );
    const m = SliderMath(spec);

    test('is not bidirectional and the neutral is at the left', () {
      expect(m.bidirectional, isFalse);
      expect(m.neutralFraction, 0);
    });

    test('fills from the left', () {
      final (s, e) = m.fillRange(0.5);
      expect(s, 0);
      expect(e, closeTo(0.5, 1e-9));
    });
  });
}
