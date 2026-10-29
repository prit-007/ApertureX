import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aperturex/gallery/folder_gallery_source.dart';
import 'package:aperturex/gallery/gallery_source.dart';
import 'package:aperturex/gallery/photo_gallery_source.dart';
import 'package:aperturex/gallery/gallery_source_factory.dart';

/// 1×1 PNG (same fixture the other gallery tests use).
final Uint8List _pngBytes = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// TIFF magic — detectImageFormat reports this as a RAW container.
const List<int> _tiffMagic = [0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('aperturex-folder-src');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  FolderGallerySource sourceWith({Future<String?> Function()? pick}) =>
      FolderGallerySource(pickDirectory: pick ?? () async => tempDir.path);

  File write(String name, List<int> bytes, {DateTime? modified}) {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name')
      ..writeAsBytesSync(bytes);
    if (modified != null) {
      file.setLastModifiedSync(modified);
    }
    return file;
  }

  group('scanning the chosen folder', () {
    test(
      'keeps supported images flat, newest-first, skips everything else',
      () async {
        write('old.jpg', _pngBytes, modified: DateTime(2024, 1, 1));
        write('new.png', _pngBytes, modified: DateTime(2025, 6, 1));
        write('notes.txt', [1, 2, 3]); // unsupported extension
        write('noext', _pngBytes); // no extension at all
        final sub = Directory('${tempDir.path}/sub')..createSync();
        File('${sub.path}/deep.jpg').writeAsBytesSync(_pngBytes); // not flat

        final src = sourceWith();
        await src.pickRoot();
        final images = await src.listImages();

        expect(
          images.map((a) => a.id).toList(),
          ['new.png', 'old.jpg'],
          reason: 'flat scan, newest first; txt/no-extension/subdir excluded',
        );
        expect(images.first.modified!.year, 2025);
      },
    );

    test('accepts the RAW extensions the Rust decoder opens', () async {
      write('shot.dng', _tiffMagic);
      write('shot2.cr2', _tiffMagic);
      write('shot3.nef', _tiffMagic);
      write('shot4.arw', _tiffMagic);

      final src = sourceWith();
      await src.pickRoot();
      final images = await src.listImages();
      expect(images.map((a) => a.id).toSet(), {
        'shot.dng',
        'shot2.cr2',
        'shot3.nef',
        'shot4.arw',
      });
    });

    test('limits results and filters by the folder album id', () async {
      write('a.jpg', _pngBytes, modified: DateTime(2024, 1, 1));
      write('b.jpg', _pngBytes, modified: DateTime(2024, 1, 2));
      write('c.jpg', _pngBytes, modified: DateTime(2024, 1, 3));
      final src = sourceWith();
      await src.pickRoot();

      expect((await src.listImages(limit: 2)).map((a) => a.id), [
        'c.jpg',
        'b.jpg',
      ]);
      expect(await src.listImages(albumId: kFolderAlbumId), hasLength(3));
      expect(await src.listImages(albumId: 'some-other-album'), isEmpty);
    });
  });

  group('permission + settings (no system photo library on desktop)', () {
    test('requestPermission is granted without any platform channel', () async {
      expect(await sourceWith().requestPermission(), GalleryPermission.granted);
    });

    test('openAppSettings is a no-op instead of throwing', () async {
      await sourceWith().openAppSettings();
    });
  });

  group('root lifecycle', () {
    test('no root → empty library and no albums', () async {
      final src = FolderGallerySource(pickDirectory: () async => null);
      expect(src.rootPath, isNull);
      expect(await src.listImages(), isEmpty);
      expect(await src.listAlbums(), isEmpty);
      expect(await src.requestPermission(), GalleryPermission.granted);
    });

    test('picking persists the root for the next session', () async {
      write('a.jpg', _pngBytes);
      final first = sourceWith();
      expect(await first.pickRoot(), isTrue);
      expect(first.rootPath, tempDir.path);

      // A fresh instance (same persisted prefs) resolves the root itself —
      // this is the app-restart contract for the Edits catalog (#103).
      final second = FolderGallerySource(pickDirectory: () async => null);
      expect(await second.listImages(), hasLength(1));
      expect(second.rootPath, tempDir.path);
    });

    test('a cancelled re-pick keeps the current root', () async {
      write('a.jpg', _pngBytes);
      final first = sourceWith();
      await first.pickRoot();

      final second = FolderGallerySource(pickDirectory: () async => null);
      expect(await second.pickRoot(), isFalse, reason: 'picker returned null');
      expect(second.rootPath, tempDir.path, reason: 'root must not be cleared');
      expect(await second.listImages(), hasLength(1));
    });

    test('a root that disappeared on disk degrades to “no root”', () async {
      SharedPreferences.setMockInitialValues({
        folderRootPrefsKey: '${tempDir.path}${Platform.pathSeparator}gone',
      });
      final src = FolderGallerySource(pickDirectory: () async => null);
      expect(await src.listImages(), isEmpty);
      expect(src.rootPath, isNull, reason: 'stale root dropped, CTA returns');
    });

    test('album is one folder entry named after the root', () async {
      write('a.jpg', _pngBytes);
      final src = sourceWith();
      await src.pickRoot();
      final albums = await src.listAlbums();
      expect(albums, hasLength(1));
      expect(albums.single.id, kFolderAlbumId);
      expect(
        albums.single.name,
        tempDir.path.split(Platform.pathSeparator).last,
      );
      expect(albums.single.count, 1);
    });
  });

  group('id contract: bare names resolved under the root', () {
    test('loadImage round-trips bytes for an id from the scan', () async {
      write('a.jpg', _pngBytes);
      final src = sourceWith();
      await src.pickRoot();
      expect(await src.loadImage('a.jpg'), _pngBytes);
    });

    test(
      'rejects traversal/absolute ids and tolerates missing files',
      () async {
        write('a.jpg', _pngBytes);
        final src = sourceWith();
        await src.pickRoot();

        expect(
          await src.loadImage('a.jpg'),
          _pngBytes,
          reason: 'control: valid bare name still resolves',
        );
        expect(await src.loadImage('../a.jpg'), isEmpty);
        expect(await src.loadImage('sub/../a.jpg'), isEmpty);
        expect(await src.loadImage('/etc/passwd'), isEmpty);
        expect(await src.loadImage('missing.jpg'), isEmpty);
      },
    );

    test(
      'ids stay valid after moving to a sibling root (same names)',
      () async {
        final other = await Directory.systemTemp.createTemp(
          'aperturex-folder2',
        );
        addTearDown(() async {
          if (await other.exists()) await other.delete(recursive: true);
        });
        write('a.jpg', _pngBytes);
        final src = sourceWith();
        await src.pickRoot();
        expect(await src.loadImage('a.jpg'), _pngBytes);

        const different = [0x01, 0x02, 0x03];
        File('${other.path}/a.jpg').writeAsBytesSync(different);
        expect(await src.setRoot(other.path), isTrue);
        expect(
          await src.loadImage('a.jpg'),
          different,
          reason: 'same relative id resolves under the new root',
        );
      },
    );
  });

  group('preview/thumbnail contract', () {
    test('raster preview is a bounded JPEG (never the raw original)', () async {
      // 100×50 PNG → preview maxDim 32 must shrink the long side to ≤32 and
      // re-encode as JPEG so the editor's engine path sees JPEG bytes.
      final bigPng = img.encodePng(img.Image(width: 100, height: 50));
      write('big.png', bigPng);
      final src = sourceWith();
      await src.pickRoot();

      final preview = await src.loadPreview('big.png', maxDim: 32);
      final decoded = img.decodeJpg(preview);
      expect(decoded, isNotNull, reason: 'preview must be JPEG-encoded');
      expect(decoded!.width, lessThanOrEqualTo(32));
      expect(decoded.height, lessThanOrEqualTo(32));
    });

    test('RAW preview passes the original bytes through untouched', () async {
      final raw = Uint8List.fromList(_tiffMagic);
      write('shot.dng', raw);
      final src = sourceWith();
      await src.pickRoot();
      expect(await src.loadPreview('shot.dng'), raw);
    });

    test('raster thumbnail is a bounded JPEG', () async {
      final bigPng = img.encodePng(img.Image(width: 100, height: 50));
      write('big.png', bigPng);
      final src = sourceWith();
      await src.pickRoot();

      final thumb = await src.loadThumbnail('big.png', size: 16);
      final decoded = img.decodeJpg(thumb);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(16));
      expect(decoded.height, lessThanOrEqualTo(16));
    });

    test(
      'RAW cells degrade to the placeholder (no thumbnail encoder)',
      () async {
        // v1 exposes no Rust thumbnail encoder, so RAW ids must return empty
        // bytes and the grid draws its placeholder — never a crash, never a
        // full-resolution dump (#103).
        write('shot.dng', _tiffMagic);
        final src = sourceWith();
        await src.pickRoot();
        expect(await src.loadThumbnail('shot.dng'), isEmpty);
      },
    );

    test('missing file → empty bytes everywhere (Fake parity)', () async {
      final src = sourceWith();
      await src.pickRoot();
      expect(await src.loadImage('gone.jpg'), isEmpty);
      expect(await src.loadPreview('gone.jpg'), isEmpty);
      expect(await src.loadThumbnail('gone.jpg'), isEmpty);
    });
  });

  group('platform default factory', () {
    test('desktop platforms get the folder source', () {
      expect(defaultGallerySource(isDesktop: true), isA<FolderGallerySource>());
    });

    test('mobile/macOS keep photo_manager', () {
      expect(defaultGallerySource(isDesktop: false), isA<PhotoGallerySource>());
    });
  });
}
