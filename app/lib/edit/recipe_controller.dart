import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';
import 'adjustment_layer.dart';
import 'history_tree.dart';
import 'parameter.dart';
import 'recipe.dart';
import 'recipe_state.dart';
import 'retouch_patch.dart';
import 'tone_curve.dart';
import 'tool_definition.dart';

/// Single source of truth for an edit session. Both shells (Lightroom panels
/// and the Snapseed gesture FSM) read and write exactly this one controller —
/// neither shell owns edit state (ADR 0008 §6).
///
/// History is backed by a non-linear Git-style DAG [HistoryTree] (Issue #97).
final recipeControllerProvider = NotifierProvider<RecipeController, RecipeState>(
  RecipeController.new,
);

/// Target tonal region for 3-way color grading wheels.
enum GradeWheelZone { shadows, midtones, highlights }

class RecipeController extends Notifier<RecipeState> {
  @override
  RecipeState build() {
    final tree = HistoryTree.initial();
    return RecipeState(
      recipe: EditRecipe.neutral,
      history: [RecipeHistoryEntry('Original', EditRecipe.neutral, tree.currentNodeId)],
      historyTree: tree,
      index: 0,
    );
  }

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

  /// Updates one HSL color-mixer band (0..7) component(s). Live edit.
  void setHsl(
    int band, {
    double? hue,
    double? saturation,
    double? luminance,
  }) {
    final values = [...state.recipe.hsl];
    if (hue != null) values[band * 3] = hue.clamp(-1.0, 1.0);
    if (saturation != null) values[band * 3 + 1] = saturation.clamp(-1.0, 1.0);
    if (luminance != null) values[band * 3 + 2] = luminance.clamp(-1.0, 1.0);
    state = state.copyWith(recipe: state.recipe.copyWith(hsl: values));
  }

  /// Updates a 3-way color grading wheel (shadows, midtones, highlights).
  void setGradeWheel(
    GradeWheelZone zone, {
    double? hue,
    double? sat,
    double? lum,
  }) {
    final recipe = switch (zone) {
      GradeWheelZone.shadows => state.recipe.copyWith(
        gradeShadowHue: hue?.clamp(0.0, 360.0),
        gradeShadowSat: sat?.clamp(0.0, 1.0),
        gradeShadowLum: lum?.clamp(-1.0, 1.0),
      ),
      GradeWheelZone.midtones => state.recipe.copyWith(
        gradeMidHue: hue?.clamp(0.0, 360.0),
        gradeMidSat: sat?.clamp(0.0, 1.0),
        gradeMidLum: lum?.clamp(-1.0, 1.0),
      ),
      GradeWheelZone.highlights => state.recipe.copyWith(
        gradeHighlightHue: hue?.clamp(0.0, 360.0),
        gradeHighlightSat: sat?.clamp(0.0, 1.0),
        gradeHighlightLum: lum?.clamp(-1.0, 1.0),
      ),
    };
    state = state.copyWith(recipe: recipe);
  }

  /// Applies 2D trackball deltas to a color grading wheel:
  /// [hueDelta] in degrees, wrapping around 0..360°.
  /// [satDelta] normalized delta, clamped to 0..1.
  void applyGradeWheel2DDelta(
    GradeWheelZone zone, {
    required double hueDelta,
    required double satDelta,
  }) {
    final (currentHue, currentSat, currentLum) = switch (zone) {
      GradeWheelZone.shadows => (
        state.recipe.gradeShadowHue,
        state.recipe.gradeShadowSat,
        state.recipe.gradeShadowLum,
      ),
      GradeWheelZone.midtones => (
        state.recipe.gradeMidHue,
        state.recipe.gradeMidSat,
        state.recipe.gradeMidLum,
      ),
      GradeWheelZone.highlights => (
        state.recipe.gradeHighlightHue,
        state.recipe.gradeHighlightSat,
        state.recipe.gradeHighlightLum,
      ),
    };
    final newHue = ((currentHue + hueDelta) % 360.0 + 360.0) % 360.0;
    final newSat = (currentSat + satDelta).clamp(0.0, 1.0);
    setGradeWheel(zone, hue: newHue, sat: newSat, lum: currentLum);
  }

  /// Updates global color grading parameters (blending, balance).
  void setGradeGlobal({
    double? blending,
    double? balance,
  }) {
    state = state.copyWith(
      recipe: state.recipe.copyWith(
        gradeBlending: blending?.clamp(0.0, 1.0),
        gradeBalance: balance?.clamp(-1.0, 1.0),
      ),
    );
  }

  /// Rotates by [delta] quarter turns clockwise.
  void rotate(int delta) {
    final r = ((state.recipe.rotation + delta) % 4 + 4) % 4;
    state = state.copyWith(recipe: state.recipe.copyWith(rotation: r));
  }

  void toggleFlipH() => state = state.copyWith(
    recipe: state.recipe.copyWith(flipH: !state.recipe.flipH),
  );

  void toggleFlipV() => state = state.copyWith(
    recipe: state.recipe.copyWith(flipV: !state.recipe.flipV),
  );

  void setPerspectiveX(double degrees) => state = state.copyWith(
    recipe: state.recipe.copyWith(perspectiveX: degrees.clamp(-1.0, 1.0)),
  );

  void setPerspectiveY(double degrees) => state = state.copyWith(
    recipe: state.recipe.copyWith(perspectiveY: degrees.clamp(-1.0, 1.0)),
  );

  void setSkewX(double degrees) => state = state.copyWith(
    recipe: state.recipe.copyWith(skewX: degrees.clamp(-1.0, 1.0)),
  );

  void setSkewY(double degrees) => state = state.copyWith(
    recipe: state.recipe.copyWith(skewY: degrees.clamp(-1.0, 1.0)),
  );

  void setStraighten(double degrees) => state = state.copyWith(
    recipe: state.recipe.copyWith(straighten: degrees.clamp(-45.0, 45.0)),
  );

  void setRemoveChromaticAberration(bool value) {
    state = state.copyWith(
      recipe: state.recipe.copyWith(removeChromaticAberration: value),
    );
    commit(label: 'Remove CA');
  }

  void setProfileCorrections(bool value) {
    state = state.copyWith(
      recipe: state.recipe.copyWith(profileCorrections: value),
    );
    commit(label: 'Profile Corrections');
  }

  void setBlurEnabled(bool value) {
    state = state.copyWith(
      recipe: state.recipe.copyWith(blurEnabled: value),
    );
    commit(label: 'Lens Blur');
  }

  void setBlurBokehShape(int shapeIndex) {
    state = state.copyWith(
      recipe: state.recipe.copyWith(blurBokehShape: shapeIndex),
    );
    commit(label: 'Bokeh Shape');
  }

  void setShaderLabPreset(int preset) {
    state = state.copyWith(
      recipe: state.recipe.copyWith(shaderLabPreset: preset),
    );
    commit(label: 'Shader Preset');
  }

  void setCustomGlslCode(String code) {
    state = state.copyWith(
      recipe: state.recipe.copyWith(customGlslCode: code),
    );
    commit(label: 'Custom Shader');
  }

  /// Applies a crop (and optional rotation/flip) as one committed step.
  void applyCrop({
    required List<double> crop,
    int? rotation,
    bool? flipH,
  }) {
    var recipe = state.recipe.copyWith(crop: crop);
    if (rotation != null) {
      recipe = recipe.copyWith(rotation: ((rotation % 4) + 4) % 4);
    }
    if (flipH != null) recipe = recipe.copyWith(flipH: flipH);
    state = state.copyWith(recipe: recipe);
    commit(label: 'Crop');
  }

  /// Resets every edit back to neutral.
  void resetAll() => loadRecipe(EditRecipe.neutral, label: 'Reset');

  /// Applies a shareable look (tool definition) onto the current recipe.
  void applyTool(ToolDefinition tool) {
    state = state.copyWith(recipe: tool.applyTo(state.recipe));
    axLog(LogDomain.preset, 'Applied tool preset: ${tool.name}');
  }

  /// Appends a local adjustment layer (masking).
  void addLayer(AdjustmentLayer layer) {
    state = state.copyWith(
      recipe: state.recipe.copyWith(
        layers: [...state.recipe.layers, layer],
      ),
    );
    axLog(LogDomain.editor, 'Added mask layer: ${layer.maskKind.name}');
  }

  /// Removes the layer at [index].
  void removeLayerAt(int index) {
    final layers = [...state.recipe.layers];
    if (index < 0 || index >= layers.length) return;
    final removed = layers.removeAt(index);
    state = state.copyWith(recipe: state.recipe.copyWith(layers: layers));
    axLog(LogDomain.editor, 'Removed mask layer at $index: ${removed.maskKind.name}');
  }

  /// Replaces the layer at [index] (node moves/resizes/parameter edits,
  /// issue #25). Out-of-range indices are ignored.
  void updateLayerAt(int index, AdjustmentLayer layer) {
    final layers = [...state.recipe.layers];
    if (index < 0 || index >= layers.length) return;
    layers[index] = layer;
    state = state.copyWith(recipe: state.recipe.copyWith(layers: layers));
    axLog(LogDomain.editor, 'Updated mask layer at $index: ${layer.maskKind.name}');
  }

  void clearLayers() {
    state = state.copyWith(recipe: state.recipe.copyWith(layers: const []));
    axLog(LogDomain.editor, 'Cleared all mask layers');
  }

  /// Adds a mask group.
  void addMaskGroup(MaskGroup group) {
    state = state.copyWith(
      recipe: state.recipe.copyWith(
        maskGroups: [...state.recipe.maskGroups, group],
      ),
    );
    axLog(LogDomain.editor, 'Added mask group: ${group.name}');
  }

  /// Updates a mask group by id.
  void updateMaskGroup(MaskGroup group) {
    final groups = state.recipe.maskGroups
        .map((g) => g.id == group.id ? group : g)
        .toList();
    state = state.copyWith(
      recipe: state.recipe.copyWith(maskGroups: groups),
    );
    axLog(LogDomain.editor, 'Updated mask group: ${group.name}');
  }

  /// Removes a mask group and all member layers.
  void removeMaskGroup(String groupId) {
    final groups =
        state.recipe.maskGroups.where((g) => g.id != groupId).toList();
    final layers =
        state.recipe.layers.where((l) => l.groupId != groupId).toList();
    state = state.copyWith(
      recipe: state.recipe.copyWith(
        maskGroups: groups,
        layers: layers,
      ),
    );
    axLog(LogDomain.editor, 'Removed mask group: $groupId');
  }

  /// Appends a layer to a specific group with join operation.
  void addLayerToGroup({
    required String groupId,
    required AdjustmentLayer layer,
    MaskJoinOp joinOp = MaskJoinOp.add,
  }) {
    final member = layer.copyWith(groupId: groupId, joinOp: joinOp);
    state = state.copyWith(
      recipe: state.recipe.copyWith(
        layers: [...state.recipe.layers, member],
      ),
    );
  }

  /// Updates join operation of the layer at [index].
  void setLayerJoinOp(int index, MaskJoinOp joinOp) {
    if (index < 0 || index >= state.recipe.layers.length) return;
    final layer = state.recipe.layers[index].copyWith(joinOp: joinOp);
    updateLayerAt(index, layer);
  }

  /// Appends a retouch patch (heal/clone blemish removal).
  void addRetouchPatch(RetouchPatch patch) {
    state = state.copyWith(
      recipe: state.recipe.copyWith(
        retouchPatches: [...state.recipe.retouchPatches, patch],
      ),
    );
    commit(label: patch.mode == RetouchMode.heal ? 'Heal' : 'Clone');
  }

  /// Replaces the retouch patch at [index].
  void updateRetouchPatchAt(int index, RetouchPatch patch) {
    final patches = [...state.recipe.retouchPatches];
    if (index < 0 || index >= patches.length) return;
    patches[index] = patch;
    state = state.copyWith(
      recipe: state.recipe.copyWith(retouchPatches: patches),
    );
  }

  /// Removes the retouch patch at [index].
  void removeRetouchPatchAt(int index) {
    final patches = [...state.recipe.retouchPatches];
    if (index < 0 || index >= patches.length) return;
    patches.removeAt(index);
    state = state.copyWith(
      recipe: state.recipe.copyWith(retouchPatches: patches),
    );
    commit(label: 'Remove Patch');
  }

  /// Clears every retouch patch.
  void clearRetouchPatches() {
    if (state.recipe.retouchPatches.isEmpty) return;
    state = state.copyWith(
      recipe: state.recipe.copyWith(retouchPatches: const []),
    );
    commit(label: 'Clear Retouch');
  }

  /// Replaces the session with [recipe] from a sidecar/preset, resetting the
  /// history to a single node.
  void loadRecipe(EditRecipe recipe, {String label = 'Loaded'}) {
    final tree = HistoryTree.initial(initialRecipe: recipe, rootLabel: label);
    state = RecipeState(
      recipe: recipe,
      history: [RecipeHistoryEntry(label, recipe, tree.currentNodeId)],
      historyTree: tree,
      index: 0,
    );
    axLog(LogDomain.editor, 'Loaded recipe: $label');
  }

  /// Commits the live recipe as a new (optionally named) history node.
  ///
  /// Backed by the DAG [HistoryTree] (Issue #97). Appends a child to the current
  /// node on [HistoryTree.activeBranch] while preserving parallel branches.
  void commit({String? label, Map<String, dynamic>? metadata}) {
    if (!state.isDirty) return;
    final name = label ?? 'Edit';
    final currentTree = state.historyTree ??
        HistoryTree.initial(initialRecipe: state.committed);
    final updatedTree = currentTree.commit(
      recipe: state.recipe,
      label: name,
      metadata: metadata,
    );
    final lineage = updatedTree.activeLineage;
    final history = lineage
        .map((n) => RecipeHistoryEntry(n.label, n.recipe, n.id))
        .toList();

    state = state.copyWith(
      historyTree: updatedTree,
      history: history,
      index: history.length - 1,
    );
    axLog(LogDomain.editor, 'Committed edit: $name (branch: ${updatedTree.activeBranch})');
  }

  /// Discards live edits back to the current committed node.
  void cancel() => state = state.copyWith(recipe: state.committed);

  /// Steps back one history node along the active branch lineage.
  void undo() {
    if (state.index == 0) return;
    final i = state.index - 1;
    final targetEntry = state.history[i];
    final currentTree = state.historyTree;
    final updatedTree = targetEntry.nodeId != null && currentTree != null
        ? currentTree.jumpTo(targetEntry.nodeId!)
        : currentTree;

    state = state.copyWith(
      index: i,
      recipe: targetEntry.recipe,
      historyTree: updatedTree,
    );
    axLog(LogDomain.editor, 'Undo');
  }

  /// Steps forward one history node along the active branch lineage.
  void redo() {
    if (state.index >= state.history.length - 1) return;
    final i = state.index + 1;
    final targetEntry = state.history[i];
    final currentTree = state.historyTree;
    final updatedTree = targetEntry.nodeId != null && currentTree != null
        ? currentTree.jumpTo(targetEntry.nodeId!)
        : currentTree;

    state = state.copyWith(
      index: i,
      recipe: targetEntry.recipe,
      historyTree: updatedTree,
    );
    axLog(LogDomain.editor, 'Redo');
  }

  /// Jumps to a history node along the active branch lineage.
  void jumpTo(int index) {
    if (index < 0 || index >= state.history.length) return;
    final targetEntry = state.history[index];
    final currentTree = state.historyTree;
    final updatedTree = targetEntry.nodeId != null && currentTree != null
        ? currentTree.jumpTo(targetEntry.nodeId!)
        : currentTree;

    state = state.copyWith(
      index: index,
      recipe: targetEntry.recipe,
      historyTree: updatedTree,
    );
    axLog(LogDomain.editor, 'Jumped to history entry $index: ${targetEntry.label}');
  }

  /// Jumps to an arbitrary node in the DAG by [nodeId], regardless of active branch.
  void jumpToNode(NodeId nodeId) {
    final currentTree = state.historyTree;
    if (currentTree == null || !currentTree.nodes.containsKey(nodeId)) return;
    final updatedTree = currentTree.jumpTo(nodeId);
    final targetNode = updatedTree.nodes[nodeId]!;
    final lineage = updatedTree.activeLineage;
    final history = lineage
        .map((n) => RecipeHistoryEntry(n.label, n.recipe, n.id))
        .toList();
    final index = lineage.indexWhere((n) => n.id == nodeId);

    state = state.copyWith(
      historyTree: updatedTree,
      history: history,
      index: index >= 0 ? index : history.length - 1,
      recipe: targetNode.recipe,
    );
    axLog(LogDomain.editor, 'Jumped to DAG node $nodeId: ${targetNode.label}');
  }

  /// Creates a new named branch pointing at the current commit and switches to it.
  void createBranch(String branchName) {
    final currentTree = state.historyTree ??
        HistoryTree.initial(initialRecipe: state.committed);
    final updatedTree = currentTree.createBranch(branchName);
    state = state.copyWith(historyTree: updatedTree);
    axLog(LogDomain.editor, 'Created branch: $branchName');
  }

  /// Switches active branch to [branchName] and checks out its HEAD commit.
  void switchBranch(String branchName) {
    final currentTree = state.historyTree;
    if (currentTree == null || !currentTree.branches.containsKey(branchName)) return;
    final updatedTree = currentTree.switchBranch(branchName);
    final headNode = updatedTree.currentNode;
    final lineage = updatedTree.activeLineage;
    final history = lineage
        .map((n) => RecipeHistoryEntry(n.label, n.recipe, n.id))
        .toList();

    state = state.copyWith(
      historyTree: updatedTree,
      history: history,
      index: history.length - 1,
      recipe: headNode.recipe,
    );
    axLog(LogDomain.editor, 'Switched to branch: $branchName');
  }

  /// Deletes a branch pointer. The commits themselves remain in the DAG.
  void deleteBranch(String branchName) {
    final currentTree = state.historyTree;
    if (currentTree == null) return;
    final updatedTree = currentTree.deleteBranch(branchName);
    state = state.copyWith(historyTree: updatedTree);
    axLog(LogDomain.editor, 'Deleted branch: $branchName');
  }
}
