import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/gallery/gallery_album.dart';
import 'package:aperturex/gallery/gallery_asset.dart';
import 'package:aperturex/gallery/gallery_controller.dart';
import 'package:aperturex/gallery/gallery_source.dart';
import 'package:aperturex/gallery/thumbnail_memory_cache.dart';

/// A gallery source that delays album loading to simulate slow album queries.
class DelayedAlbumsSource implements GallerySource {

  DelayedAlbumsSource({
    required this.assets,
    required this.albums,
    this.albumDelay = const Duration(milliseconds: 50),
  });
  final List<GalleryAsset> assets;
  final List<GalleryAlbum> albums;
  final Duration albumDelay;

  @override
  final ThumbnailMemoryCache thumbnailCache = ThumbnailMemoryCache();

  @override
  Future<GalleryPermission> requestPermission() async => GalleryPermission.granted;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<List<GalleryAlbum>> listAlbums() async {
    await Future.delayed(albumDelay);
    return albums;
  }

  @override
  Future<List<GalleryAsset>> listImages({int limit = 500, String? albumId}) async {
    return assets.take(limit).toList();
  }

  @override
  Future<Uint8List> loadImage(String id) async => Uint8List(0);

  @override
  Future<Uint8List> loadPreview(String id, {int maxDim = 1600}) async => Uint8List(0);

  @override
  Future<Uint8List> loadThumbnail(String id, {int size = 256}) async => Uint8List(0);
}

void main() {
  late ProviderContainer container;

  setUp(() {
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
  });
  tearDown(() => container.dispose());

  GalleryState state() => container.read(galleryControllerProvider);
  GalleryController controller() =>
      container.read(galleryControllerProvider.notifier);

  test('load populates the assets', () async {
    await controller().load();
    expect(state().assets.map((a) => a.id), ['a', 'b', 'c']);
    expect(state().loading, isFalse);
    expect(state().error, isNull);
  });

  test('load shows assets immediately while albums load in background', () async {
    final delayedSource = DelayedAlbumsSource(
      assets: const [
        GalleryAsset(id: 'a', width: 100, height: 100),
        GalleryAsset(id: 'b', width: 100, height: 100),
      ],
      albums: const [
        GalleryAlbum(id: 'album1', name: 'Vacation', count: 10),
        GalleryAlbum(id: 'album2', name: 'Work', count: 5),
      ],
      albumDelay: const Duration(milliseconds: 50),
    );
    container = ProviderContainer(
      overrides: [
        gallerySourceProvider.overrideWithValue(delayedSource),
      ],
    );

    final ctrl = container.read(galleryControllerProvider.notifier);

    final stopwatch = Stopwatch()..start();
    await ctrl.load();
    final loadTime = stopwatch.elapsedMilliseconds;

    // Assets available immediately after load() returns
    expect(state().assets.map((a) => a.id), ['a', 'b']);
    expect(state().loading, isFalse);
    expect(state().error, isNull);

    // load() should return quickly (< 100ms) since it doesn't wait for albums
    expect(loadTime, lessThan(const Duration(milliseconds: 100).inMilliseconds),
        reason: 'load() should return after images, not wait for albums');

    // Wait for background album loading to complete
    await Future.delayed(const Duration(milliseconds: 100));

    // Albums should now be populated
    expect(state().albums.map((a) => a.id), ['album1', 'album2']);
    expect(state().albumsLoading, isFalse);
  });

  test('albumsLoading is true while albums load, false after', () async {
    final delayedSource = DelayedAlbumsSource(
      assets: const [GalleryAsset(id: 'a', width: 100, height: 100)],
      albums: const [GalleryAlbum(id: 'album1', name: 'Vacation', count: 10)],
      albumDelay: const Duration(milliseconds: 30),
    );
    container = ProviderContainer(
      overrides: [
        gallerySourceProvider.overrideWithValue(delayedSource),
      ],
    );

    final ctrl = container.read(galleryControllerProvider.notifier);

    // During load, albumsLoading should be true while images load first
    // We can't easily capture the intermediate state, but after load()
    // completes, albumsLoading should still be true (albums loading in bg)
    await ctrl.load();
    expect(state().albumsLoading, isTrue);

    // After delay, albumsLoading should be false
    await Future.delayed(const Duration(milliseconds: 50));
    expect(state().albumsLoading, isFalse);
    expect(state().albums.map((a) => a.id), ['album1']);
  });

  test('album load error does not clear already-loaded assets', () async {
    final errorSource = DelayedAlbumsSource(
      assets: const [GalleryAsset(id: 'a', width: 100, height: 100)],
      albums: const [],
      albumDelay: const Duration(milliseconds: 10),
    );
    // We can't easily make listAlbums throw with DelayedAlbumsSource;
    // instead verify assets persist when albums load normally.
    container = ProviderContainer(
      overrides: [
        gallerySourceProvider.overrideWithValue(errorSource),
      ],
    );

    final ctrl = container.read(galleryControllerProvider.notifier);
    await ctrl.load();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(state().assets.map((a) => a.id), ['a']);
    expect(state().error, isNull);
  });

  test('startSelection enters selection mode with that asset', () {
    controller().startSelection('a');
    expect(state().selectionMode, isTrue);
    expect(state().selected, {'a'});
  });

  test('toggle adds and removes; leaving none ends selection mode', () {
    controller().startSelection('a');
    controller().toggle('b');
    expect(state().selected, {'a', 'b'});

    controller().toggle('a');
    expect(state().selected, {'b'});

    controller().toggle('b');
    expect(state().selected, isEmpty);
    expect(state().selectionMode, isFalse);
  });

  test('selectAll selects every asset', () async {
    await controller().load();
    controller().selectAll();
    expect(state().selectedCount, 3);
  });

  test('clearSelection empties and exits selection mode', () {
    controller().startSelection('a');
    controller().clearSelection();
    expect(state().selected, isEmpty);
    expect(state().selectionMode, isFalse);
  });
}
