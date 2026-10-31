import 'package:aperturex/gallery/gallery_asset.dart';
import 'package:aperturex/gallery/gallery_screen.dart';
import 'package:aperturex/gallery/photo_gallery_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GalleryAsset metadata fields and chronological sorting (ISSUE-05)', () {
    test('instantiates with all extended metadata fields', () {
      final created = DateTime(2026, 4, 15, 10, 30);
      final modified = DateTime(2026, 4, 15, 11, 0);

      final asset = GalleryAsset(
        id: '10042',
        width: 4000,
        height: 3000,
        created: created,
        modified: modified,
        title: 'DSC_0042.NEF',
        mimeType: 'image/x-nikon-nef',
        type: 1,
        relativePath: 'DCIM/Camera',
        isFavorite: true,
        latitude: 37.7749,
        longitude: -122.4194,
      );

      expect(asset.id, '10042');
      expect(asset.width, 4000);
      expect(asset.height, 3000);
      expect(asset.created, created);
      expect(asset.modified, modified);
      expect(asset.latestDate, modified);
      expect(asset.title, 'DSC_0042.NEF');
      expect(asset.mimeType, 'image/x-nikon-nef');
      expect(asset.type, 1);
      expect(asset.relativePath, 'DCIM/Camera');
      expect(asset.isFavorite, isTrue);
      expect(asset.latitude, 37.7749);
      expect(asset.longitude, -122.4194);
    });

    test('latestDate falls back to created when modified is null', () {
      final created = DateTime(2026, 3, 20);
      final asset = GalleryAsset(
        id: '2001',
        width: 1920,
        height: 1080,
        created: created,
      );
      expect(asset.latestDate, created);
    });

    test('isRawAsset identifies real Android numeric ids via title and mimeType', () {
      const numericIdNef = GalleryAsset(
        id: '10000492',
        width: 6000,
        height: 4000,
        title: 'DSC_0042.NEF',
      );
      expect(isRawAsset(numericIdNef), isTrue);

      const numericIdCr3 = GalleryAsset(
        id: '10000493',
        width: 6000,
        height: 4000,
        mimeType: 'image/x-canon-cr3',
      );
      expect(isRawAsset(numericIdCr3), isTrue);

      const numericIdDng = GalleryAsset(
        id: '10000494',
        width: 4000,
        height: 3000,
        title: 'IMG_20261031_120000.DNG',
        mimeType: 'image/x-adobe-dng',
      );
      expect(isRawAsset(numericIdDng), isTrue);

      const standardJpeg = GalleryAsset(
        id: '10000495',
        width: 4000,
        height: 3000,
        title: 'IMG_20261031_120001.JPG',
        mimeType: 'image/jpeg',
      );
      expect(isRawAsset(standardJpeg), isFalse);
    });
  });

  group('PhotoGallerySource instance checks', () {
    test('instantiates with fresh thumbnail memory cache', () {
      final source = PhotoGallerySource();
      expect(source.thumbnailCache, isNotNull);
    });
  });
}
