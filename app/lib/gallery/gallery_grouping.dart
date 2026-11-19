import 'gallery_asset.dart';

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// A row in the grouped gallery feed: either a date header or a photo.
sealed class GalleryRow {
  const GalleryRow();
}

class GalleryDateHeader extends GalleryRow {
  const GalleryDateHeader(this.label, this.day);

  final String label;

  /// Midnight of the group's calendar day, for stable keys.
  final DateTime day;
}

class GalleryPhoto extends GalleryRow {
  const GalleryPhoto(this.asset);

  final GalleryAsset asset;
}

/// Human date label for a group header ("Today", "Yesterday", "Dec 24, 2025").
String dateHeaderLabel(DateTime day, {DateTime? now}) {
  final today = _midnight(now ?? DateTime.now());
  final d = _midnight(day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  final suffix = d.year == today.year ? '' : ', ${d.year}';
  return '${_months[d.month - 1]} ${d.day}$suffix';
}

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

/// Sorting options for the library gallery.
enum GallerySortOption {
  dateNewest('Date: Newest First'),
  dateOldest('Date: Oldest First'),
  name('Name (A-Z)'),
  iso('ISO Speed'),
  aperture('Aperture (f-stop)'),
  focalLength('Focal Length');

  const GallerySortOption(this.label);
  final String label;
}

/// Filters [assets] by matching substring [query] against asset ID or metadata keywords.
List<GalleryAsset> filterAssets(List<GalleryAsset> assets, String query) {
  if (query.trim().isEmpty) return assets;
  final q = query.trim().toLowerCase();
  return assets.where((a) => a.id.toLowerCase().contains(q)).toList();
}

/// Sorts [assets] according to [option].
List<GalleryAsset> sortAssets(List<GalleryAsset> assets, GallerySortOption option) {
  final list = List<GalleryAsset>.from(assets);
  switch (option) {
    case GallerySortOption.dateNewest:
      list.sort((a, b) => (b.latestDate ?? DateTime(0)).compareTo(a.latestDate ?? DateTime(0)));
      break;
    case GallerySortOption.dateOldest:
      list.sort((a, b) => (a.latestDate ?? DateTime(0)).compareTo(b.latestDate ?? DateTime(0)));
      break;
    case GallerySortOption.name:
      list.sort((a, b) => a.id.compareTo(b.id));
      break;
    case GallerySortOption.iso:
      list.sort((a, b) {
        if (a.iso == null && b.iso == null) {
          return (b.latestDate ?? DateTime(0)).compareTo(a.latestDate ?? DateTime(0));
        }
        if (a.iso == null) return 1;
        if (b.iso == null) return -1;
        final cmp = a.iso!.compareTo(b.iso!);
        return cmp != 0 ? cmp : (b.latestDate ?? DateTime(0)).compareTo(a.latestDate ?? DateTime(0));
      });
      break;
    case GallerySortOption.aperture:
      list.sort((a, b) {
        if (a.aperture == null && b.aperture == null) {
          return (b.latestDate ?? DateTime(0)).compareTo(a.latestDate ?? DateTime(0));
        }
        if (a.aperture == null) return 1;
        if (b.aperture == null) return -1;
        final cmp = a.aperture!.compareTo(b.aperture!);
        return cmp != 0 ? cmp : (b.latestDate ?? DateTime(0)).compareTo(a.latestDate ?? DateTime(0));
      });
      break;
    case GallerySortOption.focalLength:
      list.sort((a, b) {
        if (a.focalLength == null && b.focalLength == null) {
          return (b.latestDate ?? DateTime(0)).compareTo(a.latestDate ?? DateTime(0));
        }
        if (a.focalLength == null) return 1;
        if (b.focalLength == null) return -1;
        final cmp = a.focalLength!.compareTo(b.focalLength!);
        return cmp != 0 ? cmp : (b.latestDate ?? DateTime(0)).compareTo(a.latestDate ?? DateTime(0));
      });
      break;
  }
  return list;
}

/// Groups [assets] into a flat list of date headers + photos, **newest first**
/// (Google-Photos style). Photos with no date fall into an "Unknown date" group
/// at the end.
List<GalleryRow> buildGalleryRows(List<GalleryAsset> assets) {
  final dated = [for (final a in assets) if (a.latestDate != null) a]
    ..sort((a, b) => b.latestDate!.compareTo(a.latestDate!));
  final undated = [for (final a in assets) if (a.latestDate == null) a];

  final rows = <GalleryRow>[];
  DateTime? currentDay;
  for (final asset in dated) {
    final day = _midnight(asset.latestDate!);
    if (currentDay == null || day != currentDay) {
      rows.add(GalleryDateHeader(dateHeaderLabel(day), day));
      currentDay = day;
    }
    rows.add(GalleryPhoto(asset));
  }
  if (undated.isNotEmpty) {
    rows.add(GalleryDateHeader('Unknown date', DateTime(1970)));
    for (final asset in undated) {
      rows.add(GalleryPhoto(asset));
    }
  }
  return rows;
}
