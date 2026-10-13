import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

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
  Future<List<GalleryAsset>> listImages({int limit = 200}) async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (paths.isEmpty) return const [];
    final entities = await paths.first.getAssetListPaged(page: 0, size: limit);
    return [
      for (final e in entities)
        GalleryAsset(
          id: e.id,
          width: e.width,
          height: e.height,
          created: e.createDateTime,
        ),
    ];
  }

  @override
  Future<Uint8List> loadImage(String id) async {
    final entity = await AssetEntity.fromId(id);
    return await entity?.originBytes ?? Uint8List(0);
  }

  @override
  Future<Uint8List> loadThumbnail(String id, {int size = 256}) async {
    final entity = await AssetEntity.fromId(id);
    return await entity?.thumbnailDataWithSize(ThumbnailSize(size, size)) ??
        Uint8List(0);
  }
}
