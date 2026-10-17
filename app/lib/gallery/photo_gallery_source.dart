import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import 'gallery_album.dart';
import 'gallery_asset.dart';
import 'gallery_source.dart';

/// Real [GallerySource] backed by `photo_manager` (scoped storage safe).
class PhotoGallerySource implements GallerySource {
  /// Requests photo access. Re-calling after a denial re-prompts on Android
  /// (where the OS allows it); when it is permanently denied the app should
  /// send the user to settings instead ([openAppSettings]).
  @override
  Future<GalleryPermission> requestPermission() async {
    final result = await PhotoManager.requestPermissionExtend();
    if (result.isAuth || result.hasAccess) {
      return result.isLimited
          ? GalleryPermission.limited
          : GalleryPermission.granted;
    }
    return GalleryPermission.denied;
  }

  @override
  Future<void> openAppSettings() => PhotoManager.openSetting();

  @override
  Future<List<GalleryAlbum>> listAlbums() async {
    final paths = await PhotoManager.getAssetPathList(type: RequestType.image);
    final albums = <GalleryAlbum>[];
    for (final p in paths) {
      albums.add(
        GalleryAlbum(
          id: p.id,
          name: p.name,
          count: await p.assetCountAsync,
        ),
      );
    }
    return albums;
  }

  @override
  Future<List<GalleryAsset>> listImages({
    int limit = 500,
    String? albumId,
  }) async {
    final path = await _pathFor(albumId);
    if (path == null) return const [];
    final entities = await path.getAssetListPaged(page: 0, size: limit);
    return [
      for (final e in entities)
        GalleryAsset(
          id: e.id,
          width: e.width,
          height: e.height,
          created: e.createDateTime,
          modified: e.modifiedDateTime,
        ),
    ];
  }

  Future<AssetPathEntity?> _pathFor(String? albumId) async {
    if (albumId == null) {
      final recent = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      return recent.isEmpty ? null : recent.first;
    }
    final paths = await PhotoManager.getAssetPathList(type: RequestType.image);
    for (final p in paths) {
      if (p.id == albumId) return p;
    }
    return null;
  }

  @override
  Future<Uint8List> loadImage(String id) async {
    final entity = await AssetEntity.fromId(id);
    return await entity?.originBytes ?? Uint8List(0);
  }

  @override
  Future<Uint8List> loadPreview(String id, {int maxDim = 1600}) async {
    final entity = await AssetEntity.fromId(id);
    if (entity == null) return Uint8List(0);
    // Never touch the full original for preview: the platform media store
    // returns a bounded, already-downscaled JPEG (fast, low-memory).
    return await entity.thumbnailDataWithSize(
          ThumbnailSize(maxDim, maxDim),
          quality: 90,
        ) ??
        Uint8List(0);
  }

  @override
  Future<Uint8List> loadThumbnail(String id, {int size = 256}) async {
    final entity = await AssetEntity.fromId(id);
    return await entity?.thumbnailDataWithSize(ThumbnailSize(size, size)) ??
        Uint8List(0);
  }
}
