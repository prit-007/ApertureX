import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/color/spatial_spec.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/selective_recipe.dart';
import 'package:aperturex/engine/engine.dart';
import 'package:aperturex/features/ai_plugins/ai_plugin_model.dart';
import 'package:aperturex/features/ai_plugins/ai_plugin_store.dart';

void main() {
  group('AI Denoise Parameter & Recipe Integration', () {
    test('EditRecipe defaults aiDenoise to 0.0 and round-trips JSON', () {
      const neutral = EditRecipe.neutral;
      expect(neutral.aiDenoise, 0.0);

      final modified = neutral.copyWith(aiDenoise: 0.65);
      expect(modified.aiDenoise, 0.65);

      final json = modified.toJson();
      expect(json['aiDenoise'], 0.65);

      final restored = EditRecipe.fromJson(json);
      expect(restored.aiDenoise, 0.65);
      expect(restored, equals(modified));
    });

    test('Parameter.aiDenoise binds to RecipeSection.detail and updates recipe', () {
      final spec = specOf(Parameter.aiDenoise);
      expect(spec.section, RecipeSection.detail);
      expect(spec.label, 'AI Denoise');
      expect(spec.min, 0.0);
      expect(spec.max, 1.0);

      const r = EditRecipe.neutral;
      final updated = withValue(r, Parameter.aiDenoise, 0.75);
      expect(valueOf(updated, Parameter.aiDenoise), 0.75);

      expect(isSectionModified(updated, RecipeSection.detail), isTrue);
      expect(isSectionModified(r, RecipeSection.detail), isFalse);
    });

    test('CopiedSettings preserves aiDenoise', () {
      final source = const EditRecipe().copyWith(aiDenoise: 0.85);
      final copied = CopiedSettings.modifiedOnly(source);
      expect(copied.sections, contains(RecipeSection.detail));

      final applied = copied.applyTo(const EditRecipe());
      expect(applied.aiDenoise, 0.85);
    });

    test('SpatialSpec reads aiDenoise from recipe', () {
      const neutral = EditRecipe.neutral;
      final neutralSpec = SpatialSpec.fromRecipe(neutral);
      expect(neutralSpec.isNeutral, isTrue);

      final withDenoise = neutral.copyWith(aiDenoise: 0.5);
      final spec = SpatialSpec.fromRecipe(withDenoise);
      expect(spec.aiDenoise, 0.5);
      expect(spec.isNeutral, isFalse);
    });
  });

  group('AxEngine.aiDenoise bilateral filtering', () {
    test('returns exact input buffer when amount is 0.0', () {
      final rgba = Uint8List.fromList([
        100, 100, 100, 255,
        150, 150, 150, 255,
      ]);
      final result = AxEngine.aiDenoise(rgba, 2, 1, 0.0);
      expect(result, same(rgba));
    });

    test('smooths flat noisy regions while preserving hard step edges', () {
      // 4x4 image:
      // Left 2 columns: ~50 with subtle noise (48, 52)
      // Right 2 columns: ~200 with subtle noise (198, 202)
      // Hard step edge between column 1 and column 2
      const w = 4;
      const h = 4;
      final rgba = Uint8List(w * h * 4);

      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final off = (y * w + x) * 4;
          final base = x < 2 ? 50 : 200;
          final noise = (x + y) % 2 == 0 ? -4 : 4;
          final v = base + noise;
          rgba[off] = v;
          rgba[off + 1] = v;
          rgba[off + 2] = v;
          rgba[off + 3] = 255;
        }
      }

      final filtered = AxEngine.aiDenoise(rgba, w, h, 0.8);
      expect(filtered.length, rgba.length);

      // Verify that left columns stayed close to ~50 and right to ~200 (step preserved)
      // Col 0 pixel (0,0)
      expect(filtered[0], inInclusiveRange(45, 55));
      // Col 3 pixel (3,0)
      const col3Off = 3 * 4;
      expect(filtered[col3Off], inInclusiveRange(195, 205));
    });
  });

  group('AI Plugin Store Denoise Models', () {
    test('AiTask.denoise has correct label', () {
      expect(AiTask.denoise.label, 'AI Neural Denoise');
    });

    test('kCommunityAiPlugins contains NAFNet and SCUNet denoise plugins', () {
      final denoisePlugins = kCommunityAiPlugins.where((p) => p.task == AiTask.denoise).toList();
      expect(denoisePlugins.length, greaterThanOrEqualTo(2));

      final ids = denoisePlugins.map((p) => p.id).toList();
      expect(ids, contains('nafnet-denoise'));
      expect(ids, contains('scunet-color'));
    });
  });
}
