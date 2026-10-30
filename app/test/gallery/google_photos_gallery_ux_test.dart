import 'dart:typed_data';

import 'package:aperturex/edit/library_catalog.dart';
import 'package:aperturex/gallery/gallery_album.dart';
import 'package:aperturex/gallery/gallery_asset.dart';
import 'package:aperturex/gallery/gallery_controller.dart';
import 'package:aperturex/gallery/gallery_screen.dart';
import 'package:aperturex/gallery/gallery_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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
              GalleryAsset(id: 'photo_1.jpg', width: 1, height: 1),
              GalleryAsset(id: 'photo_2.dng', width: 1, height: 1),
            ],
            albums: const [
              GalleryAlbum(
                id: 'alb_long',
                name: 'Summer Vacation In Northern Norway 2026 With Family And Friends',
                count: 1,
              ),
            ],
            assetsByAlbum: const {
              'alb_long': [GalleryAsset(id: 'photo_2.dng', width: 1, height: 1)],
            },
            thumbnails: {'photo_1.jpg': _png, 'photo_2.dng': _png},
          ),
        ),
      ],
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

  testWidgets('Album title handles long names with ellipsis and constraints', (
    tester,
  ) async {
    await pumpGallery(tester);

    // Initial album is Recent
    expect(find.text('Recent'), findsOneWidget);

    // Switch to long album name
    await container.read(galleryControllerProvider.notifier).selectAlbum('alb_long');
    await tester.pumpAndSettle();

    final albumText = tester.widget<Text>(
      find.text('Summer Vacation In Northern Norway 2026 With Family And Friends'),
    );
    expect(albumText.maxLines, 1);
    expect(albumText.overflow, TextOverflow.ellipsis);
  });

  testWidgets('Album sheet displays albums with covers, photo counts and ellipses', (
    tester,
  ) async {
    await pumpGallery(tester);

    // Tap album dropdown
    await tester.tap(find.text('Recent'));
    await tester.pumpAndSettle();

    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Recent & All Photos'), findsOneWidget);
    expect(
      find.text('Summer Vacation In Northern Norway 2026 With Family And Friends'),
      findsOneWidget,
    );

    final itemTitle = tester.widget<Text>(
      find.text('Summer Vacation In Northern Norway 2026 With Family And Friends'),
    );
    expect(itemTitle.maxLines, 1);
    expect(itemTitle.overflow, TextOverflow.ellipsis);

    // Select album
    await tester.tap(
      find.text('Summer Vacation In Northern Norway 2026 With Family And Friends'),
    );
    await tester.pumpAndSettle();

    expect(container.read(galleryControllerProvider).selectedAlbumId, 'alb_long');
  });

  testWidgets('RAW badge is displayed on RAW photos', (tester) async {
    await pumpGallery(tester);

    // photo_2.dng is RAW, so RAW badge is rendered
    expect(find.byKey(const Key('raw-badge-photo_2.dng')), findsOneWidget);
  });

  testWidgets('Grid density toggle switches between comfort and compact grid', (
    tester,
  ) async {
    await pumpGallery(tester);

    final densityButton = find.byTooltip('Compact grid');
    expect(densityButton, findsOneWidget);

    await tester.tap(densityButton);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Comfort grid'), findsOneWidget);
  });

  testWidgets('Filter bar filters by RAW and Color Labels', (tester) async {
    final catalog = container.read(libraryCatalogProvider.notifier);
    catalog.setColorLabel(originalEntryId('photo_1.jpg'), ColorLabel.red);

    await pumpGallery(tester);

    // Both photos are visible initially
    expect(find.byType(Image), findsNWidgets(2));

    // Tap RAW filter chip
    await tester.tap(find.byKey(const Key('filter-raw')));
    await tester.pumpAndSettle();

    // Only photo_2.dng is shown
    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(const Key('raw-badge-photo_2.dng')), findsOneWidget);

    // Untap RAW filter chip
    await tester.tap(find.byKey(const Key('filter-raw')));
    await tester.pumpAndSettle();

    // Tap Red Color filter chip
    await tester.tap(find.byKey(const Key('filter-color-red')));
    await tester.pumpAndSettle();

    // Only photo_1.jpg (which has Red label) is shown
    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(const Key('color-badge-photo_1.jpg')), findsOneWidget);

    // Tap All to clear filters
    await tester.tap(find.byKey(const Key('filter-all')));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('Selection mode provides Color Label and Keywords sheets', (
    tester,
  ) async {
    await pumpGallery(tester);

    // Select via Select button in AppBar
    await tester.tap(find.byTooltip('Select'));
    await tester.pumpAndSettle();

    expect(find.text('2 selected'), findsOneWidget);
    expect(find.byKey(const Key('color-label-action')), findsOneWidget);
    expect(find.byKey(const Key('keywords-action')), findsOneWidget);

    // Open color label sheet
    await tester.tap(find.byKey(const Key('color-label-action')));
    await tester.pumpAndSettle();

    expect(find.text('Set Color Label (2 selected)'), findsOneWidget);
    expect(find.byKey(const Key('color-label-chip-green')), findsOneWidget);

    // Select green
    await tester.tap(find.byKey(const Key('color-label-chip-green')));
    await tester.pumpAndSettle();

    expect(
      container.read(libraryCatalogProvider)[originalEntryId('photo_1.jpg')]?.colorLabel,
      ColorLabel.green,
    );

    // Open keywords sheet
    await tester.tap(find.byKey(const Key('keywords-action')));
    await tester.pumpAndSettle();

    expect(find.text('Manage Keywords (2 selected)'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('keyword-input')), 'Landscape');
    await tester.tap(find.byKey(const Key('add-keyword-button')));
    await tester.pumpAndSettle();

    expect(
      container.read(libraryCatalogProvider)[originalEntryId('photo_1.jpg')]?.keywords,
      contains('Landscape'),
    );
  });
}
