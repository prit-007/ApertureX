import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/gallery/gallery_asset.dart';
import 'package:aperturex/gallery/gallery_grouping.dart';

GalleryAsset _asset(String id, DateTime? created) =>
    GalleryAsset(id: id, width: 1, height: 1, created: created);

void main() {
  test('groups by day, newest first, with a header per day', () {
    final rows = buildGalleryRows([
      _asset('x', DateTime(2025, 12, 24, 9)),
      _asset('y', DateTime(2025, 12, 24, 8)),
      _asset('z', DateTime(2025, 12, 22, 8)),
    ]);

    expect(rows[0], isA<GalleryDateHeader>());
    expect((rows[0] as GalleryDateHeader).label, 'Dec 24, 2025');
    expect((rows[1] as GalleryPhoto).asset.id, 'x');
    expect((rows[2] as GalleryPhoto).asset.id, 'y');
    expect((rows[3] as GalleryDateHeader).label, 'Dec 22, 2025');
    expect((rows[4] as GalleryPhoto).asset.id, 'z');
  });

  test('Today / Yesterday labels', () {
    final now = DateTime(2026, 1, 10, 12);
    expect(dateHeaderLabel(DateTime(2026, 1, 10), now: now), 'Today');
    expect(dateHeaderLabel(DateTime(2026, 1, 9), now: now), 'Yesterday');
    expect(dateHeaderLabel(DateTime(2025, 12, 31), now: now), 'Dec 31, 2025');
  });

  test('same-year groups omit the year', () {
    final now = DateTime(2026, 3, 1);
    expect(dateHeaderLabel(DateTime(2026, 2, 14), now: now), 'Feb 14');
  });

  test('undated assets go into a trailing "Unknown date" group', () {
    final rows = buildGalleryRows([
      _asset('u', null),
      _asset('d', DateTime(2025, 1, 1)),
    ]);
    expect(rows.last, isA<GalleryPhoto>());
    expect((rows.last as GalleryPhoto).asset.id, 'u');
    expect(
      rows.any((r) => r is GalleryDateHeader && r.label == 'Unknown date'),
      isTrue,
    );
  });
}
