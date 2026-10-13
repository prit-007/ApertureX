import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/gallery/gallery_asset.dart';
import 'package:tessera/gallery/gallery_controller.dart';
import 'package:tessera/gallery/gallery_source.dart';

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
