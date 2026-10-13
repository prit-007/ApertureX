import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'parameter.dart';
import 'recipe.dart';
import 'recipe_state.dart';
import 'tone_curve.dart';

/// Single source of truth for an edit session. Both shells (Lightroom panels
/// and the Snapseed gesture FSM) read and write exactly this one controller —
/// neither shell owns edit state (ADR 0008 §6).
///
/// History is a **branchable list**: committing after an undo truncates the
/// redo tail, so a new edit branches from the current node (ADR 0011).
final recipeControllerProvider = NotifierProvider<RecipeController, RecipeState>(
  RecipeController.new,
);

class RecipeController extends Notifier<RecipeState> {
  @override
  RecipeState build() => const RecipeState(
    recipe: EditRecipe.neutral,
    history: [RecipeHistoryEntry('Original', EditRecipe.neutral)],
  );

  bool get isDirty => state.isDirty;

  /// Selects the UI's active parameter (also set on edits).
  void selectParameter(Parameter? parameter) =>
      state = state.copyWith(activeParameter: parameter);

  /// Sets [parameter] to an absolute [value] (clamped to its range).
  void update(Parameter parameter, double value) {
    state = state.copyWith(
      recipe: withValue(state.recipe, parameter, value),
      activeParameter: parameter,
    );
  }

  /// Applies an incremental [delta], scaled by the parameter's sensitivity.
  void applyDelta(Parameter parameter, double delta) {
    update(
      parameter,
      valueOf(state.recipe, parameter) + delta * specOf(parameter).scale,
    );
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

  /// Commits the live recipe as a new (optionally named) history node. Truncates
  /// the redo tail — this is where a branch happens.
  void commit({String? label}) {
    if (!state.isDirty) return;
    final history = [
      ...state.history.sublist(0, state.index + 1),
      RecipeHistoryEntry(label ?? 'Edit', state.recipe),
    ];
    state = state.copyWith(history: history, index: history.length - 1);
  }

  /// Discards live edits back to the current committed node.
  void cancel() => state = state.copyWith(recipe: state.committed);

  /// Steps back one history node.
  void undo() {
    if (state.index == 0) return;
    final i = state.index - 1;
    state = state.copyWith(index: i, recipe: state.history[i].recipe);
  }

  /// Steps forward one history node.
  void redo() {
    if (state.index >= state.history.length - 1) return;
    final i = state.index + 1;
    state = state.copyWith(index: i, recipe: state.history[i].recipe);
  }

  /// Jumps to a history node (viewing it). A later commit branches from here.
  void jumpTo(int index) {
    if (index < 0 || index >= state.history.length) return;
    state = state.copyWith(index: index, recipe: state.history[index].recipe);
  }
}
