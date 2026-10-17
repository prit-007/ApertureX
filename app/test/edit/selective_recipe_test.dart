import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/selective_recipe.dart';
import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CopiedSettings', () {
    test('detectModifiedSections finds modified groups', () {
      final modified = EditRecipe.neutral.copyWith(
        exposure: 1.5,
        contrast: 0.2,
        temperature: 0.4,
        blurEnabled: true,
        blurAmount: 0.8,
      );

      final sections = CopiedSettings.detectModifiedSections(modified);
      expect(sections.contains(RecipeSection.light), isTrue);
      expect(sections.contains(RecipeSection.color), isTrue);
      expect(sections.contains(RecipeSection.blur), isTrue);
      expect(sections.contains(RecipeSection.geometry), isFalse);
      expect(sections.contains(RecipeSection.masking), isFalse);
    });

    test('applyTo selectively transfers only specified sections', () {
      final source = EditRecipe.neutral.copyWith(
        exposure: 2.0,
        contrast: 0.5,
        temperature: 0.8,
        saturation: 0.3,
        rotation: 1,
      );

      final target = EditRecipe.neutral.copyWith(
        exposure: -1.0,
        contrast: -0.5,
        temperature: -0.2,
        saturation: -0.1,
        rotation: 2,
      );

      // Copy ONLY light (exposure & contrast), not color or geometry
      final copied = CopiedSettings(
        recipe: source,
        sections: {RecipeSection.light},
      );

      final merged = copied.applyTo(target);

      // Light should come from source:
      expect(merged.exposure, 2.0);
      expect(merged.contrast, 0.5);

      // Color and geometry must stay from target:
      expect(merged.temperature, -0.2);
      expect(merged.saturation, -0.1);
      expect(merged.rotation, 2);
    });

    test('applyTo transfers masking when selected', () {
      const layer = AdjustmentLayer(maskKind: MaskKind.sky, exposure: 0.5);
      final source = EditRecipe.neutral.copyWith(layers: [layer]);
      final target = EditRecipe.neutral;

      final copied = CopiedSettings(
        recipe: source,
        sections: {RecipeSection.masking},
      );

      final merged = copied.applyTo(target);
      expect(merged.layers.length, 1);
      expect(merged.layers.first.maskKind, MaskKind.sky);
    });
  });
}
