import 'dart:io';
import 'dart:typed_data';

import 'package:aperturex/edit/catalog_db.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/gallery/edit_preview_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CatalogDb db;
  late Directory tempDir;
  late EditPreviewStore store;

  setUp(() async {
    db = CatalogDb(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('aperturex-edits-test');
    store = EditPreviewStore(
      db,
      editsDirResolver: () async => tempDir,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('recipeHash', () {
    test('produces deterministic 8-char hex string for recipe', () {
      final r1 = EditRecipe.neutral.copyWith(exposure: 1.0);
      final r2 = EditRecipe.neutral.copyWith(exposure: 1.0);
      final r3 = EditRecipe.neutral.copyWith(exposure: 1.5);

      final h1 = computeRecipeHash(r1);
      final h2 = computeRecipeHash(r2);
      final h3 = computeRecipeHash(r3);

      expect(h1, hasLength(8));
      expect(h1, equals(h2));
      expect(h1, isNot(equals(h3)));
    });
  });

  group('EditPreviewStore', () {
    test('starts empty', () async {
      final previews = await store.getAll();
      expect(previews, isEmpty);
    });

    test('savePreview writes jpeg file and inserts database row', () async {
      final dummyJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
      await store.savePreview(
        entryId: 'orig:photo1',
        jpegBytes: dummyJpeg,
        width: 1200,
        height: 800,
        recipeHash: 'a1b2c3d4',
      );

      final previews = await store.getAll();
      expect(previews, hasLength(1));
      final p = previews.first;
      expect(p.entryId, 'orig:photo1');
      expect(p.width, 1200);
      expect(p.height, 800);
      expect(p.recipeHash, 'a1b2c3d4');
      expect(File(p.path).existsSync(), isTrue);
      expect(await File(p.path).readAsBytes(), dummyJpeg);
    });

    test('re-saving with new hash cleans up stale file', () async {
      final bytes1 = Uint8List.fromList([1, 2, 3]);
      await store.savePreview(
        entryId: 'vc:copy1',
        jpegBytes: bytes1,
        width: 1000,
        height: 1000,
        recipeHash: 'hash0001',
      );

      final p1 = await store.find('vc:copy1');
      expect(p1, isNotNull);
      final oldPath = p1!.path;
      expect(File(oldPath).existsSync(), isTrue);

      final bytes2 = Uint8List.fromList([4, 5, 6, 7]);
      await store.savePreview(
        entryId: 'vc:copy1',
        jpegBytes: bytes2,
        width: 1000,
        height: 1000,
        recipeHash: 'hash0002',
      );

      // Old file should be deleted
      expect(File(oldPath).existsSync(), isFalse);

      final p2 = await store.find('vc:copy1');
      expect(p2, isNotNull);
      expect(p2!.path, isNot(equals(oldPath)));
      expect(File(p2.path).existsSync(), isTrue);
      expect(await File(p2.path).readAsBytes(), bytes2);
    });

    test('delete removes both DB row and disk file', () async {
      final dummyJpeg = Uint8List.fromList([10, 20]);
      await store.savePreview(
        entryId: 'orig:delete_me',
        jpegBytes: dummyJpeg,
        width: 800,
        height: 600,
        recipeHash: 'deadbeef',
      );

      final item = await store.find('orig:delete_me');
      expect(item, isNotNull);
      expect(File(item!.path).existsSync(), isTrue);

      await store.delete('orig:delete_me');

      expect(await store.find('orig:delete_me'), isNull);
      expect(File(item.path).existsSync(), isFalse);
    });

    test('watchAll emits updates reactively', () async {
      final stream = store.watchAll();
      expect(
        stream,
        emitsInOrder([
          isEmpty,
          hasLength(1),
        ]),
      );

      await store.savePreview(
        entryId: 'orig:reactive',
        jpegBytes: Uint8List.fromList([1]),
        width: 500,
        height: 500,
        recipeHash: '12345678',
      );
    });
  });
}
