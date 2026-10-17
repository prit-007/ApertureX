import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session state for node-based selective editing (issue #25): the drop-a-pin
/// radial control points rendered over the photo.
///
/// `selected` is an index into `recipe.layers` (any kind; only radial layers
/// are rendered as nodes, and consumers must guard against the index going
/// stale when layers change).
class NodeEditorState {
  const NodeEditorState({
    this.enabled = false,
    this.selected,
    this.eraserMode = false,
    this.refineBrushMode = false,
  });

  /// Whether the photo is in "tap to place / drag to adjust" node mode.
  final bool enabled;

  /// Recipe layer index of the selected node, if any.
  final int? selected;

  /// Whether the brush is currently in eraser mode.
  final bool eraserMode;

  /// Whether the brush is currently in refine edge mode (issue #95).
  final bool refineBrushMode;

  NodeEditorState copyWith({
    bool? enabled,
    int? selected,
    bool? eraserMode,
    bool? refineBrushMode,
  }) => NodeEditorState(
    enabled: enabled ?? this.enabled,
    selected: selected ?? this.selected,
    eraserMode: eraserMode ?? this.eraserMode,
    refineBrushMode: refineBrushMode ?? this.refineBrushMode,
  );

  @override
  bool operator ==(Object other) =>
      other is NodeEditorState &&
      other.enabled == enabled &&
      other.selected == selected &&
      other.eraserMode == eraserMode &&
      other.refineBrushMode == refineBrushMode;

  @override
  int get hashCode => Object.hash(enabled, selected, eraserMode, refineBrushMode);
}

class NodeEditor extends Notifier<NodeEditorState> {
  @override
  NodeEditorState build() => const NodeEditorState();

  void enable() {
    if (state.enabled) return;
    state = state.copyWith(enabled: true);
  }

  void disable() {
    if (!state.enabled &&
        state.selected == null &&
        !state.eraserMode &&
        !state.refineBrushMode) {
      return;
    }
    state = const NodeEditorState();
  }

  void toggle() => state.enabled ? disable() : enable();

  void select(int? index) {
    if (state.selected == index) return;
    state = NodeEditorState(
      enabled: state.enabled,
      selected: index,
      eraserMode: state.eraserMode,
      refineBrushMode: state.refineBrushMode,
    );
  }

  void setEraserMode(bool value) {
    if (state.eraserMode == value) return;
    state = state.copyWith(
      eraserMode: value,
      refineBrushMode: value ? false : state.refineBrushMode,
    );
  }

  void toggleEraserMode() => setEraserMode(!state.eraserMode);

  void setRefineBrushMode(bool value) {
    if (state.refineBrushMode == value) return;
    state = state.copyWith(
      refineBrushMode: value,
      eraserMode: value ? false : state.eraserMode,
    );
  }

  void toggleRefineBrushMode() => setRefineBrushMode(!state.refineBrushMode);
}

/// Active selective-editing mode + selection (issue #25).
final nodeEditorProvider = NotifierProvider<NodeEditor, NodeEditorState>(
  NodeEditor.new,
);
