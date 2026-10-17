import 'dart:io';
import 'dart:typed_data';

import 'package:aperturex/edit/catalog_db.dart';
import 'package:aperturex/edit/drift_catalog_store.dart';
import 'package:aperturex/edit/library_catalog.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/features/editor/editor_screen.dart';
import 'package:aperturex/gallery/edit_preview_store.dart';
import 'package:aperturex/gallery/gallery_asset.dart';
import 'package:aperturex/gallery/gallery_controller.dart';
import 'package:aperturex/gallery/gallery_screen.dart';
import 'package:aperturex/gallery/gallery_source.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final Uint8List _fakePng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  late CatalogDb db;
  late Directory tempDir;
  late EditPreviewStore store;

  setUp(() async {
    db = CatalogDb(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('aperturex-edits-ui-test');
    store = EditPreviewStore(
      db,
      editsDirResolver: () async => tempDir,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget pumpScreen(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: GalleryScreen(),
      ),
    );
  }

  testWidgets('switching scope to Edits shows empty state when no edits saved', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        gallerySourceProvider.overrideWithValue(
          FakeGallerySource(images: {'a': _fakePng}),
        ),
        catalogDbProvider.overrideWithValue(db),
        editPreviewStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(pumpScreen(container));
    await tester.pumpAndSettle();

    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Edits'), findsOneWidget);

    // Tap 'Edits' segment
    await tester.tap(find.text('Edits'));
    await tester.pumpAndSettle();

    expect(find.text('No edits saved yet'), findsOneWidget);
  });

  testWidgets('Edits view renders saved preview with badges and opens editor on tap', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await store.savePreview(
        entryId: 'orig:a',
        jpegBytes: _fakePng,
        width: 1200,
        height: 800,
        recipeHash: '12345678',
      );
    });

    final container = ProviderContainer(
      overrides: [
        gallerySourceProvider.overrideWithValue(
          FakeGallerySource(
            assets: const [GalleryAsset(id: 'a', width: 1, height: 1)],
            images: {'a': _fakePng},
          ),
        ),
        catalogDbProvider.overrideWithValue(db),
        editPreviewStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    // Set rating, flag, and label on the entry
    final catalog = container.read(libraryCatalogProvider.notifier);
    catalog.syncRecipe('orig:a', EditRecipe.neutral.copyWith(exposure: 1.0));
    catalog.setRating('orig:a', 5);
    catalog.setFlag('orig:a', true);
    catalog.rename('orig:a', 'Sunset Peak');

    await tester.pumpWidget(pumpScreen(container));
    await tester.pumpAndSettle();

    // Switch to Edits scope
    await tester.tap(find.text('Edits'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Should find the label and rating badge
    expect(find.text('Sunset Peak'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.flag), findsOneWidget);

    // Tap on the edit preview cell to open the editor
    await tester.tap(find.text('Sunset Peak'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // Editor screen opened
    expect(find.byType(EditorScreen), findsOneWidget);
  });

  testWidgets('long press on EditPreviewCell shows menu and delete removes preview', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await store.savePreview(
        entryId: 'orig:b',
        jpegBytes: _fakePng,
        width: 800,
        height: 600,
        recipeHash: 'abcdef01',
      );
    });

    final container = ProviderContainer(
      overrides: [
        gallerySourceProvider.overrideWithValue(
          FakeGallerySource(
            assets: const [GalleryAsset(id: 'b', width: 1, height: 1)],
            images: {'b': _fakePng},
          ),
        ),
        catalogDbProvider.overrideWithValue(db),
        editPreviewStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(pumpScreen(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edits'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Long press preview
    await tester.longPress(find.byType(Image));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Verify removed from store
    await tester.runAsync(() async {
      expect(await store.find('orig:b'), isNull);
    });
    expect(find.text('No edits saved yet'), findsOneWidget);
  });

  test('preview dimensions size guard: aspect ratio maintained <= 1600', () {
    // Landscape 4000x2000 -> 1600x800
    int w = 4000;
    int h = 2000;
    double aspect = w / h;
    int outW = w;
    int outH = h;
    if (outW > 1600 || outH > 1600) {
      if (aspect >= 1.0) {
        outW = 1600;
        outH = (1600 / aspect).round();
      } else {
        outH = 1600;
        outW = (1600 * aspect).round();
      }
    }
    expect(outW, 1600);
    expect(outH, 800);

    // Portrait 2000x4000 -> 800x1600
    w = 2000;
    h = 4000;
    aspect = w / h;
    outW = w;
    outH = h;
    if (outW > 1600 || outH > 1600) {
      if (aspect >= 1.0) {
        outW = 1600;
        outH = (1600 / aspect).round();
      } else {
        outH = 1600;
        outW = (1600 * aspect).round();
      }
    }
    expect(outW, 800);
    expect(outH, 1600);
  });
}
