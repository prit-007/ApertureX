import 'dart:io';
import 'dart:typed_data';
import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:aperturex/edit/catalog_db.dart';
import 'package:aperturex/edit/drift_catalog_store.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/recipe_store.dart';
import 'package:aperturex/gallery/edit_preview_store.dart';
import 'package:aperturex/gallery/edited_versions_screen.dart';
import 'package:aperturex/gallery/staggered_photo_grid.dart';
import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestRecipeStore extends RecipeStore {
  _TestRecipeStore(this._initial);
  final Map<String, EditRecipe> _initial;
  @override
  Map<String, EditRecipe> build() => _initial;
}

void main() {
  late CatalogDb db;
  late EditPreviewStore store;
  late Directory tempDir;

  setUp(() async {
    db = CatalogDb(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('aperturex_edits_test');
    store = EditPreviewStore(db, editsDirResolver: () async => tempDir);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('EditedVersionsScreen renders empty state when no edits exist', (tester) async {
    final container = ProviderContainer(
      overrides: [
        catalogDbProvider.overrideWithValue(db),
        editPreviewStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditedVersionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edited Versions'), findsOneWidget);
    expect(find.text('No edited versions yet'), findsOneWidget);
  });

  testWidgets('EditedVersionsScreen displays cards for edited images with recipe chips', (tester) async {
    final recipe = EditRecipe.neutral.copyWith(
      exposure: 1.2,
      blurEnabled: true,
      layers: const [AdjustmentLayer(maskKind: MaskKind.subject)],
    );

    await tester.runAsync(() async {
      await store.savePreview(
        entryId: 'photo_1',
        jpegBytes: Uint8List(64),
        width: 100,
        height: 100,
        recipeHash: computeRecipeHash(recipe),
      );
    });

    final container = ProviderContainer(
      overrides: [
        catalogDbProvider.overrideWithValue(db),
        editPreviewStoreProvider.overrideWithValue(store),
        recipeStoreProvider.overrideWith(() => _TestRecipeStore({'photo_1': recipe})),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditedVersionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('photo_1'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Blur'), findsOneWidget);
    expect(find.text('Masking'), findsOneWidget);
  });

  testWidgets('EditedVersionsScreen groups previews by calendar day and renders StaggeredPhotoGrid', (tester) async {
    await tester.runAsync(() async {
      await store.savePreview(
        entryId: 'today_pic',
        jpegBytes: Uint8List(64),
        width: 120,
        height: 160,
        recipeHash: 'hash1',
      );
    });

    final container = ProviderContainer(
      overrides: [
        catalogDbProvider.overrideWithValue(db),
        editPreviewStoreProvider.overrideWithValue(store),
        recipeStoreProvider.overrideWith(() => _TestRecipeStore({})),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditedVersionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('today_pic'), findsOneWidget);
    expect(find.byType(StaggeredPhotoGrid), findsOneWidget);
  });
}
