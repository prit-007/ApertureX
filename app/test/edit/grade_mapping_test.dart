import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/grade_mapping.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/gesture/gesture_interpreter.dart' show GradeTool;

void main() {
  group('GradeUniforms.fromRecipe', () {
    test('maps the renderable fields onto the shader uniform contract', () {
      const recipe = EditRecipe(
        exposure: 1.5,
        contrast: -0.25,
        saturation: 0.4,
        temperature: 0.3,
        tint: -0.1,
        vibrance: 0.2,
        highlights: 0.5,
        shadows: -0.3,
      );
      final uniforms = GradeUniforms.fromRecipe(recipe);

      expect(uniforms.exposure, 1.5);
      expect(uniforms.contrast, -0.25);
      expect(uniforms.saturation, 0.4);
      expect(uniforms.temperature, 0.3);
      expect(uniforms.tint, -0.1);
      expect(uniforms.vibrance, 0.2);
      expect(uniforms.highlights, 0.5);
      expect(uniforms.shadows, -0.3);
    });

    test('toFloats returns uniforms in shader slot order', () {
      const recipe = EditRecipe(
        exposure: 1.0,
        contrast: 0.5,
        saturation: -0.2,
        temperature: 0.3,
        tint: -0.1,
        vibrance: 0.4,
        highlights: 0.5,
        shadows: -0.3,
      );
      final uniforms = GradeUniforms.fromRecipe(recipe);

      expect(
        uniforms.toFloats(),
        [1.0, 0.5, -0.2, 0.3, -0.1, 0.4, 0.5, -0.3],
      );
    });

    test('a neutral recipe yields zeroed uniforms (identity transform)', () {
      final uniforms = GradeUniforms.fromRecipe(EditRecipe.neutral);

      expect(uniforms.exposure, 0);
      expect(uniforms.contrast, 0);
      expect(uniforms.saturation, 0);
      expect(uniforms.temperature, 0);
      expect(uniforms.tint, 0);
      expect(uniforms.vibrance, 0);
      expect(uniforms.highlights, 0);
      expect(uniforms.shadows, 0);
    });
  });

  group('applyToolDelta', () {
    test('a full-swipe exposure delta equals 2 EV (preserves the seed feel)', () {
      // The gesture emits dx/fullSwipeValue, summing to 1.0 over a full swipe.
      final recipe = applyToolDelta(EditRecipe.neutral, GradeTool.exposure, 1.0);
      expect(recipe.exposure, closeTo(2.0, 1e-9));
    });

    test('exposure uses unit sensitivity of 2x while contrast is 1x', () {
      final e = applyToolDelta(EditRecipe.neutral, GradeTool.exposure, 0.5);
      final c = applyToolDelta(EditRecipe.neutral, GradeTool.contrast, 0.5);
      expect(e.exposure, closeTo(1.0, 1e-9));
      expect(c.contrast, closeTo(0.5, 1e-9));
    });

    test('clamps to the per-tool range', () {
      final hot = applyToolDelta(EditRecipe.neutral, GradeTool.exposure, 99);
      final cold = applyToolDelta(
        EditRecipe.neutral,
        GradeTool.exposure,
        -99,
      );
      expect(hot.exposure, 4.0);
      expect(cold.exposure, -4.0);

      final contrast = applyToolDelta(
        EditRecipe.neutral,
        GradeTool.contrast,
        99,
      );
      expect(contrast.contrast, 1.0);
    });

    test('accumulates across successive deltas', () {
      var recipe = EditRecipe.neutral;
      recipe = applyToolDelta(recipe, GradeTool.saturation, 0.1);
      recipe = applyToolDelta(recipe, GradeTool.saturation, 0.2);
      expect(recipe.saturation, closeTo(0.3, 1e-9));
    });

    test('is immutable — the receiver is never mutated', () {
      const before = EditRecipe.neutral;
      applyToolDelta(before, GradeTool.exposure, 1.0);
      expect(before, EditRecipe.neutral);
    });
  });

  group('resetTool', () {
    test('zeroes only the target tool and leaves others intact', () {
      final edited = const EditRecipe().copyWith(
        exposure: 2.0,
        contrast: 0.4,
        saturation: -0.3,
      );

      final reset = resetTool(edited, GradeTool.contrast);

      expect(reset.contrast, 0);
      expect(reset.exposure, 2.0);
      expect(reset.saturation, -0.3);
      expect(edited.contrast, 0.4); // original untouched
    });
  });
}
