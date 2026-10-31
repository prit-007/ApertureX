import 'dart:typed_data';

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
  group('isRawAsset mobile and desktop RAW detection (ISSUE-06)', () {
    test('detects all standard raw camera extensions', () {
      final extensions = [
        'dng', 'cr2', 'cr3', 'nef', 'arw', 'orf', 'rw2', 'pef', 'raf', 'raw',
      ];
      for (final ext in extensions) {
        final assetLower = GalleryAsset(
          id: 'photo_test.$ext',
          width: 100,
          height: 100,
          created: DateTime(2026, 3, 1),
        );
        final assetUpper = GalleryAsset(
          id: 'PHOTO_TEST.${ext.toUpperCase()}',
          width: 100,
          height: 100,
          modified: DateTime(2026, 3, 2),
        );
        expect(isRawAsset(assetLower), isTrue, reason: 'Failed for .$ext');
        expect(isRawAsset(assetUpper), isTrue, reason: 'Failed for .${ext.toUpperCase()}');
      }
    });

    test('detects mobile photo_manager and MediaStore raw entity hints', () {
      final mobileRawIds = [
        'content://media/external/images/media/42/raw',
        '12345/raw',
        '12345/dng',
        'media_store_123_raw_orig',
        'uuid-9876-arw-5432',
        'image/x-adobe-dng',
        'image/x-canon-cr2',
        'image/x-fuji-raf',
        'raw_camera_shot_101',
      ];
      for (final id in mobileRawIds) {
        final asset = GalleryAsset(
          id: id,
          width: 100,
          height: 100,
          created: DateTime(2026, 3, 1),
        );
        expect(isRawAsset(asset), isTrue, reason: 'Failed for mobile id: $id');
      }
    });

    test('rejects non-RAW images, substring false positives, and plain numeric IDs', () {
      final nonRawIds = [
        'photo_1.jpg',
        'photo_2.jpeg',
        'graphic.png',
        'animation.gif',
        'vector.svg',
        'straw_hat.jpg',
        'drawing_art.png',
        'crawfish_dinner.webp',
        '100234',
        '987654321',
        '',
      ];
      for (final id in nonRawIds) {
        final asset = GalleryAsset(
          id: id,
          width: 100,
          height: 100,
          created: DateTime(2026, 3, 1),
        );
        expect(isRawAsset(asset), isFalse, reason: 'Should not detect RAW for: $id');
      }
    });

    test('safely handles null latestDate without throwing', () {
      const assetNoDate = GalleryAsset(id: 'photo.dng', width: 100, height: 100);
      expect(assetNoDate.latestDate, isNull);
      expect(isRawAsset(assetNoDate), isTrue);

      const nonRawNoDate = GalleryAsset(id: 'photo.jpg', width: 100, height: 100);
      expect(isRawAsset(nonRawNoDate), isFalse);
    });
  });

  group('GalleryScreen Filter Matching & Empty State (ISSUE-06)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          gallerySourceProvider.overrideWithValue(
            FakeGallerySource(
              assets: [
                GalleryAsset(
                  id: 'photo_raw.dng',
                  width: 100,
                  height: 100,
                  created: DateTime(2026, 3, 1),
                ),
                GalleryAsset(
                  id: 'photo_jpg.jpg',
                  width: 100,
                  height: 100,
                  created: DateTime(2026, 3, 2),
                ),
              ],
              thumbnails: {
                'photo_raw.dng': _png,
                'photo_jpg.jpg': _png,
              },
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

    testWidgets('unedited photos are not filtered out by default', (tester) async {
      await pumpGallery(tester);

      // Both photos (unedited, no catalog entry) are displayed
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('RAW filter isolates unedited RAW assets', (tester) async {
      await pumpGallery(tester);

      // Tap RAW filter chip
      await tester.tap(find.byKey(const Key('filter-raw')));
      await tester.pumpAndSettle();

      // Only photo_raw.dng is shown
      expect(find.byType(Image), findsOneWidget);
      expect(find.byKey(const Key('raw-badge-photo_raw.dng')), findsOneWidget);
    });

    testWidgets('renders _EmptyFilterCard when all photos filtered out, and Clear Filters restores items', (
      tester,
    ) async {
      await pumpGallery(tester);

      // Initially 2 photos
      expect(find.byType(Image), findsNWidgets(2));

      // Filter by 3+ ★ stars (neither photo has any rating)
      await tester.tap(find.byKey(const Key('filter-rating-3')));
      await tester.pumpAndSettle();

      // 0 photos match: clean _EmptyFilterCard is rendered
      expect(find.byType(Image), findsNothing);
      expect(find.byKey(const Key('empty-filter-card')), findsOneWidget);
      expect(find.text('No photos match the selected filter'), findsOneWidget);
      expect(find.byIcon(Icons.filter_alt_off_outlined), findsOneWidget);
      expect(find.byKey(const Key('clear-filters-button')), findsOneWidget);

      // Tap Clear Filters button in _EmptyFilterCard
      await tester.tap(find.byKey(const Key('clear-filters-button')));
      await tester.pumpAndSettle();

      // Both photos restored!
      expect(find.byType(Image), findsNWidgets(2));
      expect(find.byKey(const Key('empty-filter-card')), findsNothing);
    });
  });
}
