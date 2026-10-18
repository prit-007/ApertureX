import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/color/spatial_spec.dart';
import 'package:aperturex/edit/recipe.dart';

void main() {
  group('SpatialSpec', () {
    test('the default is neutral', () {
      expect(const SpatialSpec().isNeutral, isTrue);
      expect(SpatialSpec.fromRecipe(EditRecipe.neutral).isNeutral, isTrue);
    });

    test('fromRecipe maps the spatial fields', () {
      final recipe = EditRecipe.neutral.copyWith(
        shadows: 0.4,
        highlights: -0.2,
        clarity: 0.3,
        texture: 0.1,
        sharpen: 0.5,
        denoiseLuma: 0.6,
        denoiseChroma: 0.7,
      );
      final spec = SpatialSpec.fromRecipe(recipe);

      expect(spec.shadows, 0.4);
      expect(spec.highlights, -0.2);
      expect(spec.clarity, 0.3);
      expect(spec.texture, 0.1);
      expect(spec.sharpen, 0.5);
      expect(spec.denoiseLuma, 0.6);
      expect(spec.denoiseChroma, 0.7);
      expect(spec.isNeutral, isFalse);
    });

    test('fromRecipe maps film halation params', () {
      final recipe = EditRecipe.neutral.copyWith(
        filmHalation: 0.6,
        filmHalationRadius: 0.5,
        filmHalationThreshold: 0.7,
      );
      final spec = SpatialSpec.fromRecipe(recipe);

      expect(spec.filmHalation, 0.6);
      expect(spec.filmHalationRadius, 0.5);
      expect(spec.filmHalationThreshold, 0.7);
      expect(spec.isNeutral, isFalse);
    });

    test('fromRecipe maps film bloom params', () {
      final recipe = EditRecipe.neutral.copyWith(
        filmBloom: 0.5,
        filmBloomRadius: 0.4,
        filmBloomThreshold: 0.65,
      );
      final spec = SpatialSpec.fromRecipe(recipe);

      expect(spec.filmBloom, 0.5);
      expect(spec.filmBloomRadius, 0.4);
      expect(spec.filmBloomThreshold, 0.65);
      expect(spec.isNeutral, isFalse);
    });

    test('fromRecipe maps film dust and scratches params', () {
      final recipe = EditRecipe.neutral.copyWith(
        filmDust: 0.3,
        filmScratches: 0.2,
      );
      final spec = SpatialSpec.fromRecipe(recipe);

      expect(spec.filmDust, 0.3);
      expect(spec.filmScratches, 0.2);
      expect(spec.isNeutral, isFalse);
    });

    test('isNeutral returns true when all film params are neutral', () {
      final recipe = EditRecipe.neutral.copyWith(
        filmHalation: 0.0,
        filmBloom: 0.0,
        filmDust: 0.0,
        filmScratches: 0.0,
      );
      final spec = SpatialSpec.fromRecipe(recipe);
      expect(spec.isNeutral, isTrue);
    });
  });
}
