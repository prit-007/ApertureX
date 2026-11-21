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
    this.iso,
    this.aperture,
    this.focalLength,
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
  final int? iso;
  final double? aperture;
  final double? focalLength;

  /// Effective date for chronological sorting (modified date first, falling back to created date).
  DateTime? get latestDate => modified ?? created;

  GalleryAsset copyWith({
    String? id,
    int? width,
    int? height,
    DateTime? created,
    DateTime? modified,
    String? title,
    String? mimeType,
    int? type,
    String? relativePath,
    bool? isFavorite,
    double? latitude,
    double? longitude,
    int? iso,
    double? aperture,
    double? focalLength,
  }) =>
      GalleryAsset(
        id: id ?? this.id,
        width: width ?? this.width,
        height: height ?? this.height,
        created: created ?? this.created,
        modified: modified ?? this.modified,
        title: title ?? this.title,
        mimeType: mimeType ?? this.mimeType,
        type: type ?? this.type,
        relativePath: relativePath ?? this.relativePath,
        isFavorite: isFavorite ?? this.isFavorite,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        iso: iso ?? this.iso,
        aperture: aperture ?? this.aperture,
        focalLength: focalLength ?? this.focalLength,
      );
}
