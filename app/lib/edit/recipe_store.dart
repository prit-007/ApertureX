import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'recipe.dart';

/// Per-image non-destructive recipes (`assetId → recipe`). Because a recipe is
/// tiny JSON, pasting the same grade onto 100 photos is instant — processing
/// only happens at export (batch editing, #13).
///
/// A **neutral** recipe is stored as *absence* (removed), so the gallery's
/// "edited" badge is accurate and an untouched photo never bloats the store.
class RecipeStore extends Notifier<Map<String, EditRecipe>> {
  @override
  Map<String, EditRecipe> build() => const {};

  EditRecipe? recipeFor(String id) => state[id];

  void put(String id, EditRecipe recipe) {
    if (recipe == EditRecipe.neutral) {
      remove(id);
      return;
    }
    if (state[id] == recipe) return; // no-op: avoid map churn on every tick
    state = {...state, id: recipe};
  }

  void remove(String id) {
    if (!state.containsKey(id)) return;
    state = {...state}..remove(id);
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
  }

  void clear() => state = const {};
}

final recipeStoreProvider =
    NotifierProvider<RecipeStore, Map<String, EditRecipe>>(RecipeStore.new);
