import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/library_catalog.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/recipe_store.dart';

/// Round-trip, relaunch, and virtual-copy isolation for the JSON library
/// catalog (#73 / #61). Uses a real temp file so the atomic temp+rename
/// write path is exercised end to end.
void main() {
  late Directory dir;
  late ProviderContainer container;

  LibraryCatalogStore store() =>
      JsonLibraryCatalogStore(file: () async => File('${dir.path}/library.json'));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('aperturex-catalog');
    container = ProviderContainer(
      overrides: [libraryCatalogStoreProvider.overrideWithValue(store())],
    );
  });

  tearDown(() async {
    container.dispose();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('JSON persistence', () {
    test('syncRecipe + flush writes a file with no leftover temp', () async {
      final catalog = container.read(libraryCatalogProvider.notifier);
      catalog.syncRecipe(
        originalEntryId('a'),
        EditRecipe.neutral.copyWith(exposure: 1.5),
      );
      await catalog.flush();

      final file = File('${dir.path}/library.json');
      expect(await file.exists(), isTrue);
      // Atomic write: the temp file is renamed away, never left behind.
      expect(await File('${file.path}.tmp').exists(), isFalse);

      final entries = await store().load();
      expect(entries[originalEntryId('a')]!.recipe.exposure, 1.5);
      expect(entries[originalEntryId('a')]!.sourceAssetId, 'a');
      expect(entries[originalEntryId('a')]!.kind, CatalogEntryKind.original);
    });

    test('hydrate restores entries into the live recipe store (#61)', () async {
      final vc = container
          .read(libraryCatalogProvider.notifier)
          .createVirtualCopy(
            sourceAssetId: 'a',
            recipe: EditRecipe.neutral.copyWith(contrast: 0.4),
          );
      container
          .read(recipeStoreProvider.notifier)
          .put(originalEntryId('a'), EditRecipe.neutral.copyWith(exposure: 2));
      await container.read(libraryCatalogProvider.notifier).flush();
      container.dispose();

      // Relaunch: a fresh container over the same file.
      final relaunch = ProviderContainer(
        overrides: [libraryCatalogStoreProvider.overrideWithValue(store())],
      );
      addTearDown(relaunch.dispose);
      await relaunch.read(libraryCatalogProvider.notifier).hydrate();

      final entries = relaunch.read(libraryCatalogProvider);
      expect(entries[originalEntryId('a')]!.recipe.exposure, 2);
      expect(entries[vc.entryId]!.recipe.contrast, 0.4);

      // Both recipes are back in the live store under their entry ids.
      final live = relaunch.read(recipeStoreProvider);
      expect(live[originalEntryId('a')]!.exposure, 2);
      expect(live[vc.entryId]!.contrast, 0.4);
    });

    test('hydrate is idempotent and merges over unsaved in-memory work', () async {
      final catalog = container.read(libraryCatalogProvider.notifier);
      catalog.syncRecipe(
        originalEntryId('a'),
        EditRecipe.neutral.copyWith(exposure: 1),
      );
      await catalog.flush();

      // A newer edit lands in memory before the next hydrate.
      catalog.syncRecipe(
        originalEntryId('a'),
        EditRecipe.neutral.copyWith(exposure: 3),
      );
      await catalog.hydrate();
      await catalog.hydrate(); // second call: no-op

      final entries = container.read(libraryCatalogProvider);
      expect(entries[originalEntryId('a')]!.recipe.exposure, 3);
      await catalog.flush();
      expect((await store().load())[originalEntryId('a')]!.recipe.exposure, 3);
    });
  });

  group('virtual copies', () {
    test('create snapshots the recipe and never touches the original', () {
      container
          .read(recipeStoreProvider.notifier)
          .put(originalEntryId('a'), EditRecipe.neutral.copyWith(exposure: 1));
      final catalog = container.read(libraryCatalogProvider.notifier);

      final vc = catalog.createVirtualCopy(
        sourceAssetId: 'a',
        recipe: EditRecipe.neutral.copyWith(exposure: 1, contrast: 0.5),
      );

      final entries = container.read(libraryCatalogProvider);
      expect(entries[vc.entryId]!.kind, CatalogEntryKind.virtualCopy);
      expect(entries[vc.entryId]!.sourceAssetId, 'a');
      // The original entry and its recipe are untouched.
      expect(entries[originalEntryId('a')]!.recipe.exposure, 1);
      expect(
        container.read(recipeStoreProvider)[originalEntryId('a')]!.exposure,
        1,
      );
      // The copy is live under its own entry id.
      expect(container.read(recipeStoreProvider)[vc.entryId]!.contrast, 0.5);
    });

    test('a virtual copy of an unedited original survives creation', () {
      final catalog = container.read(libraryCatalogProvider.notifier);

      final vc = catalog.createVirtualCopy(
        sourceAssetId: 'a',
        recipe: EditRecipe.neutral,
      );

      final entries = container.read(libraryCatalogProvider);
      expect(entries.containsKey(vc.entryId), isTrue);
      expect(entries[vc.entryId]!.recipe, EditRecipe.neutral);
      // Neutral copies are carried by the catalog alone — the recipe store
      // treats neutral as absence and must not conjure an entry.
      expect(
        container.read(recipeStoreProvider).containsKey(vc.entryId),
        isFalse,
      );
    });

    test('delete removes only the copy', () {
      container
          .read(recipeStoreProvider.notifier)
          .put(originalEntryId('a'), EditRecipe.neutral.copyWith(exposure: 1));
      final catalog = container.read(libraryCatalogProvider.notifier);
      final vc = catalog.createVirtualCopy(
        sourceAssetId: 'a',
        recipe: EditRecipe.neutral.copyWith(exposure: 1),
      );

      catalog.deleteVirtualCopy(vc.entryId);

      final entries = container.read(libraryCatalogProvider);
      expect(entries.containsKey(vc.entryId), isFalse);
      expect(entries.containsKey(originalEntryId('a')), isTrue);
      final live = container.read(recipeStoreProvider);
      expect(live.containsKey(vc.entryId), isFalse);
      expect(live[originalEntryId('a')]!.exposure, 1);
    });

    test('rename updates the label and survives a flush', () async {
      final catalog = container.read(libraryCatalogProvider.notifier);
      final vc = catalog.createVirtualCopy(
        sourceAssetId: 'a',
        recipe: EditRecipe.neutral,
      );

      catalog.rename(vc.entryId, 'B&W try');
      await catalog.flush();

      expect(container.read(libraryCatalogProvider)[vc.entryId]!.label, 'B&W try');
      expect((await store().load())[vc.entryId]!.label, 'B&W try');
    });
  });

  group('original entries', () {
    test('a neutral recipe drops a metadata-free entry', () {
      final catalog = container.read(libraryCatalogProvider.notifier);
      catalog.syncRecipe(
        originalEntryId('a'),
        EditRecipe.neutral.copyWith(exposure: 1),
      );
      expect(
        container.read(libraryCatalogProvider).containsKey(originalEntryId('a')),
        isTrue,
      );

      catalog.syncRecipe(originalEntryId('a'), EditRecipe.neutral);

      expect(
        container.read(libraryCatalogProvider).containsKey(originalEntryId('a')),
        isFalse,
      );
    });

    test('metadata (label/rating) keeps a neutral entry alive', () async {
      final catalog = container.read(libraryCatalogProvider.notifier);
      catalog.syncRecipe(
        originalEntryId('a'),
        EditRecipe.neutral.copyWith(exposure: 1),
      );
      catalog.rename(originalEntryId('a'), 'Keeper');
      catalog.setRating(originalEntryId('a'), 3);

      catalog.syncRecipe(originalEntryId('a'), EditRecipe.neutral);

      final entry = container.read(libraryCatalogProvider)[originalEntryId('a')];
      expect(entry, isNotNull);
      expect(entry!.recipe, EditRecipe.neutral);
      expect(entry.label, 'Keeper');
      expect(entry.rating, 3);
    });

    test('clear() resets recipes but leaves virtual copies intact', () {
      final catalog = container.read(libraryCatalogProvider.notifier);
      catalog.syncRecipe(
        originalEntryId('a'),
        EditRecipe.neutral.copyWith(exposure: 1),
      );
      final vc = catalog.createVirtualCopy(
        sourceAssetId: 'a',
        recipe: EditRecipe.neutral.copyWith(exposure: 1),
      );
      container.read(recipeStoreProvider.notifier).clear();

      catalog.resetRecipes();

      final entries = container.read(libraryCatalogProvider);
      expect(entries.containsKey(originalEntryId('a')), isFalse);
      expect(entries[vc.entryId]!.recipe, EditRecipe.neutral);
      expect(container.read(recipeStoreProvider), isEmpty);
    });

    test('rating an unedited photo creates its metadata entry', () {
      final catalog = container.read(libraryCatalogProvider.notifier);

      catalog.setRating(originalEntryId('a'), 4);

      final entry = container.read(libraryCatalogProvider)[
        originalEntryId('a')
      ];
      expect(entry, isNotNull);
      expect(entry!.recipe, EditRecipe.neutral);
      expect(entry.rating, 4);
      expect(entry.hasMetadata, isTrue);
    });

    test('rating 0 on an unknown entry is a no-op', () {
      final catalog = container.read(libraryCatalogProvider.notifier);

      catalog.setRating(originalEntryId('a'), 0);

      expect(
        container.read(libraryCatalogProvider).containsKey(originalEntryId('a')),
        isFalse,
      );
    });

    test('setFlag toggles the flag independently per entry (#74)', () {
      final catalog = container.read(libraryCatalogProvider.notifier);
      final vc = catalog.createVirtualCopy(
        sourceAssetId: 'a',
        recipe: EditRecipe.neutral,
      );

      catalog.setFlag(originalEntryId('a'), true);
      catalog.setFlag(vc.entryId, true);

      final entries = container.read(libraryCatalogProvider);
      expect(entries[originalEntryId('a')]!.flag, isTrue);
      expect(entries[vc.entryId]!.flag, isTrue);

      // Clearing the flag on the original — its only metadata — drops that
      // entry, while the copy keeps its own flag.
      catalog.setFlag(originalEntryId('a'), false);

      expect(
        container.read(libraryCatalogProvider).containsKey(
          originalEntryId('a'),
        ),
        isFalse,
      );
      expect(
        container.read(libraryCatalogProvider)[vc.entryId]!.flag,
        isTrue,
      );
    });

    test('setFlag on an unknown original creates a neutral flagged entry', () {
      final catalog = container.read(libraryCatalogProvider.notifier);

      catalog.setFlag(originalEntryId('a'), true);

      final entry = container.read(libraryCatalogProvider)[
        originalEntryId('a')
      ];
      expect(entry, isNotNull);
      expect(entry!.flag, isTrue);
      expect(entry.recipe, EditRecipe.neutral);

      // Clearing a flag on a metadata-free entry drops it again.
      catalog.setFlag(originalEntryId('a'), false);
      expect(
        container.read(libraryCatalogProvider).containsKey(originalEntryId('a')),
        isFalse,
      );
    });
  });
}
