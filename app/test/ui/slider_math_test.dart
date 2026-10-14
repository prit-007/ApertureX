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

  group('unidirectional (synthetic spec: 0..1, neutral 0)', () {
    const spec = ParameterSpec(
      id: Parameter.whites,
      section: RecipeSection.detail,
      label: 'Sharpening',
      min: 0,
      max: 1,
    );
    final m = SliderMath(spec);

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
