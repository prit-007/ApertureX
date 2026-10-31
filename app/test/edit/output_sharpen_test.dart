import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/color/spatial_spec.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/viewport/base_spec.dart';

void main() {
  group('Output Sharpening Recipe & Pipeline Tests', () {
    test('default recipe has outputSharpen 0 and screen media (0)', () {
      const r = EditRecipe();
      expect(r.outputSharpen, 0.0);
      expect(r.outputSharpenMedia, 0);
    });

    test('roundtrips outputSharpen and outputSharpenMedia via JSON', () {
      const r = EditRecipe(
        outputSharpen: 0.75,
        outputSharpenMedia: 2, // PrintGlossy
      );

      final jsonMap = r.toJson();
      expect(jsonMap['outputSharpen'], 0.75);
      expect(jsonMap['outputSharpenMedia'], 2);

      final jsonStr = jsonEncode(jsonMap);
      final decoded = EditRecipe.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

      expect(decoded.outputSharpen, 0.75);
      expect(decoded.outputSharpenMedia, 2);
      expect(decoded, equals(r));
    });

    test('copyWith updates outputSharpen and preserves other parameters', () {
      const base = EditRecipe(exposure: 1.0, contrast: 0.2);
      final updated = base.copyWith(
        outputSharpen: 0.5,
        outputSharpenMedia: 1, // PrintMatte
      );

      expect(updated.exposure, 1.0);
      expect(updated.contrast, 0.2);
      expect(updated.outputSharpen, 0.5);
      expect(updated.outputSharpenMedia, 1);
    });

    test('SpatialSpec.fromRecipe maps output sharpen parameters accurately', () {
      const r = EditRecipe(
        sharpen: 0.4,
        outputSharpen: 0.8,
        outputSharpenMedia: 3, // Web
      );

      final spec = SpatialSpec.fromRecipe(r);
      expect(spec.outputSharpen, 0.8);
      expect(spec.outputSharpenMedia, 3);
    });

    test('baseSpecFromRecipe maps output sharpening from recipe', () {
      const r = EditRecipe(
        outputSharpen: 0.6,
        outputSharpenMedia: 1,
      );

      final spec = baseSpecFromRecipe(r);

      expect(spec.outputSharpen, 0.6);
      expect(spec.outputSharpenMedia, 1);
    });

    test('parameter catalog provides valid specs for outputSharpen', () {
      final sSharpen = specOf(Parameter.outputSharpen);
      expect(sSharpen.min, 0.0);
      expect(sSharpen.max, 1.0);
      expect(sSharpen.neutral, 0.0);

      final sMedia = specOf(Parameter.outputSharpenMedia);
      expect(sMedia.min, 0.0);
      expect(sMedia.max, 3.0);
      expect(sMedia.neutral, 0.0);
    });
  });
}
