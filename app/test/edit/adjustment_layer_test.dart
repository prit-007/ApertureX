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

  group('brush helpers', () {
    test('extracts brushRadius, brushFeather, and brushPointCount', () {
      const emptyBrush = AdjustmentLayer(
        maskKind: MaskKind.brush,
        maskParams: [],
      );
      expect(emptyBrush.brushRadius, 0.06);
      expect(emptyBrush.brushFeather, 0.25);
      expect(emptyBrush.brushPointCount, 0);

      const filledBrush = AdjustmentLayer(
        maskKind: MaskKind.brush,
        maskParams: [0.12, 0.4, 2, 0.1, 0.2, 0.8, 0.3, 0.4, 0.9],
      );
      expect(filledBrush.brushRadius, 0.12);
      expect(filledBrush.brushFeather, 0.4);
      expect(filledBrush.brushPointCount, 2);
    });

    test('withBrushRadius and withBrushFeather update parameters cleanly', () {
      var brush = const AdjustmentLayer(
        maskKind: MaskKind.brush,
        maskParams: [0.06, 0.25, 0],
      );
      brush = brush.withBrushRadius(0.15);
      expect(brush.brushRadius, 0.15);

      brush = brush.withBrushFeather(0.6);
      expect(brush.brushFeather, 0.6);
    });

    test('withClearedStrokes resets stroke points count to 0', () {
      const brush = AdjustmentLayer(
        maskKind: MaskKind.brush,
        maskParams: [0.10, 0.3, 2, 0.2, 0.2, 1.0, 0.3, 0.3, 1.0],
      );
      final cleared = brush.withClearedStrokes();
      expect(cleared.brushRadius, 0.10);
      expect(cleared.brushFeather, 0.3);
      expect(cleared.brushPointCount, 0);
      expect(cleared.maskParams.length, 3);
    });

    test('withErasedNear removes stroke points within the erase radius', () {
      const brush = AdjustmentLayer(
        maskKind: MaskKind.brush,
        maskParams: [
          0.10, 0.25, 3,
          0.2, 0.2, 1.0, // target near (0.2, 0.2)
          0.8, 0.8, 1.0, // far point
          0.22, 0.21, 1.0, // target near (0.2, 0.2)
        ],
      );
      // Erase around (0.2, 0.2) with radius 0.05
      final erased = brush.withErasedNear(0.2, 0.2, 0.05);
      expect(erased.brushPointCount, 1);
      expect(erased.maskParams.length, 6);
      expect(erased.maskParams[3], 0.8);
      expect(erased.maskParams[4], 0.8);
    });
  });
}
