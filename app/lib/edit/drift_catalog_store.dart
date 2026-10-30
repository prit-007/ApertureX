import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog_db.dart';
import 'library_catalog.dart';
import 'recipe.dart';

/// Riverpod provider for the singleton [CatalogDb].
final catalogDbProvider = Provider<CatalogDb>((ref) {
  final db = CatalogDb();
  ref.onDispose(db.close);
  return db;
});

/// Riverpod provider for the Drift SQLite implementation of [LibraryCatalogStore].
final driftLibraryCatalogStoreProvider = Provider<DriftLibraryCatalogStore>((ref) {
  final db = ref.watch(catalogDbProvider);
  return DriftLibraryCatalogStore(db);
});

/// SQLite-backed implementation of [LibraryCatalogStore] using Drift (#84).
class DriftLibraryCatalogStore implements LibraryCatalogStore {
  DriftLibraryCatalogStore(this.db);

  final CatalogDb db;

  @override
  Future<Map<String, CatalogEntry>> load() async {
    final rows = await db.select(db.catalogEntries).get();
    final result = <String, CatalogEntry>{};

    for (final row in rows) {
      try {
        if (row.kind < 0 || row.kind >= CatalogEntryKind.values.length) {
          continue;
        }
        final kind = CatalogEntryKind.values[row.kind];
        final decoded = jsonDecode(row.recipeJson);
        final recipe = decoded is Map
            ? EditRecipe.fromJson(decoded.cast<String, Object?>())
            : EditRecipe.neutral;

        ColorLabel? colorLabel;
        List<String> keywords = const [];
        if (decoded is Map && decoded['_meta'] is Map) {
          final meta = decoded['_meta'] as Map;
          colorLabel = ColorLabel.tryParse(meta['colorLabel'] as String?);
          if (meta['keywords'] is List) {
            keywords = (meta['keywords'] as List).whereType<String>().toList();
          }
        }

        result[row.entryId] = CatalogEntry(
          entryId: row.entryId,
          sourceAssetId: row.sourceAssetId,
          kind: kind,
          label: row.label,
          rating: row.rating,
          flag: row.flag,
          colorLabel: colorLabel,
          keywords: keywords,
          created: row.created,
          recipe: recipe,
        );
      } catch (_) {
        // Skip corrupt rows to preserve library tolerance
      }
    }
    return result;
  }

  @override
  Future<void> save(Map<String, CatalogEntry> entries) async {
    await db.transaction(() async {
      await db.delete(db.catalogEntries).go();
      await db.batch((batch) {
        for (final entry in entries.values) {
          final recipeMap = entry.recipe.toJson();
          if (entry.colorLabel != null || entry.keywords.isNotEmpty) {
            recipeMap['_meta'] = {
              if (entry.colorLabel != null) 'colorLabel': entry.colorLabel!.name,
              if (entry.keywords.isNotEmpty) 'keywords': entry.keywords,
            };
          }
          batch.insert(
            db.catalogEntries,
            CatalogEntriesCompanion.insert(
              entryId: entry.entryId,
              sourceAssetId: entry.sourceAssetId,
              kind: entry.kind.index,
              label: Value(entry.label),
              rating: Value(entry.rating),
              flag: Value(entry.flag),
              created: entry.created,
              recipeJson: jsonEncode(recipeMap),
            ),
          );
        }
      });
    });
  }
}
