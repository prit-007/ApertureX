import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/edit/retouch_patch.dart';

void main() {
  group('RetouchPatch model', () {
    test('default values', () {
      const patch = RetouchPatch(
        targetX: 0.5,
        targetY: 0.5,
        sourceX: 0.4,
        sourceY: 0.4,
      );
      expect(patch.radius, 0.05);
      expect(patch.feather, 0.5);
      expect(patch.opacity, 1.0);
      expect(patch.mode, RetouchMode.heal);
    });

    test('JSON round-trip', () {
      const patch = RetouchPatch(
        targetX: 0.25,
        targetY: 0.75,
        sourceX: 0.30,
        sourceY: 0.80,
        radius: 0.08,
        feather: 0.4,
        opacity: 0.9,
        mode: RetouchMode.clone,
      );
      final json = patch.toJson();
      final roundTrip = RetouchPatch.fromJson(json);
      expect(roundTrip, patch);
    });

    test('equality and copyWith', () {
      const patch = RetouchPatch(
        targetX: 0.1,
        targetY: 0.2,
        sourceX: 0.3,
        sourceY: 0.4,
      );
      final updated = patch.copyWith(mode: RetouchMode.clone, opacity: 0.8);
      expect(updated.mode, RetouchMode.clone);
      expect(updated.opacity, 0.8);
      expect(updated.targetX, 0.1);
      expect(patch == updated, isFalse);
    });
  });

  group('Recipe retouchPatches integration', () {
    test('neutral recipe has empty retouch patches', () {
      expect(EditRecipe.neutral.retouchPatches, isEmpty);
    });

    test('EditRecipe JSON round-trip retains patches', () {
      const patch = RetouchPatch(
        targetX: 0.5,
        targetY: 0.5,
        sourceX: 0.4,
        sourceY: 0.4,
        mode: RetouchMode.heal,
      );
      final recipe = EditRecipe.neutral.copyWith(retouchPatches: [patch]);
      final json = recipe.toJson();
      final restored = EditRecipe.fromJson(json);
      expect(restored.retouchPatches.length, 1);
      expect(restored.retouchPatches.first, patch);
    });

    test('RecipeController manipulates retouch patches', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(recipeControllerProvider.notifier);

      expect(container.read(recipeControllerProvider).recipe.retouchPatches, isEmpty);

      const p1 = RetouchPatch(targetX: 0.2, targetY: 0.2, sourceX: 0.1, sourceY: 0.1);
      notifier.addRetouchPatch(p1);
      expect(container.read(recipeControllerProvider).recipe.retouchPatches.length, 1);
      expect(container.read(recipeControllerProvider).history.last.label, 'Heal');

      final p1Modified = p1.copyWith(radius: 0.1);
      notifier.updateRetouchPatchAt(0, p1Modified);
      expect(container.read(recipeControllerProvider).recipe.retouchPatches.first.radius, 0.1);

      const p2 = RetouchPatch(
        targetX: 0.6,
        targetY: 0.6,
        sourceX: 0.5,
        sourceY: 0.5,
        mode: RetouchMode.clone,
      );
      notifier.addRetouchPatch(p2);
      expect(container.read(recipeControllerProvider).recipe.retouchPatches.length, 2);
      expect(container.read(recipeControllerProvider).history.last.label, 'Clone');

      notifier.removeRetouchPatchAt(0);
      expect(container.read(recipeControllerProvider).recipe.retouchPatches.length, 1);
      expect(container.read(recipeControllerProvider).recipe.retouchPatches.first.targetX, 0.6);

      notifier.clearRetouchPatches();
      expect(container.read(recipeControllerProvider).recipe.retouchPatches, isEmpty);
    });
  });
}
