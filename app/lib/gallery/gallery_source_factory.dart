import 'dart:io';

import 'folder_gallery_source.dart';
import 'gallery_source.dart';
import 'photo_gallery_source.dart';

/// Picks the gallery implementation for the current platform (#103).
///
/// Windows/Linux use the folder-backed source (no photo library service);
/// macOS and mobile keep photo_manager. Tests inject `isDesktop` instead of
/// mocking platform channels.
GallerySource defaultGallerySource({bool? isDesktop}) {
  final desktop = isDesktop ?? (Platform.isLinux || Platform.isWindows);
  return desktop ? FolderGallerySource() : PhotoGallerySource();
}
