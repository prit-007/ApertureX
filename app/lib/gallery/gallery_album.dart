/// An album (photo_manager `AssetPathEntity`) abstracted from the plugin.
class GalleryAlbum {
  const GalleryAlbum({
    required this.id,
    required this.name,
    required this.count,
    this.coverAssetId,
  });

  final String id;
  final String name;
  final int count;
  final String? coverAssetId;
}
