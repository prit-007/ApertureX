import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/recipe_mapping.dart';

void main() {
  group('EditRecipe v19 (Film Emulation & Shader Lab)', () {
    test('currentSchemaVersion is 20', () {
      expect(EditRecipe.currentSchemaVersion, 20);
    });

    test('default recipe has neutral film and lab parameters', () {
      const r = EditRecipe();
      expect(r.filmHalation, 0.0);
      expect(r.filmHalationRadius, 0.5);
      expect(r.filmHalationThreshold, 0.8);
      expect(r.filmBloom, 0.0);
      expect(r.filmBloomRadius, 0.5);
      expect(r.filmBloomThreshold, 0.75);
      expect(r.filmDust, 0.0);
      expect(r.filmScratches, 0.0);
      expect(r.shaderLabPreset, 0);
      expect(r.shaderParam1, 0.0);
      expect(r.shaderParam2, 0.0);
      expect(r.shaderParam3, 0.0);
    });

    test('round-trips film and lab parameters through JSON', () {
      const r = EditRecipe(
        filmHalation: 0.75,
        filmHalationRadius: 0.6,
        filmHalationThreshold: 0.7,
        filmBloom: 0.5,
        filmBloomRadius: 0.4,
        filmBloomThreshold: 0.65,
        filmDust: 0.3,
        filmScratches: 0.2,
        shaderLabPreset: 1,
        shaderParam1: 0.8,
        shaderParam2: 0.4,
        shaderParam3: 0.1,
      );

      final json = r.toJson();
      final restored = EditRecipe.fromJson(json);

      expect(restored.schemaVersion, EditRecipe.currentSchemaVersion);
      expect(restored.filmHalation, 0.75);
      expect(restored.filmHalationRadius, 0.6);
      expect(restored.filmHalationThreshold, 0.7);
      expect(restored.filmBloom, 0.5);
      expect(restored.filmBloomRadius, 0.4);
      expect(restored.filmBloomThreshold, 0.65);
      expect(restored.filmDust, 0.3);
      expect(restored.filmScratches, 0.2);
      expect(restored.shaderLabPreset, 1);
      expect(restored.shaderParam1, 0.8);
      expect(restored.shaderParam2, 0.4);
      expect(restored.shaderParam3, 0.1);
      expect(restored, r);
    });

    test('migrates older v18 recipes to v20 with neutral film & lab fields', () {
      final oldJson = <String, dynamic>{
        'schemaVersion': 18,
        'exposure': 1.0,
        'contrast': 0.2,
      };

      final migrated = EditRecipe.fromJson(oldJson);
      expect(migrated.schemaVersion, EditRecipe.currentSchemaVersion);
      expect(migrated.exposure, 1.0);
      expect(migrated.contrast, 0.2);
      expect(migrated.filmHalation, 0.0);
      expect(migrated.filmBloom, 0.0);
      expect(migrated.shaderLabPreset, 0);
    });

    test('RecipeSection contains film and lab with registered parameters', () {
      expect(RecipeSection.values, contains(RecipeSection.film));
      expect(RecipeSection.values, contains(RecipeSection.lab));

      final filmParams = parametersIn(RecipeSection.film);
      expect(filmParams, contains(Parameter.filmHalation));
      expect(filmParams, contains(Parameter.filmBloom));
      expect(filmParams, contains(Parameter.filmDust));
      expect(filmParams, contains(Parameter.filmScratches));

      final labParams = parametersIn(RecipeSection.lab);
      expect(labParams, contains(Parameter.shaderParam1));
    });
  });
}
