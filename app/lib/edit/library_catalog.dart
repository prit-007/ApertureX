import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'recipe.dart';
import 'recipe_store.dart';

/// Catalog entry id for the **original** photo [assetId]. Virtual copies use
/// their own generated id; keying the live [RecipeStore] by entry id is what
/// lets one photo carry many independent edits (#73).
String originalEntryId(String assetId) => 'orig:$assetId';

/// Inverse of [originalEntryId] (raw ids without a prefix pass through).
String sourceAssetIdFor(String entryId) =>
    entryId.startsWith('orig:') ? entryId.substring(5) : entryId;

/// Which a catalog entry represents.
enum CatalogEntryKind {
  /// The photo itself (its develop state + optional metadata).
  original,

  /// A zero-byte copy: same pixels, independent recipe (#73).
  virtualCopy,
}

/// One row of `library.json`: enough to rebuild the gallery and every
/// recipe after a relaunch without touching a single image byte.
class CatalogEntry {
  const CatalogEntry({
    required this.entryId,
    required this.sourceAssetId,
    required this.kind,
    required this.recipe,
    required this.created,
    this.label,
    this.rating = 0,
    this.flag = false,
  });

  /// The original-photo entry for [entryId] (see [originalEntryId]).
  factory CatalogEntry.original({
    required String entryId,
    required EditRecipe recipe,
  }) => CatalogEntry(
    entryId: entryId,
    sourceAssetId: sourceAssetIdFor(entryId),
    kind: CatalogEntryKind.original,
    recipe: recipe,
    created: DateTime.now(),
  );

  factory CatalogEntry.fromJson(String entryId, Map<String, Object?> json) {
    final kindName = json['kind'];
    final kind = CatalogEntryKind.values.cast<CatalogEntryKind?>().firstWhere(
      (k) => k!.name == kindName,
      orElse: () => null,
    );
    if (kind == null) {
      throw FormatException('unknown entry kind: $kindName');
    }
    final recipeJson = json['recipe'];
    return CatalogEntry(
      entryId: entryId,
      sourceAssetId:
          (json['sourceAssetId'] as String?) ?? sourceAssetIdFor(entryId),
      kind: kind,
      label: json['label'] as String?,
      recipe: recipeJson is Map
          ? EditRecipe.fromJson(recipeJson.cast<String, Object?>())
          : EditRecipe.neutral,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      flag: json['flag'] as bool? ?? false,
      created: DateTime.tryParse(json['created'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String entryId;
  final String sourceAssetId;
  final CatalogEntryKind kind;
  final String? label;
  final EditRecipe recipe;
  final int rating;
  final bool flag;
  final DateTime created;

  /// True once the entry carries anything a neutral-recipe original would
  /// lose: dropping it on a neutral recipe must keep metadata alive.
  bool get hasMetadata =>
      (label?.isNotEmpty ?? false) || rating != 0 || flag;

  CatalogEntry copyWith({
    EditRecipe? recipe,
    String? label,
    int? rating,
    bool? flag,
  }) => CatalogEntry(
    entryId: entryId,
    sourceAssetId: sourceAssetId,
    kind: kind,
    label: label ?? this.label,
    recipe: recipe ?? this.recipe,
    rating: rating ?? this.rating,
    flag: flag ?? this.flag,
    created: created,
  );

  Map<String, Object?> toJson() => {
    'entryId': entryId,
    'sourceAssetId': sourceAssetId,
    'kind': kind.name,
    if (label != null) 'label': label,
    'recipe': recipe.toJson(),
    'rating': rating,
    'flag': flag,
    'created': created.toIso8601String(),
  };
}

/// The persistence seam behind [LibraryCatalog] (#73 guardrail): the UI and
/// editor only ever see the catalog interface, so swapping this JSON
/// implementation for SQLite/ObjectBox/Isar needs zero call-site changes.
abstract class LibraryCatalogStore {
  Future<Map<String, CatalogEntry>> load();

  Future<void> save(Map<String, CatalogEntry> entries);
}

/// JSON file implementation: versioned envelope, **atomic** publish (write
/// to `library.json.tmp`, then rename — a crash never leaves a torn file).
class JsonLibraryCatalogStore implements LibraryCatalogStore {
  JsonLibraryCatalogStore({required this.file});

  /// Resolves the backing file lazily (path_provider is async).
  final Future<File> Function() file;

  @override
  Future<Map<String, CatalogEntry>> load() async {
    final file = await this.file();
    if (!await file.exists()) return const {};
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return const {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('library.json is not a JSON object');
    }
    final entriesRaw = decoded['entries'];
    if (entriesRaw is! Map) return const {};
    final out = <String, CatalogEntry>{};
    entriesRaw.forEach((key, value) {
      if (key is! String || value is! Map) return;
      try {
        out[key] = CatalogEntry.fromJson(
          key,
          value.cast<String, Object?>(),
        );
      } on FormatException {
        // One bad row must not cost the whole library; skip it.
      }
    });
    return out;
  }

  @override
  Future<void> save(Map<String, CatalogEntry> entries) async {
    final file = await this.file();
    await file.parent.create(recursive: true);
    final encoded = jsonEncode({
      'version': 1,
      'entries': {
        for (final entry in entries.values) entry.entryId: entry.toJson(),
      },
    });
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(encoded, flush: true);
    await tmp.rename(file.path);
  }
}

/// Production store: `ApplicationDocumentsDirectory/library.json` (#73).
final libraryCatalogStoreProvider = Provider<LibraryCatalogStore>(
  (ref) => JsonLibraryCatalogStore(
    file: () async {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/library.json');
    },
  ),
);

/// Debounce between a catalog mutation and its disk write: edits arrive in
/// bursts (slider ticks), each flush is one atomic rename.
const Duration kCatalogSaveDebounce = Duration(milliseconds: 300);

/// True under `flutter test` harnesses (set by the Flutter tool). Debounced
/// auto-writes are suppressed there: widget tests trip the test binding's
/// no-pending-timers invariant the moment the test body returns, and no test
/// observes disk state unless it awaits [LibraryCatalog.flush].
final bool kSuppressDebouncedSave = Platform.environment.containsKey(
  'FLUTTER_TEST',
);

/// The in-memory catalog (`entryId → entry`) plus its write-through to disk.
///
/// Lifecycle rules:
/// * [hydrate] loads once per session and merges **over** unsaved in-memory
///   work (memory wins), then restores every non-neutral recipe into the
///   live [RecipeStore] under its entry id.
/// * [RecipeStore] pushes recipe changes back through [syncRecipes], so the
///   catalog is a persisted mirror, never a second source of truth.
/// * Virtual copy entries are never dropped by a neutral recipe — only
///   [deleteVirtualCopy] removes them.
class LibraryCatalog extends Notifier<Map<String, CatalogEntry>> {
  @override
  Map<String, CatalogEntry> build() {
    ref.onDispose(() => _saveTimer?.cancel());
    return const {};
  }

  LibraryCatalogStore get _store => ref.read(libraryCatalogStoreProvider);

  Timer? _saveTimer;
  Future<void> _writeChain = Future<void>.value();
  bool _hydrated = false;
  bool _hydrating = false;
  int _vcSequence = 0;

  /// Loads `library.json` once (idempotent) and restores recipes. Errors are
  /// swallowed: a missing/corrupt catalog degrades to "fresh library", it
  /// must never block or crash startup.
  Future<void> hydrate() async {
    if (_hydrated) return;
    _hydrated = true;
    Map<String, CatalogEntry> loaded;
    try {
      loaded = await _store.load();
    } catch (_) {
      loaded = const {};
    }
    _hydrating = true;
    try {
      // Memory wins: an edit made before hydration finishes survives.
      state = {...loaded, ...state};
      final store = ref.read(recipeStoreProvider.notifier);
      for (final entry in state.values) {
        if (entry.recipe == EditRecipe.neutral) continue;
        store.put(entry.entryId, entry.recipe);
      }
    } finally {
      _hydrating = false;
    }
  }

  /// Write-through from [RecipeStore]: originals are created/updated/dropped
  /// (neutral + no metadata = absence), virtual copies only ever change
  /// recipe. Batched so a multi-photo paste is one state change + one write.
  void syncRecipes(Map<String, EditRecipe> updates) {
    if (_hydrating || updates.isEmpty) return;
    Map<String, CatalogEntry>? next;
    Map<String, CatalogEntry> mutable() => next ??= {...state};

    updates.forEach((entryId, recipe) {
      final existing = state[entryId];
      if (entryId.startsWith('vc:') && existing == null) {
        return; // recipes may not conjure copies; only createVirtualCopy can
      }
      if (existing != null &&
          existing.kind == CatalogEntryKind.virtualCopy) {
        if (existing.recipe != recipe) {
          mutable()[entryId] = existing.copyWith(recipe: recipe);
        }
        return;
      }
      if (recipe == EditRecipe.neutral) {
        if (existing == null) return;
        if (existing.hasMetadata) {
          mutable()[entryId] = existing.copyWith(recipe: recipe);
        } else {
          mutable().remove(entryId);
        }
        return;
      }
      if (existing != null && existing.recipe == recipe) return;
      mutable()[entryId] = existing?.copyWith(recipe: recipe) ??
          CatalogEntry.original(entryId: entryId, recipe: recipe);
    });

    if (next != null) {
      state = next!;
      _markDirty();
    }
  }

  /// Single-entry convenience over [syncRecipes].
  void syncRecipe(String entryId, EditRecipe recipe) =>
      syncRecipes({entryId: recipe});

  /// Creates a zero-byte copy of [sourceAssetId] seeded with [recipe]
  /// (normally a snapshot of the original) and makes it live in the store.
  CatalogEntry createVirtualCopy({
    required String sourceAssetId,
    required EditRecipe recipe,
  }) {
    final existing = state.values.where(
      (e) =>
          e.kind == CatalogEntryKind.virtualCopy &&
          e.sourceAssetId == sourceAssetId,
    );
    final ordinal = existing.length + 1;
    final entry = CatalogEntry(
      entryId:
          'vc:${DateTime.now().microsecondsSinceEpoch}-${_vcSequence++}',
      sourceAssetId: sourceAssetId,
      kind: CatalogEntryKind.virtualCopy,
      label: 'Virtual copy $ordinal',
      recipe: recipe,
      created: DateTime.now(),
    );
    // Entry first: the RecipeStore push below round-trips into it.
    state = {...state, entry.entryId: entry};
    _markDirty();
    // A neutral recipe is stored as *absence* in RecipeStore — pushing it
    // would round-trip back here and delete the fresh copy. The catalog entry
    // alone carries the neutral copy until the first real edit.
    if (recipe != EditRecipe.neutral) {
      ref.read(recipeStoreProvider.notifier).put(entry.entryId, recipe);
    }
    return entry;
  }

  /// Deletes a virtual copy — the **only** way an entry leaves the catalog
  /// involuntarily; originals are never touched here.
  void deleteVirtualCopy(String entryId) {
    final entry = state[entryId];
    if (entry == null || entry.kind != CatalogEntryKind.virtualCopy) return;
    state = {...state}..remove(entryId);
    _markDirty();
    ref.read(recipeStoreProvider.notifier).remove(entryId);
  }

  void rename(String entryId, String label) {
    final entry = state[entryId];
    if (entry == null || entry.label == label) return;
    state = {...state, entryId: entry.copyWith(label: label)};
    _markDirty();
  }

  /// Sets an entry's star rating (Lightroom semantics: each entry — original
  /// or virtual copy — rates independently). Rating a not-yet-known original
  /// creates its neutral metadata entry; clearing the last metadata on a
  /// neutral original drops the entry again.
  void setRating(String entryId, int rating) {
    final entry = state[entryId];
    if (entry == null) {
      if (entryId.startsWith('vc:') || rating == 0) return;
      _putMetadataEntry(
        entryId,
        CatalogEntry.original(entryId: entryId, recipe: EditRecipe.neutral)
            .copyWith(rating: rating),
      );
      return;
    }
    if (entry.rating == rating) return;
    _putMetadataEntry(entryId, entry.copyWith(rating: rating));
  }

  /// Sets (or clears) an entry's reject flag — same metadata lifecycle as
  /// [setRating].
  void setFlag(String entryId, bool flag) {
    final entry = state[entryId];
    if (entry == null) {
      if (entryId.startsWith('vc:') || !flag) return;
      _putMetadataEntry(
        entryId,
        CatalogEntry.original(entryId: entryId, recipe: EditRecipe.neutral)
            .copyWith(flag: true),
      );
      return;
    }
    if (entry.flag == flag) return;
    _putMetadataEntry(entryId, entry.copyWith(flag: flag));
  }

  /// Commits a metadata/rating/flag change: a neutral original that ends up
  /// with no metadata and no recipe would be invisible anyway, so it leaves
  /// the catalog (freeing it from every future flush).
  void _putMetadataEntry(String entryId, CatalogEntry entry) {
    if (entry.kind == CatalogEntryKind.original &&
        entry.recipe == EditRecipe.neutral &&
        !entry.hasMetadata) {
      state = {...state}..remove(entryId);
    } else {
      state = {...state, entryId: entry};
    }
    _markDirty();
  }

  /// Clears every recipe (originals drop unless they carry metadata; copies
  /// stay as neutral copies) — the catalog half of `RecipeStore.clear`.
  void resetRecipes() {
    Map<String, CatalogEntry>? next;
    state.forEach((entryId, entry) {
      if (entry.recipe == EditRecipe.neutral) return;
      next ??= {...state};
      if (entry.kind == CatalogEntryKind.original && !entry.hasMetadata) {
        next!.remove(entryId);
      } else {
        next![entryId] = entry.copyWith(recipe: EditRecipe.neutral);
      }
    });
    if (next != null) {
      state = next!;
      _markDirty();
    }
  }

  /// Virtual copies grouped by source photo, oldest first — one pass per
  /// rebuild for the gallery grid (#73).
  Map<String, List<CatalogEntry>> virtualCopiesBySource() {
    final out = <String, List<CatalogEntry>>{};
    for (final entry in state.values) {
      if (entry.kind != CatalogEntryKind.virtualCopy) continue;
      (out[entry.sourceAssetId] ??= []).add(entry);
    }
    for (final copies in out.values) {
      copies.sort((a, b) => a.created.compareTo(b.created));
    }
    return out;
  }

  void _markDirty() {
    // Under `flutter test` the debounce timer is never scheduled: widget tests
    // verify invariants (no pending timers) the moment the test body returns,
    // and nothing there observes disk writes. Tests that assert persistence
    // call [flush] explicitly instead.
    if (kSuppressDebouncedSave) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(kCatalogSaveDebounce, () {
      _saveTimer = null;
      unawaited(_save());
    });
  }

  /// Serializes writes so a flush can never race the debounce timer onto the
  /// same temp file.
  Future<void> _save() {
    _writeChain = _writeChain.then((_) async {
      try {
        await _store.save(state);
      } catch (_) {
        // Best-effort persistence: a failed write keeps the in-memory
        // library working; the next mutation retries.
      }
    });
    return _writeChain;
  }

  /// Awaits any pending debounced write (tests and app lifecycle).
  Future<void> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    return _save();
  }
}

final libraryCatalogProvider =
    NotifierProvider<LibraryCatalog, Map<String, CatalogEntry>>(
  LibraryCatalog.new,
);
