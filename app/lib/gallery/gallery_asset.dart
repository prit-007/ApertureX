/// A photo in the device gallery (abstracted from the platform plugin).
class GalleryAsset {
  const GalleryAsset({
    required this.id,
    required this.width,
    required this.height,
    this.created,
    this.modified,
    this.title,
    this.mimeType,
    this.type = 1,
    this.relativePath,
    this.isFavorite = false,
    this.latitude,
    this.longitude,
  });

  final String id;
  final int width;
  final int height;
  final DateTime? created;
  final DateTime? modified;
  final String? title;
  final String? mimeType;
  final int type;
  final String? relativePath;
  final bool isFavorite;
  final double? latitude;
  final double? longitude;

  /// Effective date for chronological sorting (modified date first, falling back to created date).
  DateTime? get latestDate => modified ?? created;
}
