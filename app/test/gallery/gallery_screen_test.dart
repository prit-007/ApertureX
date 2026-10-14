import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/recipe_store.dart';
import 'package:aperturex/edit/settings_clipboard.dart';
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

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        gallerySourceProvider.overrideWithValue(
          FakeGallerySource(
            assets: const [
              GalleryAsset(id: 'a', width: 1, height: 1),
              GalleryAsset(id: 'b', width: 1, height: 1),
            ],
            thumbnails: {'a': _png, 'b': _png},
          ),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: GalleryScreen()),
    ),
  );

  testWidgets('shows thumbnails and batch-pastes the clipboard recipe', (
    tester,
  ) async {
    container
        .read(settingsClipboardProvider.notifier)
        .copy(EditRecipe.neutral.copyWith(exposure: 1.5));

    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(2));

    // Long-press enters selection mode with the first photo selected.
    await tester.longPress(find.byType(Image).at(0));
    await tester.pumpAndSettle();
    // In selection mode, a tap toggles the second photo in.
    await tester.tap(find.byType(Image).at(1));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();

    final store = container.read(recipeStoreProvider);
    expect(store['a']!.exposure, 1.5);
    expect(store['b']!.exposure, 1.5);
  });
}
