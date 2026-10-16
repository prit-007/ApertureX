import 'package:aperturex/edit/catalog_db.dart';
import 'package:aperturex/edit/drift_catalog_store.dart';
import 'package:aperturex/edit/library_catalog.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/recipe_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CatalogDb db;
  late DriftLibraryCatalogStore store;

  setUp(() {
    db = CatalogDb(NativeDatabase.memory());
    store = DriftLibraryCatalogStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DriftLibraryCatalogStore', () {
    test('empty DB returns empty map', () async {
      final entries = await store.load();
      expect(entries, isEmpty);
    });

    test('save and load roundtrips originals and virtual copies', () async {
      final now = DateTime.utc(2026, 10, 16, 12, 0);
      final orig = CatalogEntry(
        entryId: 'orig:photo1',
        sourceAssetId: 'photo1',
        kind: CatalogEntryKind.original,
        recipe: EditRecipe.neutral.copyWith(exposure: 1.25, contrast: 0.2),
        label: 'Keeper',
        rating: 4,
        flag: true,
        created: now,
      );
      final vc = CatalogEntry(
        entryId: 'vc:123-1',
        sourceAssetId: 'photo1',
        kind: CatalogEntryKind.virtualCopy,
        recipe: EditRecipe.neutral.copyWith(temperature: 5500),
        label: 'Warm look',
        rating: 5,
        flag: false,
        created: now.add(const Duration(minutes: 5)),
      );

      await store.save({
        orig.entryId: orig,
        vc.entryId: vc,
      });

      final loaded = await store.load();
      expect(loaded.length, 2);

      final loadedOrig = loaded[orig.entryId]!;
      expect(loadedOrig.entryId, orig.entryId);
      expect(loadedOrig.sourceAssetId, orig.sourceAssetId);
      expect(loadedOrig.kind, CatalogEntryKind.original);
      expect(loadedOrig.recipe.exposure, 1.25);
      expect(loadedOrig.recipe.contrast, 0.2);
      expect(loadedOrig.label, 'Keeper');
      expect(loadedOrig.rating, 4);
      expect(loadedOrig.flag, isTrue);
      expect(loadedOrig.created.toUtc(), orig.created);

      final loadedVc = loaded[vc.entryId]!;
      expect(loadedVc.entryId, vc.entryId);
      expect(loadedVc.sourceAssetId, vc.sourceAssetId);
      expect(loadedVc.kind, CatalogEntryKind.virtualCopy);
      expect(loadedVc.recipe.temperature, 5500);
      expect(loadedVc.label, 'Warm look');
      expect(loadedVc.rating, 5);
      expect(loadedVc.flag, isFalse);
      expect(loadedVc.created.toUtc(), vc.created);
    });

    test('corrupt row (invalid kind or bad json) is skipped gracefully', () async {
      // Insert valid row
      await db.into(db.catalogEntries).insert(
            CatalogEntriesCompanion.insert(
              entryId: 'orig:good',
              sourceAssetId: 'good',
              kind: CatalogEntryKind.original.index,
              created: DateTime.now(),
              recipeJson: '{"exposure": 0.5}',
            ),
          );

      // Insert row with invalid kind enum value
      await db.into(db.catalogEntries).insert(
            CatalogEntriesCompanion.insert(
              entryId: 'orig:bad_kind',
              sourceAssetId: 'bad_kind',
              kind: 999,
              created: DateTime.now(),
              recipeJson: '{}',
            ),
          );

      // Insert row with corrupt JSON
      await db.into(db.catalogEntries).insert(
            CatalogEntriesCompanion.insert(
              entryId: 'orig:bad_json',
              sourceAssetId: 'bad_json',
              kind: CatalogEntryKind.original.index,
              created: DateTime.now(),
              recipeJson: 'not valid json {{{',
            ),
          );

      final loaded = await store.load();
      expect(loaded.length, 1);
      expect(loaded.containsKey('orig:good'), isTrue);
      expect(loaded['orig:good']!.recipe.exposure, 0.5);
    });

    test('save replaces previous entries cleanly in a transaction', () async {
      final e1 = CatalogEntry.original(
        entryId: 'orig:1',
        recipe: EditRecipe.neutral.copyWith(exposure: 1),
      );
      await store.save({e1.entryId: e1});

      expect(await store.load(), hasLength(1));

      final e2 = CatalogEntry.original(
        entryId: 'orig:2',
        recipe: EditRecipe.neutral.copyWith(exposure: 2),
      );
      await store.save({e2.entryId: e2});

      final loaded = await store.load();
      expect(loaded.length, 1);
      expect(loaded.containsKey('orig:1'), isFalse);
      expect(loaded.containsKey('orig:2'), isTrue);
    });
  });

  group('LibraryCatalog with Drift store integration', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          catalogDbProvider.overrideWithValue(db),
          libraryCatalogStoreProvider.overrideWithValue(store),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('syncRecipe + flush writes to SQLite and survives reload', () async {
      final catalog = container.read(libraryCatalogProvider.notifier);
      catalog.syncRecipe(
        originalEntryId('img100'),
        EditRecipe.neutral.copyWith(exposure: 1.75, clarity: 0.3),
      );
      await catalog.flush();

      // Check rows in sqlite
      final rows = await db.select(db.catalogEntries).get();
      expect(rows, hasLength(1));
      expect(rows.first.entryId, originalEntryId('img100'));

      // Check reload in a new container
      final relaunch = ProviderContainer(
        overrides: [
          catalogDbProvider.overrideWithValue(db),
          libraryCatalogStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(relaunch.dispose);

      await relaunch.read(libraryCatalogProvider.notifier).hydrate();
      final entries = relaunch.read(libraryCatalogProvider);
      expect(entries[originalEntryId('img100')]!.recipe.exposure, 1.75);
      expect(entries[originalEntryId('img100')]!.recipe.clarity, 0.3);

      final liveRecipes = relaunch.read(recipeStoreProvider);
      expect(liveRecipes[originalEntryId('img100')]!.exposure, 1.75);
    });

    test('virtual copy lifecycle and ratings are persisted in SQLite', () async {
      final catalog = container.read(libraryCatalogProvider.notifier);
      catalog.setRating(originalEntryId('base'), 5);
      catalog.setFlag(originalEntryId('base'), true);

      final vc = catalog.createVirtualCopy(
        sourceAssetId: 'base',
        recipe: EditRecipe.neutral.copyWith(contrast: 0.8),
      );
      catalog.rename(vc.entryId, 'High Contrast B&W');

      await catalog.flush();

      final loaded = await store.load();
      expect(loaded, hasLength(2));
      expect(loaded[originalEntryId('base')]!.rating, 5);
      expect(loaded[originalEntryId('base')]!.flag, isTrue);
      expect(loaded[vc.entryId]!.label, 'High Contrast B&W');
      expect(loaded[vc.entryId]!.recipe.contrast, 0.8);
    });
  });
}
