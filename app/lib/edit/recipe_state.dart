import 'parameter.dart';
import 'recipe.dart';

/// Immutable editing-session state (P2 Slice A; ARCHITECTURE §16).
///
/// [recipe] is the live preview value; [committed] is the last committed node.
/// History is an array of cheap, KB-sized recipe snapshots — never pixel data.
class RecipeState {
  const RecipeState({
    required this.recipe,
    required this.committed,
    this.undoStack = const [],
    this.redoStack = const [],
    this.activeParameter,
  });

  final EditRecipe recipe;
  final EditRecipe committed;

  /// Committed recipes before the current one (last element = previous node).
  final List<EditRecipe> undoStack;

  /// Committed recipes re-done from an undo (for redo).
  final List<EditRecipe> redoStack;

  /// The parameter the UI is currently scrubbing/selected.
  final Parameter? activeParameter;

  /// True while there are live edits not yet committed.
  bool get isDirty => recipe != committed;

  RecipeState copyWith({
    EditRecipe? recipe,
    EditRecipe? committed,
    List<EditRecipe>? undoStack,
    List<EditRecipe>? redoStack,
    Object? activeParameter = _unset,
  }) {
    return RecipeState(
      recipe: recipe ?? this.recipe,
      committed: committed ?? this.committed,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      activeParameter: identical(activeParameter, _unset)
          ? this.activeParameter
          : activeParameter as Parameter?,
    );
  }

  static const Object _unset = Object();
}