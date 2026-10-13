/// A photo in the device gallery (abstracted from the platform plugin).
class GalleryAsset {
  const GalleryAsset({
    required this.id,
    required this.width,
    required this.height,
    this.created,
  });

  final String id;
  final int width;
  final int height;
  final DateTime? created;
}
