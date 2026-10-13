import 'parameter.dart';
import 'recipe.dart';

/// A named point in the edit history.
class RecipeHistoryEntry {
  const RecipeHistoryEntry(this.label, this.recipe);

  final String label;
  final EditRecipe recipe;
}

/// Immutable editing-session state (P2): a **branchable history** — a list of
/// labeled recipe snapshots plus the current index. Committing after an undo
/// truncates the redo tail, so the history is a tree in disguise (ADR 0011).
class RecipeState {
  const RecipeState({
    required this.recipe,
    required this.history,
    this.index = 0,
    this.activeParameter,
  });

  /// Live (preview) recipe.
  final EditRecipe recipe;

  /// Committed snapshots, oldest first. Always non-empty.
  final List<RecipeHistoryEntry> history;

  /// Index of the current committed entry within [history].
  final int index;

  /// The parameter the UI is currently scrubbing/selected.
  final Parameter? activeParameter;

  /// The committed recipe at [index].
  EditRecipe get committed => history[index].recipe;

  /// True while there are live edits not yet committed.
  bool get isDirty => recipe != committed;

  RecipeState copyWith({
    EditRecipe? recipe,
    List<RecipeHistoryEntry>? history,
    int? index,
    Object? activeParameter = _unset,
  }) {
    return RecipeState(
      recipe: recipe ?? this.recipe,
      history: history ?? this.history,
      index: index ?? this.index,
      activeParameter: identical(activeParameter, _unset)
          ? this.activeParameter
          : activeParameter as Parameter?,
    );
  }

  static const Object _unset = Object();
}
