import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/gallery/gallery_album.dart';
import 'package:aperturex/gallery/gallery_asset.dart';
import 'package:aperturex/gallery/gallery_controller.dart';
import 'package:aperturex/gallery/gallery_source.dart';
import 'package:aperturex/gallery/photo_navigator.dart';
import 'package:aperturex/gallery/thumbnail_memory_cache.dart';

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

  group('PhotoNavigator', () {
    test('defaults to first asset as current', () {
      final nav = container.read(photoNavigatorProvider);
      expect(nav.currentAsset?.id, 'a');
      expect(nav.currentIndex, 0);
      expect(nav.assetCount, 3);
      expect(nav.canGoPrevious, isFalse);
      expect(nav.canGoNext, isTrue);
    });

    test('goNext moves to next asset and wraps at end', () {
      final nav = container.read(photoNavigatorProvider.notifier);
      nav.goNext();
      expect(container.read(photoNavigatorProvider).currentAsset?.id, 'b');
      expect(container.read(photoNavigatorProvider).currentIndex, 1);

      nav.goNext();
      expect(container.read(photoNavigatorProvider).currentAsset?.id, 'c');
      expect(container.read(photoNavigatorProvider).currentIndex, 2);
      expect(container.read(photoNavigatorProvider).canGoNext, isFalse);

      // Wrap around
      nav.goNext();
      expect(container.read(photoNavigatorProvider).currentAsset?.id, 'a');
      expect(container.read(photoNavigatorProvider).currentIndex, 0);
    });

    test('goPrevious moves to previous asset and wraps at start', () {
      final nav = container.read(photoNavigatorProvider.notifier);
      nav.goNext(); // -> b
      nav.goNext(); // -> c

      nav.goPrevious();
      expect(container.read(photoNavigatorProvider).currentAsset?.id, 'b');
      expect(container.read(photoNavigatorProvider).currentIndex, 1);

      nav.goPrevious();
      nav.goPrevious();
      expect(container.read(photoNavigatorProvider).currentAsset?.id, 'c');
      expect(container.read(photoNavigatorProvider).currentIndex, 2);
      expect(container.read(photoNavigatorProvider).canGoPrevious, isTrue);

      // Wrap around
      nav.goPrevious();
      expect(container.read(photoNavigatorProvider).currentAsset?.id, 'b');
      expect(container.read(photoNavigatorProvider).currentIndex, 1);
    });

    test('jumpTo sets a specific asset by index', () {
      final nav = container.read(photoNavigatorProvider.notifier);
      nav.jumpTo(2);
      expect(container.read(photoNavigatorProvider).currentAsset?.id, 'c');
      expect(container.read(photoNavigatorProvider).currentIndex, 2);

      nav.jumpTo(0);
      expect(container.read(photoNavigatorProvider).currentAsset?.id, 'a');
      expect(container.read(photoNavigatorProvider).currentIndex, 0);
    });

    test('jumpTo ignores out-of-range indices', () {
      final nav = container.read(photoNavigatorProvider.notifier);
      nav.jumpTo(5);
      expect(container.read(photoNavigatorProvider).currentIndex, 0);
      nav.jumpTo(-1);
      expect(container.read(photoNavigatorProvider).currentIndex, 0);
    });

    test('setCurrentAsset updates index and canGo flags', () {
      final nav = container.read(photoNavigatorProvider.notifier);
      nav.setCurrentAsset(const GalleryAsset(id: 'c', width: 100, height: 100));
      expect(container.read(photoNavigatorProvider).currentIndex, 2);
      expect(container.read(photoNavigatorProvider).canGoNext, isFalse);
      expect(container.read(photoNavigatorProvider).canGoPrevious, isTrue);
    });

    test('with single asset, both canGoPrevious and canGoNext are false', () async {
      container = ProviderContainer(
        overrides: [
          gallerySourceProvider.overrideWithValue(
            FakeGallerySource(
              assets: const [GalleryAsset(id: 'only', width: 100, height: 100)],
            ),
          ),
        ],
      );
      await container.read(galleryControllerProvider.notifier).load();
      final nav = container.read(photoNavigatorProvider);
      expect(nav.canGoPrevious, isFalse);
      expect(nav.canGoNext, isFalse);
    });

    test('with no assets, currentAsset is null and canGo flags are false', () async {
      container = ProviderContainer(
        overrides: [
          gallerySourceProvider.overrideWithValue(
            FakeGallerySource(assets: const []),
          ),
        ],
      );
      await container.read(galleryControllerProvider.notifier).load();
      final nav = container.read(photoNavigatorProvider);
      expect(nav.currentAsset, isNull);
      expect(nav.currentIndex, -1);
      expect(nav.assetCount, 0);
      expect(nav.canGoPrevious, isFalse);
      expect(nav.canGoNext, isFalse);
    });
  });
}
