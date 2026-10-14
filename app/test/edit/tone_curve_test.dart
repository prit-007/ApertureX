import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/color/grade_spec.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/tone_curve.dart';

void main() {
  group('ToneCurve', () {
    test('identity maps x to x', () {
      expect(ToneCurve.identity.isIdentity, isTrue);
      expect(ToneCurve.identity.points, [0, 0, 1, 1]);
    });

    test('a non-identity curve is detected', () {
      expect(const ToneCurve([0, 0, 0.5, 0.6, 1, 1]).isIdentity, isFalse);
    });

    test('JSON round-trips the points', () {
      const curve = ToneCurve([0, 0.1, 1, 0.9]);
      expect(ToneCurve.fromJson(curve.toJson()), curve);
    });

    test('null/missing JSON yields identity', () {
      expect(ToneCurve.fromJson(null), ToneCurve.identity);
      expect(ToneCurve.fromJson(<String, Object?>{}), ToneCurve.identity);
    });

    test('equality is by value, not identity', () {
      expect(const ToneCurve([0, 0, 1, 1]), const ToneCurve([0, 0, 1, 1]));
      expect(
        const ToneCurve([0, 0, 1, 1]),
        isNot(const ToneCurve([0, 0, 1, 0.9])),
      );
    });
  });

  group('GradeSpec.fromRecipe', () {
    test('maps the scalars and the four curves', () {
      final recipe = EditRecipe.neutral.copyWith(
        exposure: 1.5,
        saturation: 0.25,
        masterCurve: const ToneCurve([0, 0, 0.5, 0.6, 1, 1]),
      );
      final spec = GradeSpec.fromRecipe(recipe);

      expect(spec.exposure, 1.5);
      expect(spec.saturation, 0.25);
      expect(spec.masterCurve, [0, 0, 0.5, 0.6, 1, 1]);
      expect(spec.redCurve, ToneCurve.identity.points);
    });
  });

  group('recipe tone-curve round-trip', () {
    test('curves survive toJson/fromJson', () {
      final recipe = EditRecipe.neutral.copyWith(
        masterCurve: const ToneCurve([0, 0, 0.4, 0.55, 1, 1]),
        blueCurve: const ToneCurve([0, 0.1, 1, 0.9]),
      );
      expect(EditRecipe.fromJson(recipe.toJson()), recipe);
    });

    test('a v3 recipe without curve keys reads identity curves forward', () {
      final json = EditRecipe.neutral.toJson()
        ..remove('masterCurve')
        ..remove('redCurve')
        ..remove('greenCurve')
        ..remove('blueCurve');
      final restored = EditRecipe.fromJson(json);
      expect(restored.masterCurve, ToneCurve.identity);
      expect(restored.schemaVersion, EditRecipe.currentSchemaVersion);
    });
  });

  group('hsl mixer', () {
    test('recipe hsl round-trips', () {
      final hsl = List<double>.filled(24, 0)..[3] = 0.5;
      final recipe = EditRecipe.neutral.copyWith(hsl: hsl);
      expect(EditRecipe.fromJson(recipe.toJson()), recipe);
      expect(EditRecipe.fromJson(recipe.toJson()).hsl[3], 0.5);
    });

    test('GradeSpec carries the hsl mix', () {
      final hsl = List<double>.filled(24, 0)..[7] = -0.3;
      final spec = GradeSpec.fromRecipe(EditRecipe.neutral.copyWith(hsl: hsl));
      expect(spec.hsl[7], -0.3);
    });
  });
}
