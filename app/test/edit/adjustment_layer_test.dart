import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

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

  group('bitmap compact encoding (#86)', () {
    test('bitmap mask constructor and getters', () {
      final bitmap = AdjustmentLayer.bitmap(
        width: 4,
        height: 4,
        alphas: List.filled(16, 0.8),
        exposure: 0.7,
      );
      expect(bitmap.maskKind, MaskKind.bitmap);
      expect(bitmap.bitmapWidth, 4);
      expect(bitmap.bitmapHeight, 4);
      // #86: params carry only the dimensions; alphas live in the compact blob.
      expect(bitmap.maskParams, [4.0, 4.0]);
      expect(bitmap.maskBlob, isNotNull);
      expect(bitmap.maskBlob!.length, 16);
      expect(bitmap.maskBlob![0], 204); // 0.8 * 255 rounds to 204
      expect(bitmap.exposure, 0.7);

      final json = bitmap.toJson();
      expect(json['maskKind'], MaskKind.bitmap.index);
      expect(json['maskBlob'], isA<String>());
      expect(AdjustmentLayer.fromJson(json), bitmap);
    });

    test('bitmap JSON payload stays under 100 KB at the 256² cap', () {
      final bitmap = AdjustmentLayer.bitmap(
        width: 256,
        height: 256,
        alphas: List.filled(256 * 256, 0.5),
      );
      final encoded = jsonEncode(bitmap.toJson());
      expect(encoded.length, lessThan(100000));
    });

    test('factory caps the longest side at 256 with area averaging', () {
      final bitmap = AdjustmentLayer.bitmap(
        width: 1024,
        height: 64,
        alphas: List.filled(1024 * 64, 1.0),
      );
      expect(math.max(bitmap.bitmapWidth, bitmap.bitmapHeight), 256);
      expect(bitmap.maskBlob, isNotNull);
      expect(bitmap.maskBlob!.length, bitmap.bitmapWidth * bitmap.bitmapHeight);
      // A constant input survives averaging as the same constant.
      expect(bitmap.maskBlob!.toSet(), {255});
    });

    test('legacy inline double arrays migrate to the compact blob', () {
      final legacy = <String, Object?>{
        'maskKind': MaskKind.bitmap.index,
        'maskParams': <double>[2, 2, 0, 128 / 255, 1, 64 / 255],
        'inverted': false,
      };
      final restored = AdjustmentLayer.fromJson(legacy);
      expect(restored.maskParams, [2.0, 2.0]);
      expect(restored.maskBlob, const [0, 128, 255, 64]);
    });

    test('legacy oversized arrays are capped during migration', () {
      const w = 512;
      const h = 512;
      final legacy = <String, Object?>{
        'maskKind': MaskKind.bitmap.index,
        'maskParams': <double>[w.toDouble(), h.toDouble(), ...List.filled(w * h, 1.0)],
      };
      final restored = AdjustmentLayer.fromJson(legacy);
      expect(math.max(restored.bitmapWidth, restored.bitmapHeight), 256);
      expect(restored.maskBlob, isNotNull);
      expect(restored.maskBlob!.every((b) => b == 255), isTrue);
    });

    test('corrupt bitmap payloads throw FormatException', () {
      final badBlob = <String, Object?>{
        'maskKind': MaskKind.bitmap.index,
        'maskParams': <double>[4, 4],
        'maskBlob': base64Encode(const [1, 2, 3]),
      };
      expect(() => AdjustmentLayer.fromJson(badBlob), throwsFormatException);

      final shortLegacy = <String, Object?>{
        'maskKind': MaskKind.bitmap.index,
        'maskParams': <double>[4, 4, 1],
      };
      expect(() => AdjustmentLayer.fromJson(shortLegacy), throwsFormatException);
    });

    test('toBridgeMaskParams expands the blob for the Rust mask layer', () {
      final bitmap = AdjustmentLayer.bitmap(
        width: 2,
        height: 1,
        alphas: const [0, 1],
      );
      expect(bitmap.toBridgeMaskParams(), const <double>[2, 1, 0, 1]);

      const radial = AdjustmentLayer(
        maskKind: MaskKind.radial,
        maskParams: [0.5, 0.5, 0.2, 0.2, 0.3],
      );
      expect(
        radial.toBridgeMaskParams(),
        Float32List.fromList(const [0.5, 0.5, 0.2, 0.2, 0.3]),
      );
    });

    test('equality and hashCode cover the blob', () {
      AdjustmentLayer make() => AdjustmentLayer.bitmap(
        width: 3,
        height: 2,
        alphas: const [0, 0.5, 1, 1, 0.5, 0],
      );
      final a = make();
      final b = make();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      final c = AdjustmentLayer.bitmap(
        width: 3,
        height: 2,
        alphas: const [0, 0.5, 1, 1, 0.5, 0.2],
      );
      expect(a == c, isFalse);
    });
  });

  group('inverted property', () {
    test('defaults to false', () {
      const layer = AdjustmentLayer();
      expect(layer.inverted, isFalse);
    });

    test('round-trips through JSON', () {
      const invertedLayer = AdjustmentLayer(
        maskKind: MaskKind.linear,
        maskParams: [0, 0, 0, 1],
        inverted: true,
        exposure: 0.5,
      );
      final json = invertedLayer.toJson();
      expect(json['inverted'], isTrue);
      final restored = AdjustmentLayer.fromJson(json);
      expect(restored.inverted, isTrue);
      expect(restored, equals(invertedLayer));
    });

    test('missing inverted key in JSON defaults to false', () {
      final json = const AdjustmentLayer(exposure: 1).toJson()..remove('inverted');
      final restored = AdjustmentLayer.fromJson(json);
      expect(restored.inverted, isFalse);
    });

    test('copyWith can toggle inverted flag', () {
      const layer = AdjustmentLayer(inverted: false);
      final toggled = layer.copyWith(inverted: true);
      expect(toggled.inverted, isTrue);
      final reverted = toggled.copyWith(inverted: false);
      expect(reverted.inverted, isFalse);
    });

    test('bitmap constructor accepts inverted flag', () {
      final layer = AdjustmentLayer.bitmap(
        width: 2,
        height: 2,
        alphas: const [0, 1, 0, 1],
        inverted: true,
      );
      expect(layer.inverted, isTrue);
    });
  });
}


