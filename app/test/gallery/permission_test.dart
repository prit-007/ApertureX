import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tessera/gallery/gallery_asset.dart';
import 'package:tessera/gallery/gallery_controller.dart';
import 'package:tessera/gallery/gallery_screen.dart';
import 'package:tessera/gallery/gallery_source.dart';

final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  Future<void> pump(WidgetTester tester, GallerySource source) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: ProviderContainer(
        overrides: [gallerySourceProvider.overrideWithValue(source)],
      ),
      child: const MaterialApp(home: GalleryScreen()),
    ),
  );

  testWidgets('asks for access and shows a rationale when denied', (
    tester,
  ) async {
    await pump(
      tester,
      FakeGallerySource(permission: GalleryPermission.denied),
    );
    await tester.pumpAndSettle();

    expect(find.text('ApertureX needs your photos'), findsOneWidget);
    expect(find.text('Allow access'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('re-requesting after a denial loads the library', (
    tester,
  ) async {
    final source = FakeGallerySource(
      assets: const [GalleryAsset(id: 'a', width: 1, height: 1)],
      thumbnails: {'a': _png},
      permissionSequence: [
        GalleryPermission.denied,
        GalleryPermission.granted,
      ],
    );
    await pump(tester, source);
    await tester.pumpAndSettle();
    expect(find.text('ApertureX needs your photos'), findsOneWidget);

    await tester.tap(find.text('Allow access'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('open settings delegates to the source', (tester) async {
    final source = FakeGallerySource(permission: GalleryPermission.denied);
    await pump(tester, source);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(source.openedSettings, isTrue);
  });
}
