import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:aperturex/edit/recipe.dart';

void main() {
  test('layer JSON round-trips', () {
    const layer = AdjustmentLayer(
      maskKind: MaskKind.radial,
      maskParams: [0.5, 0.5, 0.2, 0.2, 0.3],
      exposure: 0.5,
      saturation: -0.2,
    );
    expect(AdjustmentLayer.fromJson(layer.toJson()), layer);
  });

  test('recipe layers survive toJson/fromJson', () {
    final recipe = EditRecipe.neutral.copyWith(
      layers: const [
        AdjustmentLayer(exposure: 1),
        AdjustmentLayer(maskKind: MaskKind.luminance, maskParams: [0, 0.5]),
      ],
    );
    final restored = EditRecipe.fromJson(recipe.toJson());
    expect(restored, recipe);
    expect(restored.layers.length, 2);
  });

  test('a recipe without a layers key reads forward to empty', () {
    final json = EditRecipe.neutral.toJson()..remove('layers');
    expect(EditRecipe.fromJson(json).layers, isEmpty);
  });
}
