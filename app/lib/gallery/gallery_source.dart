import 'dart:typed_data';

import 'gallery_asset.dart';

/// Read access to the device gallery, behind an interface so the app and tests
/// never depend on a platform plugin directly.
abstract class GallerySource {
  /// Most-recent image assets first.
  Future<List<GalleryAsset>> listImages({int limit = 200});

  /// Full JPEG bytes for editing.
  Future<Uint8List> loadImage(String id);

  /// Small thumbnail bytes for the grid.
  Future<Uint8List> loadThumbnail(String id, {int size = 256});
}

/// In-memory [GallerySource] for tests and previews.
class FakeGallerySource implements GallerySource {
  FakeGallerySource({
    List<GalleryAsset>? assets,
    Map<String, Uint8List>? images,
    Map<String, Uint8List>? thumbnails,
  }) : assets = assets ?? const [],
       _images = images ?? const {},
       _thumbs = thumbnails ?? const {};

  final List<GalleryAsset> assets;
  final Map<String, Uint8List> _images;
  final Map<String, Uint8List> _thumbs;

  @override
  Future<List<GalleryAsset>> listImages({int limit = 200}) async =>
      assets.take(limit).toList();

  @override
  Future<Uint8List> loadImage(String id) async =>
      _images[id] ?? Uint8List(0);

  @override
  Future<Uint8List> loadThumbnail(String id, {int size = 256}) async =>
      _thumbs[id] ?? _images[id] ?? Uint8List(0);
}
