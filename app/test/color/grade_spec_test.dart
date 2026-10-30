import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/color/grade_spec.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/engine/engine.dart';

void main() {
  group('GradeSpec (issue #59)', () {
    test('defaults to neutral with whites, blacks, highlights, shadows at 0', () {
      const spec = GradeSpec();
      expect(spec.whites, 0.0);
      expect(spec.blacks, 0.0);
      expect(spec.highlights, 0.0);
      expect(spec.shadows, 0.0);
      expect(spec.vibrance, 0.0);
      expect(spec.exposure, 0.0);
      expect(spec.contrast, 0.0);
    });

    test('GradeSpec.fromRecipe maps highlights, shadows, whites, blacks from EditRecipe', () {
      final recipe = EditRecipe.neutral.copyWith(
        highlights: -0.60,
        shadows: 0.40,
        whites: 0.75,
        blacks: -0.45,
        vibrance: 0.30,
        exposure: 0.50,
      );

      final spec = GradeSpec.fromRecipe(recipe);
      expect(spec.highlights, -0.60);
      expect(spec.shadows, 0.40);
      expect(spec.whites, 0.75);
      expect(spec.blacks, -0.45);
      expect(spec.vibrance, 0.30);
      expect(spec.exposure, 0.50);
    });

    test('AxEngine.normalizeHue normalizes degrees (0..360) and preserves 0..1 scalars', () {
      // 120 degrees (pure green) -> 1/3 (not collapsing to 0.0 red)
      expect(AxEngine.normalizeHue(120.0), closeTo(120.0 / 360.0, 1e-5));
      // 240 degrees (pure blue) -> 2/3
      expect(AxEngine.normalizeHue(240.0), closeTo(240.0 / 360.0, 1e-5));
      // 360 degrees wraps to 0.0
      expect(AxEngine.normalizeHue(360.0), closeTo(0.0, 1e-5));
      // Negative degrees wrap around
      expect(AxEngine.normalizeHue(-30.0), closeTo(330.0 / 360.0, 1e-5));
      // Normalized presets (0.0..1.0) preserved verbatim
      expect(AxEngine.normalizeHue(0.58), closeTo(0.58, 1e-5));
      expect(AxEngine.normalizeHue(0.12), closeTo(0.12, 1e-5));
      expect(AxEngine.normalizeHue(0.0), 0.0);
    });
  });
}

