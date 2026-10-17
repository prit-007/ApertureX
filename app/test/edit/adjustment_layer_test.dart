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

  group('amount (issue #91)', () {
    test('round-trips through JSON', () {
      const layer = AdjustmentLayer(
        maskKind: MaskKind.linear,
        maskParams: [0, 0, 0, 1],
        amount: 0.75,
        exposure: 0.5,
      );
      final json = layer.toJson();
      expect(json['amount'], 0.75);
      final restored = AdjustmentLayer.fromJson(json);
      expect(restored.amount, 0.75);
      expect(restored, equals(layer));
    });

    test('missing amount in JSON defaults to 1.0 (v19 migration)', () {
      final v19Json = <String, Object?>{
        'maskKind': 0,
        'maskParams': [0.0, 0.0, 0.0, 1.0],
        'exposure': 0.5,
      };
      final restored = AdjustmentLayer.fromJson(v19Json);
      expect(restored.amount, 1.0);
    });

    test('stored v19 recipe JSON fixture loads with amount == 1.0', () {
      final v19RecipeJson = <String, Object?>{
        'schemaVersion': 19,
        'exposure': 0.2,
        'layers': [
          {
            'maskKind': 1,
            'maskParams': [0.5, 0.5, 0.2, 0.2, 0.3],
            'exposure': 0.5,
          }
        ],
      };
      final recipe = EditRecipe.fromJson(v19RecipeJson);
      expect(recipe.layers.single.amount, 1.0);
      expect(recipe.schemaVersion, EditRecipe.currentSchemaVersion);
    });

    test('copyWith(amount: 0.5) changes == and recipe hash', () {
      const layer1 = AdjustmentLayer(amount: 1.0, exposure: 0.5);
      final layer2 = layer1.copyWith(amount: 0.5);
      expect(layer2.amount, 0.5);
      expect(layer1, isNot(equals(layer2)));
      expect(layer1.hashCode, isNot(equals(layer2.hashCode)));

      final r1 = EditRecipe.neutral.copyWith(layers: [layer1]);
      final r2 = EditRecipe.neutral.copyWith(layers: [layer2]);
      expect(r1, isNot(equals(r2)));
      expect(r1.hashCode, isNot(equals(r2.hashCode)));
    });

    test('bitmap constructor accepts amount', () {
      final layer = AdjustmentLayer.bitmap(
        width: 2,
        height: 2,
        alphas: const [0, 1, 0, 1],
        amount: 1.5,
      );
      expect(layer.amount, 1.5);
    });
  });

  group('MaskGroup & MaskJoinOp (Issue #92 / Schema v21)', () {
    test('MaskJoinOp serialization and deserialization', () {
      expect(MaskJoinOp.add.index, 0);
      expect(MaskJoinOp.subtract.index, 1);
      expect(MaskJoinOp.intersect.index, 2);
    });

    test('AdjustmentLayer roundtrips groupId and joinOp through JSON', () {
      const layer = AdjustmentLayer(
        maskKind: MaskKind.radial,
        groupId: 'group_test_1',
        joinOp: MaskJoinOp.subtract,
        amount: 1.2,
      );
      final json = layer.toJson();
      expect(json['groupId'], 'group_test_1');
      expect(json['joinOp'], MaskJoinOp.subtract.index);

      final restored = AdjustmentLayer.fromJson(json);
      expect(restored.groupId, 'group_test_1');
      expect(restored.joinOp, MaskJoinOp.subtract);
      expect(restored, layer);

      final fromString = AdjustmentLayer.fromJson({
        ...json,
        'joinOp': 'subtract',
      });
      expect(fromString.joinOp, MaskJoinOp.subtract);
    });

    test('MaskGroup roundtrips through JSON with defaults', () {
      const group = MaskGroup(
        id: 'grp_42',
        name: 'Sky & Subject',
        amount: 1.5,
        inverted: true,
        exposure: 0.4,
        contrast: 0.2,
        highlights: -0.3,
        shadows: 0.1,
        temperature: 0.2,
        tint: -0.1,
        saturation: 0.3,
      );
      final json = group.toJson();
      final restored = MaskGroup.fromJson(json);
      expect(restored, group);
      expect(restored.id, 'grp_42');
      expect(restored.amount, 1.5);
      expect(restored.inverted, isTrue);
      expect(restored.exposure, 0.4);
    });

    test('Recipe serializes and deserializes maskGroups', () {
      const group = MaskGroup(id: 'g1', name: 'Mask 1', amount: 1.25);
      const layer = AdjustmentLayer(
        maskKind: MaskKind.linear,
        groupId: 'g1',
        joinOp: MaskJoinOp.add,
      );
      final recipe = EditRecipe.neutral.copyWith(
        maskGroups: const [group],
        layers: const [layer],
      );
      final json = recipe.toJson();
      final restored = EditRecipe.fromJson(json);
      expect(restored.maskGroups.length, 1);
      expect(restored.maskGroups.first.id, 'g1');
      expect(restored.maskGroups.first.amount, 1.25);
      expect(restored.layers.first.groupId, 'g1');
      expect(restored.layers.first.joinOp, MaskJoinOp.add);
      expect(restored.schemaVersion, EditRecipe.currentSchemaVersion);
    });

    test('v20 recipe migrates to v21 with empty maskGroups', () {
      final v20Json = {
        'schemaVersion': 20,
        'layers': [
          {
            'maskKind': 1,
            'maskParams': [0.5, 0.5, 0.2, 0.2, 0.3],
            'exposure': 0.5,
          }
        ],
      };
      final recipe = EditRecipe.fromJson(v20Json);
      expect(recipe.maskGroups, isEmpty);
      expect(recipe.layers.single.groupId, isNull);
      expect(recipe.layers.single.joinOp, MaskJoinOp.add);
      expect(recipe.schemaVersion, EditRecipe.currentSchemaVersion);
    });
  });

  group('Zone System & Luminance Band (Issue #93)', () {
    test('extracts lumaMin, lumaMax, lumaFeatherLo, lumaFeatherHi, and lumaZone', () {
      const darksLayer = AdjustmentLayer(
        maskKind: MaskKind.luminance,
        maskParams: [0.0, 0.4],
      );
      expect(darksLayer.lumaMin, 0.0);
      expect(darksLayer.lumaMax, 0.4);
      expect(darksLayer.lumaFeatherLo, 0.15);
      expect(darksLayer.lumaFeatherHi, 0.15);
      expect(darksLayer.lumaZone, 2); // (0.0 + 0.4) / 2 = 0.2 -> Zone 2

      const bandLayer = AdjustmentLayer(
        maskKind: MaskKind.luminance,
        maskParams: [0.45, 0.55, 0.08, 0.12],
      );
      expect(bandLayer.lumaMin, 0.45);
      expect(bandLayer.lumaMax, 0.55);
      expect(bandLayer.lumaFeatherLo, 0.08);
      expect(bandLayer.lumaFeatherHi, 0.12);
      expect(bandLayer.lumaZone, 5); // 0.5 -> Zone V
    });

    test('withLumaBand updates luminance parameters', () {
      const base = AdjustmentLayer(
        maskKind: MaskKind.luminance,
        maskParams: [0.0, 0.4],
      );
      final updated = base.withLumaBand(min: 0.3, max: 0.7, featherLo: 0.1, featherHi: 0.1);
      expect(updated.lumaMin, 0.3);
      expect(updated.lumaMax, 0.7);
      expect(updated.lumaFeatherLo, 0.1);
      expect(updated.lumaFeatherHi, 0.1);
    });

    test('withZone sets correct band for Ansel Adams zones', () {
      const base = AdjustmentLayer(maskKind: MaskKind.luminance);
      // Zone 0: pure black
      final z0 = base.withZone(0);
      expect(z0.lumaMin, 0.0);
      expect(z0.lumaZone, 0);

      // Zone V: middle gray
      final z5 = base.withZone(5);
      expect(z5.lumaZone, 5);
      expect((z5.lumaMin - 0.45).abs(), lessThan(1e-3));
      expect((z5.lumaMax - 0.55).abs(), lessThan(1e-3));

      // Zone X: pure white
      final z10 = base.withZone(10);
      expect(z10.lumaMax, 1.0);
      expect(z10.lumaZone, 10);
    });
  });

  group('Color wheels & pointwise highlights/shadows (Issue #94)', () {
    test('AdjustmentLayer serializes and deserializes color wheels and highlights/shadows', () {
      const layer = AdjustmentLayer(
        highlights: 0.35,
        shadows: -0.25,
        gradeShadowHue: 210,
        gradeShadowSat: 0.6,
        gradeShadowLum: -0.1,
        gradeMidHue: 45,
        gradeMidSat: 0.3,
        gradeMidLum: 0.1,
        gradeHighlightHue: 30,
        gradeHighlightSat: 0.5,
        gradeHighlightLum: 0.2,
        gradeBlending: 0.7,
        gradeBalance: -0.15,
      );

      final restored = AdjustmentLayer.fromJson(layer.toJson());
      expect(restored, layer);
      expect(restored.highlights, 0.35);
      expect(restored.shadows, -0.25);
      expect(restored.gradeShadowHue, 210);
      expect(restored.gradeShadowSat, 0.6);
      expect(restored.gradeShadowLum, -0.1);
      expect(restored.gradeMidHue, 45);
      expect(restored.gradeMidSat, 0.3);
      expect(restored.gradeMidLum, 0.1);
      expect(restored.gradeHighlightHue, 30);
      expect(restored.gradeHighlightSat, 0.5);
      expect(restored.gradeHighlightLum, 0.2);
      expect(restored.gradeBlending, 0.7);
      expect(restored.gradeBalance, -0.15);
    });

    test('MaskGroup serializes and deserializes color wheels and highlights/shadows', () {
      const group = MaskGroup(
        id: 'group_test_94',
        name: 'Sky Grade',
        highlights: -0.4,
        shadows: 0.3,
        gradeShadowHue: 240,
        gradeShadowSat: 0.5,
        gradeShadowLum: -0.2,
        gradeMidHue: 60,
        gradeMidSat: 0.2,
        gradeMidLum: 0.05,
        gradeHighlightHue: 40,
        gradeHighlightSat: 0.4,
        gradeHighlightLum: 0.15,
        gradeBlending: 0.65,
        gradeBalance: 0.2,
      );

      final restored = MaskGroup.fromJson(group.toJson());
      expect(restored, group);
      expect(restored.highlights, -0.4);
      expect(restored.shadows, 0.3);
      expect(restored.gradeShadowHue, 240);
      expect(restored.gradeShadowSat, 0.5);
      expect(restored.gradeShadowLum, -0.2);
      expect(restored.gradeMidHue, 60);
      expect(restored.gradeMidSat, 0.2);
      expect(restored.gradeMidLum, 0.05);
      expect(restored.gradeHighlightHue, 40);
      expect(restored.gradeHighlightSat, 0.4);
      expect(restored.gradeHighlightLum, 0.15);
      expect(restored.gradeBlending, 0.65);
      expect(restored.gradeBalance, 0.2);
    });

    test('backward compatibility: missing color wheel fields decode to defaults', () {
      final legacyLayerJson = <String, Object?>{
        'maskKind': MaskKind.radial.index,
        'maskParams': [0.5, 0.5, 0.3, 0.3, 0.3],
        'exposure': 0.5,
      };
      final layer = AdjustmentLayer.fromJson(legacyLayerJson);
      expect(layer.highlights, 0.0);
      expect(layer.shadows, 0.0);
      expect(layer.gradeShadowHue, 0.0);
      expect(layer.gradeShadowSat, 0.0);
      expect(layer.gradeShadowLum, 0.0);
      expect(layer.gradeMidHue, 0.0);
      expect(layer.gradeMidSat, 0.0);
      expect(layer.gradeMidLum, 0.0);
      expect(layer.gradeHighlightHue, 0.0);
      expect(layer.gradeHighlightSat, 0.0);
      expect(layer.gradeHighlightLum, 0.0);
      expect(layer.gradeBlending, 0.5);
      expect(layer.gradeBalance, 0.0);

      final legacyGroupJson = <String, Object?>{
        'id': 'legacy_group',
        'name': 'Old Group',
      };
      final group = MaskGroup.fromJson(legacyGroupJson);
      expect(group.highlights, 0.0);
      expect(group.shadows, 0.0);
      expect(group.gradeShadowHue, 0.0);
      expect(group.gradeShadowSat, 0.0);
      expect(group.gradeShadowLum, 0.0);
      expect(group.gradeBlending, 0.5);
      expect(group.gradeBalance, 0.0);
    });
  });

  group('withRefinedAlphas (issue #95)', () {
    test('converts layer to MaskKind.bitmap while preserving all grading settings', () {
      const original = AdjustmentLayer(
        maskKind: MaskKind.radial,
        maskParams: [0.5, 0.5, 0.2, 0.2, 0.3],
        exposure: 0.75,
        contrast: 0.2,
        highlights: -0.3,
        shadows: 0.4,
        gradeMidHue: 210,
        gradeMidSat: 0.5,
        groupId: 'grp1',
        joinOp: MaskJoinOp.intersect,
        inverted: true,
        amount: 1.5,
      );

      final alphas = [0.0, 0.5, 1.0, 0.25];
      final refined = original.withRefinedAlphas(alphas, 2, 2);

      expect(refined.maskKind, MaskKind.bitmap);
      expect(refined.bitmapWidth, 2);
      expect(refined.bitmapHeight, 2);
      expect(refined.exposure, 0.75);
      expect(refined.contrast, 0.2);
      expect(refined.highlights, -0.3);
      expect(refined.shadows, 0.4);
      expect(refined.gradeMidHue, 210);
      expect(refined.gradeMidSat, 0.5);
      expect(refined.groupId, 'grp1');
      expect(refined.joinOp, MaskJoinOp.intersect);
      expect(refined.inverted, isTrue);
      expect(refined.amount, 1.5);
      expect(refined.maskBlob, isNotNull);
      expect(refined.maskBlob!.length, 4);
      expect(refined.maskBlob![0], 0);
      expect(refined.maskBlob![1], 128); // 0.5 * 255 rounded = 128
      expect(refined.maskBlob![2], 255);
      expect(refined.maskBlob![3], 64);
    });
  });
}


