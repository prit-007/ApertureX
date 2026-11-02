import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/edit/recipe_snapshot.dart';
import 'package:aperturex/edit/snapshots_provider.dart';

void main() {
  group('RecipeSnapshot', () {
    test('JSON serialization roundtrip preserves all fields', () {
      final recipe = EditRecipe.neutral.copyWith(
        exposure: 1.5,
        contrast: 0.3,
        temperature: 6500,
      );
      final original = RecipeSnapshot(
        id: 'snap_123',
        name: 'Warm Sunset Look',
        recipe: recipe,
        timestamp: DateTime.utc(2026, 11, 2, 12, 0, 0),
      );

      final json = original.toJson();
      final decoded = RecipeSnapshot.fromJson(json);

      expect(decoded.id, 'snap_123');
      expect(decoded.name, 'Warm Sunset Look');
      expect(decoded.recipe.exposure, 1.5);
      expect(decoded.recipe.contrast, 0.3);
      expect(decoded.recipe.temperature, 6500);
      expect(decoded.timestamp, original.timestamp);
      expect(decoded, original);
    });

    test('copyWith updates specified fields only', () {
      final snap = RecipeSnapshot(
        id: 's1',
        name: 'Original',
        recipe: EditRecipe.neutral,
        timestamp: DateTime.utc(2026, 1, 1),
      );

      final updated = snap.copyWith(name: 'Updated Name');
      expect(updated.id, 's1');
      expect(updated.name, 'Updated Name');
      expect(updated.recipe, snap.recipe);
      expect(updated.timestamp, snap.timestamp);
    });
  });

  group('SnapshotsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('starts with empty snapshots list', () {
      final list = container.read(snapshotsProvider);
      expect(list, isEmpty);
    });

    test('createSnapshot appends new snapshot to front of list', () {
      final notifier = container.read(snapshotsProvider.notifier);
      final recipe1 = EditRecipe.neutral.copyWith(exposure: 0.8);
      final recipe2 = EditRecipe.neutral.copyWith(exposure: -0.5);

      final snap1 = notifier.createSnapshot(
        name: 'Bright',
        recipe: recipe1,
      );
      expect(container.read(snapshotsProvider), [snap1]);
      expect(snap1.name, 'Bright');
      expect(snap1.recipe.exposure, 0.8);

      final snap2 = notifier.createSnapshot(
        name: 'Dark Moody',
        recipe: recipe2,
      );
      final list = container.read(snapshotsProvider);
      expect(list.length, 2);
      expect(list.first.id, snap2.id);
      expect(list[1].id, snap1.id);
    });

    test('createSnapshot uses fallback name if name is empty', () {
      final notifier = container.read(snapshotsProvider.notifier);
      final snap = notifier.createSnapshot(
        name: '   ',
        recipe: EditRecipe.neutral,
      );
      expect(snap.name, 'Snapshot 1');
    });

    test('renameSnapshot updates name of matching snapshot', () {
      final notifier = container.read(snapshotsProvider.notifier);
      final snap = notifier.createSnapshot(
        name: 'Old Name',
        recipe: EditRecipe.neutral,
      );

      notifier.renameSnapshot(snap.id, 'New Name');
      final list = container.read(snapshotsProvider);
      expect(list.first.name, 'New Name');
    });

    test('deleteSnapshot removes specified snapshot', () {
      final notifier = container.read(snapshotsProvider.notifier);
      final snap1 = notifier.createSnapshot(name: 'A', recipe: EditRecipe.neutral);
      final snap2 = notifier.createSnapshot(name: 'B', recipe: EditRecipe.neutral);

      notifier.deleteSnapshot(snap1.id);
      final list = container.read(snapshotsProvider);
      expect(list.length, 1);
      expect(list.first.id, snap2.id);
    });

    test('clear removes all snapshots', () {
      final notifier = container.read(snapshotsProvider.notifier);
      notifier.createSnapshot(name: 'A', recipe: EditRecipe.neutral);
      notifier.createSnapshot(name: 'B', recipe: EditRecipe.neutral);
      expect(container.read(snapshotsProvider).length, 2);

      notifier.clear();
      expect(container.read(snapshotsProvider), isEmpty);
    });
  });

  group('RecipeController restoreRecipe', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('restoreRecipe applies snapshot and commits to DAG history', () {
      final controller = container.read(recipeControllerProvider.notifier);
      // Make an initial commit
      controller.update(Parameter.exposure, 0.5);
      controller.commit(label: 'Exposure +0.5');

      final snapshotRecipe = EditRecipe.neutral.copyWith(
        exposure: 1.2,
        highlights: -0.4,
      );

      controller.restoreRecipe(snapshotRecipe, label: 'Snapshot: Golden Hour');

      final state = container.read(recipeControllerProvider);
      expect(state.recipe.exposure, 1.2);
      expect(state.recipe.highlights, -0.4);
      expect(state.history.last.label, 'Snapshot: Golden Hour');
      expect(state.history.length, greaterThanOrEqualTo(2));
    });
  });
}
