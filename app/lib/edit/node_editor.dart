import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session state for node-based selective editing (issue #25): the drop-a-pin
/// radial control points rendered over the photo.
///
/// `selected` is an index into `recipe.layers` (any kind; only radial layers
/// are rendered as nodes, and consumers must guard against the index going
/// stale when layers change).
class NodeEditorState {
  const NodeEditorState({this.enabled = false, this.selected});

  /// Whether the photo is in "tap to place / drag to adjust" node mode.
  final bool enabled;

  /// Recipe layer index of the selected node, if any.
  final int? selected;

  @override
  bool operator ==(Object other) =>
      other is NodeEditorState &&
      other.enabled == enabled &&
      other.selected == selected;

  @override
  int get hashCode => Object.hash(enabled, selected);
}

class NodeEditor extends Notifier<NodeEditorState> {
  @override
  NodeEditorState build() => const NodeEditorState();

  void enable() {
    if (state.enabled) return;
    state = NodeEditorState(enabled: true, selected: state.selected);
  }

  void disable() {
    if (!state.enabled && state.selected == null) return;
    state = const NodeEditorState();
  }

  void toggle() => state.enabled ? disable() : enable();

  void select(int? index) {
    if (state.selected == index) return;
    state = NodeEditorState(enabled: state.enabled, selected: index);
  }
}

/// Active selective-editing mode + selection (issue #25).
final nodeEditorProvider = NotifierProvider<NodeEditor, NodeEditorState>(
  NodeEditor.new,
);
