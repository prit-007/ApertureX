import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aperturex/edit/catalog_db.dart';
import 'package:aperturex/edit/drift_catalog_store.dart';
import 'package:aperturex/edit/library_catalog.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/features/editor/editor_screen.dart';
import 'package:aperturex/gallery/edit_preview_store.dart';
import 'package:aperturex/gallery/folder_gallery_source.dart';
import 'package:aperturex/gallery/gallery_controller.dart';
import 'package:aperturex/gallery/gallery_screen.dart';
import 'package:aperturex/gallery/gallery_source.dart';
import 'package:drift/native.dart';

final Uint8List _pngBytes = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  late Directory tempDir;
  late Directory emptyDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('aperturex-folder-ui');
    File('${tempDir.path}/photo.png').writeAsBytesSync(_pngBytes);
    // Pre-created here (real zone): widget-test bodies run in fake time, so
    // awaiting directory creation inside a test would never finish.
    emptyDir = await Directory.systemTemp.createTemp('aperturex-empty');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    if (await emptyDir.exists()) {
      await emptyDir.delete(recursive: true);
    }
  });

  /// Folder source with an injected picker; the thumb cache is pre-seeded so
  /// grid cells never wait on decode I/O inside the fake-async test zone.
  FolderGallerySource folderSource({Future<String?> Function()? pick}) {
    final source = FolderGallerySource(
      pickDirectory: pick ?? () async => tempDir.path,
    );
    source.thumbnailCache.put('photo.png', _pngBytes);
    return source;
  }

  /// Real filesystem futures (directory scan, reads) cannot finish while the
  /// widget-test zone fakes time — bridge one real event-loop turn, then
  /// settle (same pattern edits_gallery_test uses for preview I/O).
  /// Real filesystem futures (directory scan, stat, reads) only finish while
  /// the event loop actually turns — `pumpAndSettle` alone starves them, and
  /// a lone `runAsync` doesn't drain the fake zone afterwards. So: alternate
  /// a real turn with a pump until [galleryControllerProvider]'s load is
  /// done, then settle. Same "bridge real time" idea as edits_gallery_test.
  Future<void> letIo(
    WidgetTester tester, {
    ProviderContainer? container,
  }) async {
    await tester.pump();
    for (var i = 0; i < 50; i++) {
      if (container != null &&
          !container.read(galleryControllerProvider).loading) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> pumpGallery(
    WidgetTester tester,
    GallerySource source, {
    List<Override> extraOverrides = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [
        gallerySourceProvider.overrideWithValue(source),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GalleryScreen()),
      ),
    );
    await letIo(tester, container: container);
    return container;
  }

  testWidgets('no root → “Choose a photo folder”; picking reveals the grid', (
    tester,
  ) async {
    var picks = 0;
    final source = folderSource(
      pick: () async {
        picks++;
        return tempDir.path;
      },
    );

    await pumpGallery(tester, source);
    expect(find.text('Choose a photo folder'), findsOneWidget);
    expect(find.text('Choose a folder'), findsOneWidget);

    await tester.tap(find.text('Choose a folder'));
    await letIo(tester);

    expect(picks, 1);
    expect(find.text('Choose a photo folder'), findsNothing);
    expect(find.byType(GalleryThumbnail), findsOneWidget);
  });

  testWidgets('a cancelled pick keeps the CTA instead of showing an error', (
    tester,
  ) async {
    var picks = 0;
    final source = folderSource(
      pick: () async {
        picks++;
        return null; // user dismissed the dialog
      },
    );

    await pumpGallery(tester, source);
    await tester.tap(find.text('Choose a folder'));
    await tester.pumpAndSettle();

    expect(picks, 1);
    expect(find.text('Choose a photo folder'), findsOneWidget);
    expect(find.text('Can’t read your gallery'), findsNothing);
  });

  testWidgets('a persisted root skips the CTA on the next launch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({folderRootPrefsKey: tempDir.path});
    await pumpGallery(tester, folderSource());

    expect(find.text('Choose a photo folder'), findsNothing);
    expect(find.byType(GalleryThumbnail), findsOneWidget);
  });

  testWidgets('root set but folder empty → shows the path + a re-pick', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({folderRootPrefsKey: emptyDir.path});

    await pumpGallery(tester, folderSource());

    expect(find.text('No photos in this folder'), findsOneWidget);
    expect(
      find.textContaining(emptyDir.path),
      findsOneWidget,
      reason: 'the root path must be visible so the user can re-pick',
    );
    expect(find.text('Choose a folder'), findsOneWidget);
  });

  testWidgets('virtual copy round-trips on a folder-relative id', (
    tester,
  ) async {
    final db = CatalogDb(NativeDatabase.memory());
    addTearDown(() => db.close());
    final source = folderSource();
    // Skip the CTA: this test starts from an already-chosen root.
    await source.setRoot(tempDir.path);

    final container = await pumpGallery(
      tester,
      source,
      extraOverrides: [catalogDbProvider.overrideWithValue(db)],
    );

    container
        .read(libraryCatalogProvider.notifier)
        .createVirtualCopy(
          sourceAssetId: 'photo.png',
          recipe: EditRecipe.neutral.copyWith(exposure: 1.2),
        );
    // Mount the new cell, then step past its 40 ms stagger delay — settle
    // alone exits while that timer is still pending (no frames scheduled).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    // Original + virtual copy both resolve through the folder source.
    expect(find.byType(GalleryThumbnail), findsNWidgets(2));
    expect(find.text('VC'), findsOneWidget);
  });

  testWidgets('Edits gallery opens the editor on a folder-relative id', (
    tester,
  ) async {
    final db = CatalogDb(NativeDatabase.memory());
    final editsDir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('aperturex-edits'),
    ))!;
    final store = EditPreviewStore(db, editsDirResolver: () async => editsDir);
    addTearDown(() async {
      await db.close();
      if (await editsDir.exists()) await editsDir.delete(recursive: true);
    });

    final source = folderSource();
    // Already-chosen root, as a returning desktop user would have (#103) —
    // the editor resolves preview bytes through it after the tap below.
    await source.setRoot(tempDir.path);
    final container = await pumpGallery(
      tester,
      source,
      extraOverrides: [
        catalogDbProvider.overrideWithValue(db),
        editPreviewStoreProvider.overrideWithValue(store),
      ],
    );

    // Saved edit preview + non-neutral recipe, exactly like the Fake-backed
    // edits test — except the asset id is a bare folder file name (#103).
    await tester.runAsync(() async {
      await store.savePreview(
        entryId: 'orig:photo.png',
        jpegBytes: _pngBytes,
        width: 1,
        height: 1,
        recipeHash: 'deadbeef',
      );
    });
    container
        .read(libraryCatalogProvider.notifier)
        .syncRecipe(
          'orig:photo.png',
          EditRecipe.neutral.copyWith(exposure: 1.0),
        );
    container
        .read(libraryCatalogProvider.notifier)
        .rename('orig:photo.png', 'Folder Sunset');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edits'));
    // The edits scope lists preview files — bridge real turns for it too
    // (no container: the gallery is already idle).
    await letIo(tester);
    expect(find.text('Folder Sunset'), findsOneWidget);

    await tester.tap(find.text('Folder Sunset'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(EditorScreen), findsOneWidget);
  });
}
