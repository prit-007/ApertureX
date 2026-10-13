import 'dart:typed_data';

import 'gallery_asset.dart';

/// Result of requesting photo-library access.
enum GalleryPermission {
  granted,
  limited,
  denied;

  /// Whether assets can be read with this permission.
  bool get canRead => this != GalleryPermission.denied;
}

/// Read access to the device gallery, behind an interface so the app and tests
/// never depend on a platform plugin directly.
abstract class GallerySource {
  /// Requests (or re-requests) photo access, returning the resulting status.
  Future<GalleryPermission> requestPermission();

  /// Opens the OS app-settings page — for a permanently-denied permission.
  Future<void> openAppSettings();

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
    GalleryPermission permission = GalleryPermission.granted,
    List<GalleryPermission>? permissionSequence,
  }) : assets = assets ?? const [],
       _images = images ?? const {},
       _thumbs = thumbnails ?? const {},
       _sequence = permissionSequence ?? [permission];

  final List<GalleryAsset> assets;
  final Map<String, Uint8List> _images;
  final Map<String, Uint8List> _thumbs;
  final List<GalleryPermission> _sequence;
  int _requests = 0;

  bool openedSettings = false;

  @override
  Future<GalleryPermission> requestPermission() async {
    final index = _requests < _sequence.length ? _requests : _sequence.length - 1;
    _requests++;
    return _sequence[index];
  }

  @override
  Future<void> openAppSettings() async => openedSettings = true;

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
