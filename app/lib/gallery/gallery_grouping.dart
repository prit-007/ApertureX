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

/// Groups [assets] into a flat list of date headers + photos, **newest first**
/// (Google-Photos style). Photos with no date fall into an "Unknown date" group
/// at the end.
List<GalleryRow> buildGalleryRows(List<GalleryAsset> assets) {
  final dated = [for (final a in assets) if (a.created != null) a]
    ..sort((a, b) => b.created!.compareTo(a.created!));
  final undated = [for (final a in assets) if (a.created == null) a];

  final rows = <GalleryRow>[];
  DateTime? currentDay;
  for (final asset in dated) {
    final day = _midnight(asset.created!);
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
