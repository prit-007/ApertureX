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

    test('withErasedNear inserts stroke break sentinel when erasing inside a stroke', () {
      const brush = AdjustmentLayer(
        maskKind: MaskKind.brush,
        maskParams: [
          0.10, 0.25, 3,
          0.1, 0.1, 1.0, // Point A
          0.5, 0.5, 1.0, // Point B to be erased
          0.9, 0.9, 1.0, // Point C
        ],
      );
      final erased = brush.withErasedNear(0.5, 0.5, 0.1);
      // Points A and C remain, separated by [-1.0, -1.0, -1.0] sentinel
      expect(erased.maskParams[3], 0.1);
      expect(erased.maskParams[4], 0.1);
      expect(erased.maskParams[6], -1.0);
      expect(erased.maskParams[7], -1.0);
      expect(erased.maskParams[8], -1.0);
      expect(erased.maskParams[9], 0.9);
      expect(erased.maskParams[10], 0.9);
    });
  });

  group('linear, subject, and sky helpers', () {
    test('linear gradient getters and withLinearPoints', () {
      const linear = AdjustmentLayer(
        maskKind: MaskKind.linear,
        maskParams: [0.2, 0.3, 0.8, 0.9],
      );
      expect(linear.linearStart, const Offset(0.2, 0.3));
      expect(linear.linearEnd, const Offset(0.8, 0.9));

      final updated = linear.withLinearPoints(const Offset(0.1, 0.2), const Offset(0.7, 0.8));
      expect(updated.linearStart, const Offset(0.1, 0.2));
      expect(updated.linearEnd, const Offset(0.7, 0.8));
    });

    test('subject mask getters and withSubjectBounds', () {
      const subject = AdjustmentLayer(
        maskKind: MaskKind.subject,
        maskParams: [0.5, 0.6, 0.25, 0.35, 0.3],
      );
      expect(subject.subjectCenter, const Offset(0.5, 0.6));
      expect(subject.subjectRadiusX, 0.25);
      expect(subject.subjectRadiusY, 0.35);
      expect(subject.subjectFeather, 0.3);

      final updated = subject.withSubjectBounds(
        const Offset(0.4, 0.5),
        0.3,
        0.4,
        0.2,
      );
      expect(updated.subjectCenter, const Offset(0.4, 0.5));
      expect(updated.subjectRadiusX, 0.3);
      expect(updated.subjectRadiusY, 0.4);
      expect(updated.subjectFeather, 0.2);
    });

    test('sky mask getters and withSkyHorizon', () {
      const sky = AdjustmentLayer(
        maskKind: MaskKind.sky,
        maskParams: [0.45, 0.2, 0.6],
      );
      expect(sky.skyHorizon, 0.45);
      expect(sky.skyFeather, 0.2);

      final updated = sky.withSkyHorizon(0.35);
      expect(updated.skyHorizon, 0.35);
      expect(updated.skyFeather, 0.2);
    });
  });
}

