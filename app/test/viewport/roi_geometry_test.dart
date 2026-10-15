import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/viewport/roi_overlay.dart';

void main() {
  const fitted = Size(1000, 750);
  const fullHeight = 3000;

  group('roiBlockedByGeometry', () {
    test('identity geometry allows the overlay', () {
      expect(roiBlockedByGeometry(const EditRecipe()), isFalse);
    });

    test('each geometry edit blocks the overlay', () {
      const cases = <String, EditRecipe>{
        'rotation': EditRecipe(rotation: 1),
        'flipH': EditRecipe(flipH: true),
        'flipV': EditRecipe(flipV: true),
        'straighten': EditRecipe(straighten: -12.5),
        'crop': EditRecipe(crop: [0.1, 0.0, 1.0, 1.0]),
        'perspectiveX': EditRecipe(perspectiveX: 0.3),
        'perspectiveY': EditRecipe(perspectiveY: -0.2),
        'skewX': EditRecipe(skewX: 0.1),
        'skewY': EditRecipe(skewY: 0.1),
      };
      for (final entry in cases.entries) {
        expect(
          roiBlockedByGeometry(entry.value),
          isTrue,
          reason: '${entry.key} must gate the raw-band overlay',
        );
      }
    });
  });

  group('roiStripRect', () {
    test('maps the band rows to the full-width world strip', () {
      const plan = RoiOverlayPlan(
        bandTop: 100,
        bandBottom: 1100,
        dstRect: Rect.fromLTWH(50, 25, 250, 250),
        decodeW: 4000,
        decodeH: 1000,
      );
      expect(
        roiStripRect(plan, fullHeight: fullHeight, fitted: fitted),
        // y = 100/3000*750 = 25, height = 1000/3000*750 = 250.
        const Rect.fromLTWH(0, 25, 1000, 250),
      );
    });

    test('band at the very top starts at world zero', () {
      const plan = RoiOverlayPlan(
        bandTop: 0,
        bandBottom: 300,
        dstRect: Rect.fromLTWH(0, 0, 125, 75),
        decodeW: 4000,
        decodeH: 300,
      );
      expect(
        roiStripRect(plan, fullHeight: fullHeight, fitted: fitted),
        const Rect.fromLTWH(0, 0, 1000, 75),
      );
    });
  });
}
