import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/gallery/gallery_album.dart';
import 'package:aperturex/gallery/gallery_asset.dart';
import 'package:aperturex/gallery/gallery_controller.dart';
import 'package:aperturex/gallery/gallery_source.dart';
import 'package:aperturex/gallery/photo_navigator.dart';
import 'package:aperturex/gallery/thumbnail_memory_cache.dart';
import 'package:aperturex/ui/common/filmstrip.dart';

class FakeGallerySource implements GallerySource {
  FakeGallerySource({required this.assets});
  final List<GalleryAsset> assets;

  @override
  final ThumbnailMemoryCache thumbnailCache = ThumbnailMemoryCache();

  @override
  Future<GalleryPermission> requestPermission() async => GalleryPermission.granted;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<List<GalleryAlbum>> listAlbums() async => const [];

  @override
  Future<List<GalleryAsset>> listImages({int limit = 500, String? albumId}) async =>
      assets.take(limit).toList();

  @override
  Future<Uint8List> loadImage(String id) async => Uint8List(0);

  @override
  Future<Uint8List> loadPreview(String id, {int maxDim = 1600}) async => Uint8List(0);

  @override
  Future<Uint8List> loadThumbnail(String id, {int size = 256}) async => Uint8List(0);
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    container = ProviderContainer(
      overrides: [
        gallerySourceProvider.overrideWithValue(
          FakeGallerySource(
            assets: const [
              GalleryAsset(id: 'a', width: 100, height: 100),
              GalleryAsset(id: 'b', width: 100, height: 100),
              GalleryAsset(id: 'c', width: 100, height: 100),
            ],
          ),
        ),
      ],
    );
    await container.read(galleryControllerProvider.notifier).load();
  });

  tearDown(() => container.dispose());

  Widget harness() => UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Filmstrip()),
        ),
      );

  group('Filmstrip', () {
    testWidgets('renders thumbnail count indicator', (tester) async {
      await tester.pumpWidget(harness());
      expect(find.text('3 photos'), findsOneWidget);
    });

    testWidgets('shows current photo highlighted', (tester) async {
      await tester.pumpWidget(harness());
      // First photo ('a') should be highlighted initially
      final thumbnail = find.byKey(const Key('filmstrip-thumbnail-a'));
      expect(thumbnail, findsOneWidget);
      // The Container is a descendant of the GestureDetector
      final container = find.descendant(
        of: thumbnail,
        matching: find.byType(Container),
      );
      expect(container, findsOneWidget);
      expect(
        tester.widget<Container>(container.first).decoration,
        isNotNull,
      );
    });

    testWidgets('tapping a thumbnail switches current photo', (tester) async {
      await tester.pumpWidget(harness());

      final nav = container.read(photoNavigatorProvider.notifier);
      expect(nav.state.currentIndex, 0);

      await tester.tap(find.byKey(const Key('filmstrip-thumbnail-c')));
      await tester.pumpAndSettle();

      expect(nav.state.currentIndex, 2);
      expect(nav.state.currentAsset?.id, 'c');
    });

    testWidgets('next button advances to next photo', (tester) async {
      await tester.pumpWidget(harness());

      final nav = container.read(photoNavigatorProvider.notifier);
      expect(nav.state.currentIndex, 0);

      await tester.tap(find.byKey(const Key('filmstrip-next')));
      await tester.pumpAndSettle();

      expect(nav.state.currentIndex, 1);
      expect(nav.state.currentAsset?.id, 'b');
    });

    testWidgets('previous button goes to previous photo', (tester) async {
      await tester.pumpWidget(harness());

      final nav = container.read(photoNavigatorProvider.notifier);
      nav.goNext(); // -> b
      await tester.pump();
      nav.goNext(); // -> c
      await tester.pump();
      expect(nav.state.currentIndex, 2);

      await tester.tap(find.byKey(const Key('filmstrip-previous')));
      await tester.pumpAndSettle();

      expect(nav.state.currentIndex, 1);
      expect(nav.state.currentAsset?.id, 'b');
    });

    testWidgets('next button is disabled at last photo', (tester) async {
      await tester.pumpWidget(harness());

      final nav = container.read(photoNavigatorProvider.notifier);
      nav.goNext();
      await tester.pump();
      nav.goNext(); // at index 2 (last)
      await tester.pump();

      final nextButton = tester.widget<IconButton>(
        find.byKey(const Key('filmstrip-next')),
      );
      expect(nextButton.onPressed, isNull);
    });

    testWidgets('previous button is disabled at first photo', (tester) async {
      await tester.pumpWidget(harness());

      final previousButton = tester.widget<IconButton>(
        find.byKey(const Key('filmstrip-previous')),
      );
      expect(previousButton.onPressed, isNull);
    });
  });
}
