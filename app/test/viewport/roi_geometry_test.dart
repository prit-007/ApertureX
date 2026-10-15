import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/viewport/roi_overlay.dart';

void main() {
  const fitted = Size(1000, 750);

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
          reason: '${entry.key} must gate the raw-tile overlay',
        );
      }
    });
  });

  group('planRoiOverlay', () {
    test('is inactive below the proxy-density zoom gate', () {
      // Proxy is 1440 wide; a 1000-wide fitted at scale 1 is still under it.
      expect(
        planRoiOverlay(
          imageW: 4000,
          imageH: 3000,
          proxyW: 1440,
          fitted: fitted,
          scale: 1.0,
          offset: Offset.zero,
          viewport: fitted,
        ),
        isNull,
      );
    });

    test('is active once the proxy is upscaled past its native density', () {
      // scale * fitted.width = 2.0 * 1000 = 2000 >= proxyW 1440.
      final plan = planRoiOverlay(
        imageW: 4000,
        imageH: 3000,
        proxyW: 1440,
        fitted: fitted,
        scale: 2.0,
        offset: Offset.zero,
        viewport: fitted,
      );
      expect(plan, isNotNull);
      // dstRect is the visible world rect (inverse viewport transform).
      expect(plan!.dstRect, const Rect.fromLTWH(0, 0, 500, 375));
    });

    test('is blocked while geometry edits are active', () {
      expect(
        planRoiOverlay(
          imageW: 4000,
          imageH: 3000,
          proxyW: 1440,
          fitted: fitted,
          scale: 2.0,
          offset: Offset.zero,
          viewport: fitted,
          geometryActive: true,
        ),
        isNull,
      );
    });
  });

  group('tileDecodeRect', () {
    test('an interior tile grows by the halo on every side', () {
      // Tile (col 1, row 1) of a 512-tile field: [512,512,1024,1024].
      const tile = Rect.fromLTWH(512, 512, 512, 512);
      final decode = tileDecodeRect(
        tile,
        imageW: 4000,
        imageH: 3000,
        halo: 16,
      );
      expect(decode, const Rect.fromLTWH(496, 496, 544, 544));
    });

    test('a top-left tile clamps the halo at the image origin', () {
      const tile = Rect.fromLTWH(0, 0, 512, 512);
      final decode = tileDecodeRect(
        tile,
        imageW: 4000,
        imageH: 3000,
        halo: 16,
      );
      expect(decode, const Rect.fromLTWH(0, 0, 528, 528));
    });

    test('a bottom-right tile clamps the halo at the image edge', () {
      // Last tile of a 2048x1536 image (tile field 4x3 of 512).
      const tile = Rect.fromLTWH(1536, 1024, 512, 512);
      final decode = tileDecodeRect(
        tile,
        imageW: 2048,
        imageH: 1536,
        halo: 16,
      );
      expect(decode, const Rect.fromLTWH(1520, 1008, 528, 528));
    });

    test('a zero halo returns the tile rect unchanged', () {
      const tile = Rect.fromLTWH(512, 512, 512, 512);
      expect(
        tileDecodeRect(tile, imageW: 4000, imageH: 3000, halo: 0),
        tile,
      );
    });
  });
}
