/// A photo in the device gallery (abstracted from the platform plugin).
class GalleryAsset {
  const GalleryAsset({
    required this.id,
    required this.width,
    required this.height,
    this.created,
    this.modified,
  });

  final String id;
  final int width;
  final int height;
  final DateTime? created;
  final DateTime? modified;

  /// Effective date for chronological sorting (modified date first, falling back to created date).
  DateTime? get latestDate => modified ?? created;
}
