import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/edit/parameter.dart';
import 'package:tessera/edit/recipe.dart';

void main() {
  group('parameter catalog', () {
    test('every Parameter has a spec with a valid range', () {
      for (final p in Parameter.values) {
        final s = specOf(p);
        expect(s.id, p);
        expect(s.min, lessThan(s.max));
        expect(s.neutral, inInclusiveRange(s.min, s.max));
        expect(s.scale, greaterThan(0));
        expect(s.label, isNotEmpty);
        expect(s.kind, ParameterKind.slider);
      }
    });

    test('neutral is zero everywhere (identity recipe)', () {
      for (final p in Parameter.values) {
        expect(specOf(p).neutral, 0);
      }
    });

    test('the catalog covers exactly the renderable fields today', () {
      expect(Parameter.values.length, 22);
    });
  });

  group('valueOf', () {
    test('reads the matching recipe field per parameter', () {
      const r = EditRecipe(
        exposure: 1,
        contrast: 2,
        highlights: 3,
        shadows: 4,
        whites: 5,
        blacks: 6,
        temperature: 7,
        tint: 8,
        vibrance: 9,
        saturation: 10,
      );
      expect(valueOf(r, Parameter.exposure), 1);
      expect(valueOf(r, Parameter.contrast), 2);
      expect(valueOf(r, Parameter.highlights), 3);
      expect(valueOf(r, Parameter.shadows), 4);
      expect(valueOf(r, Parameter.whites), 5);
      expect(valueOf(r, Parameter.blacks), 6);
      expect(valueOf(r, Parameter.temperature), 7);
      expect(valueOf(r, Parameter.tint), 8);
      expect(valueOf(r, Parameter.vibrance), 9);
      expect(valueOf(r, Parameter.saturation), 10);
    });
  });

  group('withValue / clampParameter', () {
    test('sets only the named parameter', () {
      final r = withValue(EditRecipe.neutral, Parameter.exposure, 1.5);
      expect(r.exposure, 1.5);
      expect(r.contrast, 0);
      expect(r.saturation, 0);
    });

    test('clamps to the exclusive range', () {
      expect(withValue(EditRecipe.neutral, Parameter.exposure, 99).exposure, 4);
      expect(
        withValue(EditRecipe.neutral, Parameter.exposure, -99).exposure,
        -4,
      );
      expect(
        withValue(EditRecipe.neutral, Parameter.contrast, 99).contrast,
        1,
      );
    });

    test('exposure range is wide enough for the EV slider', () {
      expect(clampParameter(Parameter.exposure, 2), 2);
      expect(clampParameter(Parameter.exposure, -2), -2);
    });

    test('is pure — the receiver is never mutated', () {
      const before = EditRecipe.neutral;
      withValue(before, Parameter.tint, 0.5);
      expect(before, EditRecipe.neutral);
    });
  });
}