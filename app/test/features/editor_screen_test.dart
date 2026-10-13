import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tessera/features/editor/editor_screen.dart';
import 'package:tessera/gallery/gallery_asset.dart';
import 'package:tessera/gallery/gallery_controller.dart';
import 'package:tessera/gallery/gallery_source.dart';
import 'package:tessera/ui/app_shell.dart';

/// A valid 1×1 PNG (non-empty bytes so the editor proceeds to the canvas).
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  ProviderContainer containerWith({Map<String, Uint8List> images = const {}}) =>
      ProviderContainer(
        overrides: [
          gallerySourceProvider.overrideWithValue(
            FakeGallerySource(images: images),
          ),
        ],
      );

  testWidgets('shows the editor chrome (app bar + shell) for an asset', (
    tester,
  ) async {
    final container = containerWith(images: {'a': _png});
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: EditorScreen(asset: GalleryAsset(id: 'a', width: 1, height: 1)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.byTooltip('Undo'), findsOneWidget);
    expect(find.byTooltip('Redo'), findsOneWidget);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('shows a recoverable error when the image cannot be read', (
    tester,
  ) async {
    final container = containerWith(); // empty bytes for every asset
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: EditorScreen(asset: GalleryAsset(id: 'missing', width: 1, height: 1)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not open this photo'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
