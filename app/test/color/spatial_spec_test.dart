import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/color/spatial_spec.dart';
import 'package:tessera/edit/recipe.dart';

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
      );
      final spec = SpatialSpec.fromRecipe(recipe);

      expect(spec.shadows, 0.4);
      expect(spec.highlights, -0.2);
      expect(spec.clarity, 0.3);
      expect(spec.texture, 0.1);
      expect(spec.sharpen, 0.5);
      expect(spec.isNeutral, isFalse);
    });
  });
}
