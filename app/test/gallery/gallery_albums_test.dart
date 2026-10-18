import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/gallery/gallery_album.dart';
import 'package:aperturex/gallery/gallery_asset.dart';
import 'package:aperturex/gallery/gallery_controller.dart';
import 'package:aperturex/gallery/gallery_source.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        gallerySourceProvider.overrideWithValue(
          FakeGallerySource(
            assets: const [
              GalleryAsset(id: 'r1', width: 1, height: 1),
              GalleryAsset(id: 'r2', width: 1, height: 1),
            ],
            albums: const [
              GalleryAlbum(id: 'alb', name: 'Camera', count: 1),
            ],
            assetsByAlbum: const {
              'alb': [GalleryAsset(id: 'c1', width: 1, height: 1)],
            },
          ),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  GalleryState state() => container.read(galleryControllerProvider);
  GalleryController controller() =>
      container.read(galleryControllerProvider.notifier);

  test('load populates albums and the recent stream', () async {
    await controller().load();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(state().assets.map((a) => a.id), ['r1', 'r2']);
    expect(state().albums.single.name, 'Camera');
    expect(state().title, 'Recent');
    expect(state().albumsLoading, isFalse);
  });

  test('selectAlbum loads that album and clears selection', () async {
    await controller().load();
    controller().startSelection('r1');

    await controller().selectAlbum('alb');

    expect(state().assets.map((a) => a.id), ['c1']);
    expect(state().selected, isEmpty);
    expect(state().selectionMode, isFalse);
    expect(state().title, 'Camera');
  });

  test('selectAlbum(null) returns to the recent stream', () async {
    await controller().load();
    await controller().selectAlbum('alb');
    await controller().selectAlbum(null);
    expect(state().assets.map((a) => a.id), ['r1', 'r2']);
    expect(state().title, 'Recent');
  });
}
