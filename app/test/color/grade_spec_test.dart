import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/color/grade_spec.dart';
import 'package:aperturex/edit/recipe.dart';

void main() {
  group('GradeSpec (issue #59)', () {
    test('defaults to neutral with whites and blacks at 0', () {
      const spec = GradeSpec();
      expect(spec.whites, 0.0);
      expect(spec.blacks, 0.0);
      expect(spec.vibrance, 0.0);
      expect(spec.exposure, 0.0);
      expect(spec.contrast, 0.0);
    });

    test('GradeSpec.fromRecipe maps whites and blacks from EditRecipe', () {
      final recipe = EditRecipe.neutral.copyWith(
        whites: 0.75,
        blacks: -0.45,
        vibrance: 0.30,
        exposure: 0.50,
      );

      final spec = GradeSpec.fromRecipe(recipe);
      expect(spec.whites, 0.75);
      expect(spec.blacks, -0.45);
      expect(spec.vibrance, 0.30);
      expect(spec.exposure, 0.50);
    });
  });
}
