import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'parameter.dart';
import 'recipe.dart';
import 'recipe_state.dart';
import 'tone_curve.dart';

/// Single source of truth for an edit session. Both shells (Lightroom panels
/// and the Snapseed gesture FSM) read and write exactly this one controller —
/// neither shell owns edit state (ADR 0008 §6).
final recipeControllerProvider =
    NotifierProvider<RecipeController, RecipeState>(RecipeController.new);

/// Semantics:
/// * [update]/[applyDelta]/[reset] change the *live* [RecipeState.recipe].
/// * [commit] pushes the previous node on the undo stack and clears redo
///   (Snapseed "✓" / Lightroom slider release).
/// * [cancel] discards live edits, restoring the last commit (Snapseed "✕").
/// * [undo]/[redo] walk the committed-history stack.
class RecipeController extends Notifier<RecipeState> {
  @override
  RecipeState build() => const RecipeState(
    recipe: EditRecipe.neutral,
    committed: EditRecipe.neutral,
  );

  EditRecipe get _recipe => state.recipe;

  /// Selects the UI's active parameter (also sets it on edits).
  void selectParameter(Parameter? parameter) =>
      state = state.copyWith(activeParameter: parameter);

  /// Sets [parameter] to an absolute [value] (clamped to its range).
  void update(Parameter parameter, double value) {
    state = state.copyWith(
      recipe: withValue(_recipe, parameter, value),
      activeParameter: parameter,
    );
  }

  /// Applies an incremental [delta], scaled by the parameter's sensitivity.
  void applyDelta(Parameter parameter, double delta) {
    final scale = specOf(parameter).scale;
    update(parameter, valueOf(_recipe, parameter) + delta * scale);
  }

  /// Resets [parameter] to neutral.
  void reset(Parameter parameter) =>
      update(parameter, specOf(parameter).neutral);

  /// Replaces one tone curve (live edit; commit separately).
  void setCurve(ToneCurveChannel channel, ToneCurve curve) {
    final recipe = switch (channel) {
      ToneCurveChannel.master => state.recipe.copyWith(masterCurve: curve),
      ToneCurveChannel.red => state.recipe.copyWith(redCurve: curve),
      ToneCurveChannel.green => state.recipe.copyWith(greenCurve: curve),
      ToneCurveChannel.blue => state.recipe.copyWith(blueCurve: curve),
    };
    state = state.copyWith(recipe: recipe);
  }

  /// Commits the live recipe as the new node. No-op when nothing changed.
  void commit() {
    if (!state.isDirty) return;
    state = state.copyWith(
      committed: state.recipe,
      undoStack: [...state.undoStack, state.committed],
      redoStack: const [],
    );
  }

  /// Discards live edits back to the last committed node.
  void cancel() => state = state.copyWith(recipe: state.committed);

  /// Steps back one committed node (also replaces any live edits).
  void undo() {
    final undo = state.undoStack;
    if (undo.isEmpty) return;
    final previous = undo.last;
    state = state.copyWith(
      recipe: previous,
      committed: previous,
      undoStack: undo.sublist(0, undo.length - 1),
      redoStack: [...state.redoStack, state.committed],
    );
  }

  /// Redoes the last undone commit.
  void redo() {
    final redo = state.redoStack;
    if (redo.isEmpty) return;
    final next = redo.last;
    state = state.copyWith(
      recipe: next,
      committed: next,
      undoStack: [...state.undoStack, state.committed],
      redoStack: redo.sublist(0, redo.length - 1),
    );
  }
}