import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:aperturex/edit/recipe.dart';

void main() {
  group('Brush Mask and AdjustmentLayer expansion', () {
    test('creates brush adjustment layer with points and parameters', () {
      const radius = 0.08;
      const feather = 0.25;
      final points = <double>[
        radius,
        feather,
        3.0, // count
        0.1, 0.2, 0.8, // pt 1: x, y, pressure
        0.3, 0.4, 0.9, // pt 2
        0.5, 0.6, 1.0, // pt 3
      ];

      final layer = AdjustmentLayer(
        maskKind: MaskKind.brush,
        maskParams: points,
        exposure: 0.6,
        contrast: 0.2,
        inverted: true,
      );

      expect(layer.maskKind, MaskKind.brush);
      expect(layer.maskParams.length, 12);
      expect(layer.maskParams[0], radius);
      expect(layer.maskParams[1], feather);
      expect(layer.maskParams[2], 3.0);
      expect(layer.inverted, isTrue);

      final json = layer.toJson();
      final restored = AdjustmentLayer.fromJson(json);
      expect(restored, layer);
    });

    test('supports subject and sky mask kinds in recipe', () {
      final recipe = EditRecipe.neutral.copyWith(
        layers: const [
          AdjustmentLayer(
            maskKind: MaskKind.subject,
            maskParams: [0.5, 0.5, 0.3, 0.4, 0.2],
            exposure: 0.5,
          ),
          AdjustmentLayer(
            maskKind: MaskKind.sky,
            maskParams: [0.55, 0.15, 0.6],
            highlights: -0.8,
            saturation: 0.3,
          ),
        ],
      );

      final json = recipe.toJson();
      final restored = EditRecipe.fromJson(json);
      expect(restored.layers.length, 2);
      expect(restored.layers[0].maskKind, MaskKind.subject);
      expect(restored.layers[1].maskKind, MaskKind.sky);
      expect(restored, recipe);
    });
  });
}
