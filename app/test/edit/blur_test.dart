import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aperturex/color/blur_spec.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/recipe_controller.dart';

void main() {
  group('LensBlurSpec', () {
    test('default spec is neutral', () {
      const spec = LensBlurSpec();
      expect(spec.enabled, isFalse);
      expect(spec.amount, 0.0);
      expect(spec.focalPoint, 0.5);
      expect(spec.focalRange, 0.2);
      expect(spec.bokehShape, BokehShape.circle);
      expect(spec.bokehBoost, 0.0);
      expect(spec.isNeutral, isTrue);
    });

    test('fromRecipe maps fields correctly', () {
      final recipe = EditRecipe.neutral.copyWith(
        blurEnabled: true,
        blurAmount: 0.75,
        blurFocalPoint: 0.4,
        blurFocalRange: 0.15,
        blurBokehShape: BokehShape.hexagon.index,
        blurBokehBoost: 0.5,
      );
      final spec = LensBlurSpec.fromRecipe(recipe);
      expect(spec.enabled, isTrue);
      expect(spec.amount, 0.75);
      expect(spec.focalPoint, 0.4);
      expect(spec.focalRange, 0.15);
      expect(spec.bokehShape, BokehShape.hexagon);
      expect(spec.bokehBoost, 0.5);
      expect(spec.isNeutral, isFalse);
    });
  });

  group('Recipe blur integration', () {
    test('EditRecipe JSON round-trip retains blur fields', () {
      final recipe = EditRecipe.neutral.copyWith(
        blurEnabled: true,
        blurAmount: 0.8,
        blurFocalPoint: 0.3,
        blurFocalRange: 0.1,
        blurBokehShape: 2,
        blurBokehBoost: 0.6,
      );
      final json = recipe.toJson();
      final restored = EditRecipe.fromJson(json);
      expect(restored.blurEnabled, isTrue);
      expect(restored.blurAmount, 0.8);
      expect(restored.blurFocalPoint, 0.3);
      expect(restored.blurFocalRange, 0.1);
      expect(restored.blurBokehShape, 2);
      expect(restored.blurBokehBoost, 0.6);
      expect(restored, recipe);
    });

    test('RecipeController modifies blur toggles and parameters', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(recipeControllerProvider.notifier);

      expect(container.read(recipeControllerProvider).recipe.blurEnabled, isFalse);
      notifier.setBlurEnabled(true);
      expect(container.read(recipeControllerProvider).recipe.blurEnabled, isTrue);

      notifier.update(Parameter.blurAmount, 0.5);
      expect(container.read(recipeControllerProvider).recipe.blurAmount, 0.5);

      notifier.setBlurBokehShape(3);
      expect(container.read(recipeControllerProvider).recipe.blurBokehShape, 3);
    });
  });
}
