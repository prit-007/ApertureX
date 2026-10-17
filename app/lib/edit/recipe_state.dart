import 'history_tree.dart';
import 'parameter.dart';
import 'recipe.dart';

/// A named point in the edit history.
class RecipeHistoryEntry {
  const RecipeHistoryEntry(this.label, this.recipe, [this.nodeId]);

  final String label;
  final EditRecipe recipe;
  final NodeId? nodeId;
}

/// Immutable editing-session state (P2): a **branchable history** backed by a
/// full Directed Acyclic Graph (DAG) [HistoryTree] (Issue #97).
///
/// Preserves linear [history] and [index] accessors for seamless 100% backward
/// compatibility while supporting non-destructive branching, visual commit trees,
/// and instant branch hopping.
class RecipeState {
  const RecipeState({
    required this.recipe,
    required this.history,
    this.index = 0,
    this.activeParameter,
    this.historyTree,
  });

  /// Live (preview) recipe.
  final EditRecipe recipe;

  /// Committed snapshots along the active branch lineage, oldest first. Always non-empty.
  final List<RecipeHistoryEntry> history;

  /// Index of the current committed entry within [history].
  final int index;

  /// The parameter the UI is currently scrubbing/selected.
  final Parameter? activeParameter;

  /// The non-linear Git-style DAG history tree.
  final HistoryTree? historyTree;

  /// The committed recipe at [index].
  EditRecipe get committed => history[index].recipe;

  /// True while there are live edits not yet committed.
  bool get isDirty => recipe != committed;

  RecipeState copyWith({
    EditRecipe? recipe,
    List<RecipeHistoryEntry>? history,
    int? index,
    Object? activeParameter = _unset,
    HistoryTree? historyTree,
  }) {
    return RecipeState(
      recipe: recipe ?? this.recipe,
      history: history ?? this.history,
      index: index ?? this.index,
      activeParameter: identical(activeParameter, _unset)
          ? this.activeParameter
          : activeParameter as Parameter?,
      historyTree: historyTree ?? this.historyTree,
    );
  }

  static const Object _unset = Object();
}
