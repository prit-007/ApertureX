import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'recipe.dart';

/// Per-image non-destructive recipes (`assetId → recipe`). Because a recipe is
/// tiny JSON, pasting the same grade onto 100 photos is instant — processing
/// only happens at export (batch editing, #13).
class RecipeStore extends Notifier<Map<String, EditRecipe>> {
  @override
  Map<String, EditRecipe> build() => const {};

  EditRecipe? recipeFor(String id) => state[id];

  void put(String id, EditRecipe recipe) => state = {...state, id: recipe};

  void pasteTo(Iterable<String> ids, EditRecipe recipe) {
    final next = {...state};
    for (final id in ids) {
      next[id] = recipe;
    }
    state = next;
  }

  void clear() => state = const {};
}

final recipeStoreProvider =
    NotifierProvider<RecipeStore, Map<String, EditRecipe>>(RecipeStore.new);
