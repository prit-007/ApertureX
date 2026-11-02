import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'recipe.dart';
import 'recipe_snapshot.dart';

/// Manages the list of named snapshots for the active photo.
class SnapshotsNotifier extends Notifier<List<RecipeSnapshot>> {
  @override
  List<RecipeSnapshot> build() => const [];

  /// Creates and saves a new named snapshot from [recipe].
  RecipeSnapshot createSnapshot({
    required String name,
    required EditRecipe recipe,
  }) {
    final snapshot = RecipeSnapshot(
      id: 'snap_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      name: name.trim().isEmpty ? 'Snapshot ${state.length + 1}' : name.trim(),
      recipe: recipe,
      timestamp: DateTime.now().toUtc(),
    );
    state = [snapshot, ...state];
    return snapshot;
  }

  /// Deletes a snapshot by [id].
  void deleteSnapshot(String id) {
    state = state.where((s) => s.id != id).toList();
  }

  /// Renames an existing snapshot.
  void renameSnapshot(String id, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    state = [
      for (final s in state)
        if (s.id == id) s.copyWith(name: trimmed) else s,
    ];
  }

  /// Clears all snapshots (e.g. when opening a new photo).
  void clear() {
    state = const [];
  }
}

/// Provider of the list of named snapshots for creative versioning.
final snapshotsProvider =
    NotifierProvider<SnapshotsNotifier, List<RecipeSnapshot>>(
  SnapshotsNotifier.new,
);

/// Active snapshot recipe used for live A/B compare against the current edit.
/// When null, A/B compare evaluates against the original unedited source.
class SnapshotCompareRecipeNotifier extends Notifier<EditRecipe?> {
  @override
  EditRecipe? build() => null;

  void setRecipe(EditRecipe? recipe) {
    state = recipe;
  }
}

final snapshotCompareRecipeProvider =
    NotifierProvider<SnapshotCompareRecipeNotifier, EditRecipe?>(
  SnapshotCompareRecipeNotifier.new,
);
