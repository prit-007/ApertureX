import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gallery/gallery_asset.dart';

/// Holds the active image bytes for the current editing session.
final activeImageBytesProvider = NotifierProvider<ActiveImageBytesNotifier, Uint8List?>(
  ActiveImageBytesNotifier.new,
);

class ActiveImageBytesNotifier extends Notifier<Uint8List?> {
  @override
  Uint8List? build() => null;

  void setBytes(Uint8List? bytes) => state = bytes;
}

/// The [GalleryAsset] currently being edited, so settings and info sheets can
/// load the original (EXIF-bearing) bytes instead of preview bytes.
final currentEditingAssetProvider =
    NotifierProvider<CurrentEditingAssetNotifier, GalleryAsset?>(
  CurrentEditingAssetNotifier.new,
);

class CurrentEditingAssetNotifier extends Notifier<GalleryAsset?> {
  @override
  GalleryAsset? build() => null;

  void setAsset(GalleryAsset? asset) => state = asset;
}
