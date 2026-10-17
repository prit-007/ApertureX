import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../edit/catalog_db.dart';
import '../edit/drift_catalog_store.dart';
import '../edit/recipe.dart';

/// Computes an 8-character FNV-1a hex hash over the deterministic JSON
/// serialization of [recipe] (#85).
String computeRecipeHash(EditRecipe recipe) {
  final json = jsonEncode(recipe.toJson());
  var hash = 0xcbf29ce484222325;
  final bytes = utf8.encode(json);
  for (final b in bytes) {
    hash ^= b;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return (hash & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
}

/// An indexed explicit-save edit preview (#85).
class EditPreview {
  const EditPreview({
    required this.entryId,
    required this.path,
    required this.width,
    required this.height,
    required this.recipeHash,
    required this.created,
  });

  final String entryId;
  final String path;
  final int width;
  final int height;
  final String recipeHash;
  final DateTime created;
}

/// Riverpod provider for the singleton [EditPreviewStore].
final editPreviewStoreProvider = Provider<EditPreviewStore>((ref) {
  final db = ref.watch(catalogDbProvider);
  return EditPreviewStore(db);
});

/// Riverpod stream provider for watching all saved edit previews.
final editPreviewsStreamProvider = StreamProvider<List<EditPreview>>((ref) {
  final store = ref.watch(editPreviewStoreProvider);
  return store.watchAll();
});

/// SQLite-backed store for rendered proxy edit previews (#85).
class EditPreviewStore {
  EditPreviewStore(this.db, {this.editsDirResolver});

  final CatalogDb db;
  final Future<Directory> Function()? editsDirResolver;

  Future<Directory> getEditsDir() async {
    if (editsDirResolver != null) {
      final dir = await editsDirResolver!();
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/edits');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  EditPreview _fromRow(EditPreviewRow row) {
    return EditPreview(
      entryId: row.entryId,
      path: row.path,
      width: row.width,
      height: row.height,
      recipeHash: row.recipeHash,
      created: row.created,
    );
  }

  Stream<List<EditPreview>> watchAll() {
    return (db.select(db.editPreviews)
          ..orderBy([(t) => OrderingTerm.desc(t.created)]))
        .watch()
        .map((rows) => rows.map(_fromRow).toList());
  }

  Future<List<EditPreview>> getAll() async {
    final rows = await (db.select(db.editPreviews)
          ..orderBy([(t) => OrderingTerm.desc(t.created)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<EditPreview?> find(String entryId) async {
    final row = await (db.select(db.editPreviews)
          ..where((t) => t.entryId.equals(entryId)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<void> savePreview({
    required String entryId,
    required Uint8List jpegBytes,
    required int width,
    required int height,
    required String recipeHash,
  }) async {
    final dir = await getEditsDir();
    // Invalidate/delete old file if exists
    final existing = await find(entryId);
    if (existing != null && existing.path.isNotEmpty) {
      final oldFile = File(existing.path);
      if (await oldFile.exists()) {
        try {
          await oldFile.delete();
        } catch (_) {}
      }
    }

    final safeEntryId = entryId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final filePath = '${dir.path}/${safeEntryId}_$recipeHash.jpg';
    final file = File(filePath);
    await file.writeAsBytes(jpegBytes, flush: true);

    await db.into(db.editPreviews).insertOnConflictUpdate(
          EditPreviewsCompanion.insert(
            entryId: entryId,
            path: filePath,
            width: width,
            height: height,
            recipeHash: recipeHash,
            created: DateTime.now(),
          ),
        );
  }

  Future<void> delete(String entryId) async {
    final existing = await find(entryId);
    if (existing != null && existing.path.isNotEmpty) {
      final file = File(existing.path);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
    await (db.delete(db.editPreviews)..where((t) => t.entryId.equals(entryId)))
        .go();
  }
}
