import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/library_catalog.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/edit/recipe_store.dart';
import 'package:aperturex/edit/settings_clipboard.dart';
import 'package:aperturex/features/editor/editor_screen.dart';
import 'package:aperturex/gallery/gallery_asset.dart';
import 'package:aperturex/gallery/gallery_controller.dart';
import 'package:aperturex/gallery/gallery_screen.dart';
import 'package:aperturex/gallery/gallery_source.dart';

/// A valid 1×1 PNG so `Image.memory` decodes in tests.
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Records thumbnail loads so tests can prove virtual-copy cells share the
/// source photo's pixels instead of decoding per-copy data.
class _RecordingSource extends FakeGallerySource {
  _RecordingSource({required super.assets, required super.thumbnails});

  final List<String> thumbnailRequests = [];

  @override
  Future<Uint8List> loadThumbnail(String id, {int size = 256}) {
    thumbnailRequests.add(id);
    return super.loadThumbnail(id, size: size);
  }
}

void main() {
  late _RecordingSource source;
  late ProviderContainer container;

  setUp(() {
    source = _RecordingSource(
      assets: const [
        GalleryAsset(id: 'a', width: 1, height: 1),
        GalleryAsset(id: 'b', width: 1, height: 1),
      ],
      thumbnails: {'a': _png, 'b': _png},
    );
    container = ProviderContainer(
      overrides: [gallerySourceProvider.overrideWithValue(source)],
    );
  });
  tearDown(() => container.dispose());

  Future<void> pumpGallery(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GalleryScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  CatalogEntry makeCopy({String assetId = 'a', EditRecipe? recipe}) => container
      .read(libraryCatalogProvider.notifier)
      .createVirtualCopy(
        sourceAssetId: assetId,
        recipe: recipe ?? EditRecipe.neutral,
      );

  testWidgets('the selection bar creates a virtual copy per selected photo', (
    tester,
  ) async {
    container
        .read(recipeStoreProvider.notifier)
        .put(originalEntryId('a'), EditRecipe.neutral.copyWith(exposure: 1.2));

    await pumpGallery(tester);
    await tester.longPress(find.byType(Image).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('virtual-copy-action')));
    await tester.pumpAndSettle();

    final entries = container.read(libraryCatalogProvider);
    final copies = entries.values
        .where((e) => e.kind == CatalogEntryKind.virtualCopy)
        .toList();
    expect(copies, hasLength(1));
    expect(copies.single.sourceAssetId, 'a');
    // The copy snapshots the original's current recipe.
    expect(copies.single.recipe.exposure, 1.2);
    // Selection mode exits after the action.
    expect(find.text('2 selected'), findsNothing);
    expect(find.text('Recent'), findsOneWidget);
  });

  testWidgets('virtual-copy cells render under the original and share its '
      'thumbnail', (tester) async {
    final vc = makeCopy();

    await pumpGallery(tester);

    // Badge + copy-count chip are on screen.
    expect(find.byKey(Key('vc-badge-${vc.entryId}')), findsOneWidget);
    expect(find.byKey(const Key('copy-count-a')), findsOneWidget);
    expect(find.text('×1'), findsOneWidget);

    // Every thumbnail request is for a raw source asset — copies never decode
    // their own pixels.
    expect(source.thumbnailRequests, isNotEmpty);
    expect(
      source.thumbnailRequests.every((id) => id == 'a' || id == 'b'),
      isTrue,
    );
  });

  testWidgets('tapping a virtual-copy cell edits the copy, not the original', (
    tester,
  ) async {
    final vc = makeCopy(recipe: EditRecipe.neutral.copyWith(exposure: 0.7));

    await pumpGallery(tester);
    await tester.tap(find.byKey(Key('vc-badge-${vc.entryId}')));
    // The editor runs indeterminate animations (decode progress), so settle
    // with fixed pumps like the editor tests do.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(EditorScreen), findsOneWidget);
    expect(container.read(recipeControllerProvider).recipe.exposure, 0.7);
    // The original keeps its own (neutral) recipe.
    expect(
      container.read(recipeStoreProvider).containsKey(originalEntryId('a')),
      isFalse,
    );
  });

  testWidgets('long-pressing a copy offers rename and delete', (tester) async {
    final vc = makeCopy();
    await pumpGallery(tester);

    await tester.longPress(find.byKey(Key('vc-badge-${vc.entryId}')));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'B&W try');
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();

    expect(
      container.read(libraryCatalogProvider)[vc.entryId]!.label,
      'B&W try',
    );

    // Delete removes only the copy's cell.
    await tester.longPress(find.byKey(Key('vc-badge-${vc.entryId}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('vc-badge-${vc.entryId}')), findsNothing);
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('paste and the edited badge key off the original entry', (
    tester,
  ) async {
    container
        .read(settingsClipboardProvider.notifier)
        .copy(EditRecipe.neutral.copyWith(exposure: 1.5));

    await pumpGallery(tester);
    await tester.longPress(find.byType(Image).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();

    final store = container.read(recipeStoreProvider);
    expect(store[originalEntryId('a')]!.exposure, 1.5);
    expect(store.containsKey('a'), isFalse);
    expect(find.byIcon(Icons.tune), findsOneWidget);
  });
}
