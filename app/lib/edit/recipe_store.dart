import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_catalog.dart';
import 'recipe.dart';

/// Per-image non-destructive recipes (`entryId → recipe`). Because a recipe is
/// tiny JSON, pasting the same grade onto 100 photos is instant — processing
/// only happens at export (batch editing, #13).
///
/// Keys are **catalog entry ids** (#73): `orig:<assetId>` for photos,
/// `vc:<…>` for virtual copies — one photo can therefore carry many
/// independent edits. Every mutation is pushed write-through into
/// [libraryCatalogProvider], which owns disk persistence (#61).
///
/// A **neutral** recipe is stored as *absence* (removed), so the gallery's
/// "edited" badge is accurate and an untouched photo never bloats the store.
class RecipeStore extends Notifier<Map<String, EditRecipe>> {
  @override
  Map<String, EditRecipe> build() => const {};

  EditRecipe? recipeFor(String id) => state[id];

  /// Write-through to the catalog (batched, debounced, atomic on disk).
  void _sync(Map<String, EditRecipe> updates) =>
      ref.read(libraryCatalogProvider.notifier).syncRecipes(updates);

  void put(String id, EditRecipe recipe) {
    if (recipe == EditRecipe.neutral) {
      remove(id);
      return;
    }
    if (state[id] == recipe) return; // no-op: avoid map churn on every tick
    state = {...state, id: recipe};
    _sync({id: recipe});
  }

  void remove(String id) {
    if (state.containsKey(id)) {
      state = {...state}..remove(id);
    }
    // Always sync: the catalog may still hold metadata (original) or the
    // entry may be mid-delete (virtual copy) — syncRecipes is idempotent.
    _sync({id: EditRecipe.neutral});
  }

  void pasteTo(Iterable<String> ids, EditRecipe recipe) {
    final neutral = recipe == EditRecipe.neutral;
    final next = {...state};
    for (final id in ids) {
      if (neutral) {
        next.remove(id);
      } else {
        next[id] = recipe;
      }
    }
    state = next;
    _sync({
      for (final id in ids) id: neutral ? EditRecipe.neutral : recipe,
    });
  }

  /// In-memory reset only for the map itself; the catalog half runs through
  /// [LibraryCatalog.resetRecipes] (see its test — both are driven together
  /// by the settings/reset flow).
  void clear() => state = const {};
}

final recipeStoreProvider =
    NotifierProvider<RecipeStore, Map<String, EditRecipe>>(RecipeStore.new);
