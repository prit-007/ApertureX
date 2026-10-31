import 'dart:typed_data';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';

import '../../edit/active_image.dart';
import '../../edit/adjustment_layer.dart';
import '../../edit/node_editor.dart';
import '../../edit/recipe_controller.dart';
import '../../engine/engine.dart';
import '../../gallery/gallery_controller.dart' show gallerySourceProvider;
import '../../settings/ai_consent.dart';
import '../../viewport/canvas_transform.dart';
import '../../viewport/mask_peek.dart';
import 'color_grading_editor.dart';
import 'parameter_slider_row.dart';

/// Function signature for sky detection from photo bytes.
typedef SkyDetectorFn = Future<DetectedSky?> Function(Uint8List imageBytes);

/// Riverpod provider for sky detection, overridable in tests.
final skyDetectorProvider = Provider<SkyDetectorFn>((ref) {
  return (Uint8List bytes) async {
    final decoded = await AxEngine.decodeAnalysisProxy(bytes);
    return AxEngine.detectSky(
      decoded.rgba,
      width: decoded.width,
      height: decoded.height,
    );
  };
});

/// Function signature for subject segmentation into alpha mask.
typedef SubjectSegmenterFn = Future<Float32List?> Function(
  Uint8List imageBytes, {
  int targetWidth,
  int targetHeight,
});

/// Riverpod provider for subject segmentation, overridable in tests.
final subjectSegmenterProvider = Provider<SubjectSegmenterFn>((ref) {
  return (
    Uint8List bytes, {
    int targetWidth = 256,
    int targetHeight = 256,
  }) async {
    final decoded = await AxEngine.decodeAnalysisProxy(bytes);
    return AxEngine.segmentSubject(
      decoded.rgba,
      width: decoded.width,
      height: decoded.height,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
  };
});

/// Function signature for parametric subject detection.
typedef SubjectDetectorFn = Future<DetectedSubject?> Function(Uint8List imageBytes);

/// Riverpod provider for subject detection (parametric fallback), overridable in tests.
final subjectDetectorProvider = Provider<SubjectDetectorFn>((ref) {
  return (Uint8List bytes) async {
    final decoded = await AxEngine.decodeAnalysisProxy(bytes);
    return AxEngine.detectSubject(
      decoded.rgba,
      width: decoded.width,
      height: decoded.height,
    );
  };
});

/// Function signature for parametric face detection via YuNet.
typedef FaceDetectorFn = Future<DetectedFace?> Function(Uint8List imageBytes);

/// Riverpod provider for face detection (YuNet), overridable in tests.
final faceDetectorProvider = Provider<FaceDetectorFn>((ref) {
  return (Uint8List bytes) async {
    final decoded = await AxEngine.decodeAnalysisProxy(bytes);
    return AxEngine.detectFace(
      decoded.rgba,
      width: decoded.width,
      height: decoded.height,
    );
  };
});

/// Function signature for extracting an embedded depth map from original bytes.
typedef EmbeddedDepthExtractorFn = Future<EmbeddedDepthResult?> Function(
  Uint8List jpeg,
);

/// Riverpod provider for embedded depth extraction, overridable in tests.
final embeddedDepthExtractorProvider = Provider<EmbeddedDepthExtractorFn>((ref) {
  return (Uint8List bytes) => AxEngine.extractEmbeddedDepth(bytes);
});

/// Function signature for depth map estimation from RGBA, overridable in tests.
typedef DepthEstimatorFn = Future<Float32List> Function(Uint8List rgba, int width, int height);

/// Riverpod provider for on-device neural depth estimation, overridable in tests.
final depthEstimatorProvider = Provider<DepthEstimatorFn>((ref) {
  return (Uint8List rgba, int width, int height) => AxEngine.estimateDepthMap(
    rgba: rgba,
    width: width,
    height: height,
  );
});

/// Function signature for generating a false-color depth heatmap.
typedef DepthVisualizerFn = Future<Uint8List> Function(
  List<double> depth,
  int width,
  int height,
  double focalPoint,
  double focalRange,
);

/// Riverpod provider for depth-map visualizer (false-color heatmap), overridable in tests.
final depthVisualizerProvider = Provider<DepthVisualizerFn>((ref) {
  return (List<double> depth, int width, int height, double focalPoint,
          double focalRange) =>
      AxEngine.generateDepthVisualizerRgba(
        depth: depth,
        width: width,
        height: height,
        focalPoint: focalPoint,
        focalRange: focalRange,
      );
});

/// Notifier for configuring the active ML model path per task kind.
class ActiveMlModelNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<bool> setModel(String task, String path) async {
    final ok = await AxEngine.setActiveMlModel(task: task, path: path);
    state = ok;
    return ok;
  }
}

/// Riverpod provider for setting the active ML model (e.g. depth, segmentation, face).
final activeMlModelProvider =
    NotifierProvider<ActiveMlModelNotifier, bool>(ActiveMlModelNotifier.new);

/// Notifier tracking in-flight AI mask inference.
class AiMaskInferringNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setInferring(bool val) => state = val;
}

/// Riverpod state provider tracking in-flight AI mask inference.
final aiMaskInferringProvider =
    NotifierProvider<AiMaskInferringNotifier, bool>(AiMaskInferringNotifier.new);

/// Notifier tracking human-readable status for in-flight AI mask inference.
class AiMaskStatusMessageNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setMessage(String? msg) => state = msg;
}

/// Riverpod state provider tracking human-readable status for in-flight AI mask inference.
final aiMaskStatusMessageProvider =
    NotifierProvider<AiMaskStatusMessageNotifier, String?>(
  AiMaskStatusMessageNotifier.new,
);

/// Function signature for mask refinement from layer and photo bytes.
typedef MaskRefinerFn = Future<AdjustmentLayer?> Function(
  AdjustmentLayer layer,
  Uint8List imageBytes, {
  List<double> strokePoints,
  double brushRadius,
});

/// Riverpod provider for mask refinement via guided filter, overridable in tests.
final maskRefinerProvider = Provider<MaskRefinerFn>((ref) {
  return (
    AdjustmentLayer layer,
    Uint8List bytes, {
    List<double> strokePoints = const [],
    double brushRadius = 0.05,
  }) async {
    final decoded = await AxEngine.decodeAnalysisProxy(bytes);
    final refinedAlphas = await AxEngine.refineMask(
      rgba: decoded.rgba,
      width: decoded.width,
      height: decoded.height,
      maskKind: layer.maskKind.index,
      // Bitmap layers store only [w, h] in maskParams; the Rust contract
      // wants [w, h, alpha…] (2 + w*h floats) — expand via the bridge form.
      maskParams: layer.toBridgeMaskParams(),
      strokePoints: strokePoints,
      brushRadius: brushRadius,
    );
    return layer.withRefinedAlphas(refinedAlphas, decoded.width, decoded.height);
  };
});

/// Rubylith mask overlay display colors.
enum RubylithColor {
  red(Color(0xFFE53935), 'Red'),
  green(Color(0xFF43A047), 'Green'),
  blue(Color(0xFF1E88E5), 'Blue'),
  white(Color(0xFFFFFFFF), 'White');

  const RubylithColor(this.color, this.label);
  final Color color;
  final String label;
}

/// Settings for persistent Rubylith overlay bar (ADR 0013 / pro parity).
class RubylithOverlaySettings {
  const RubylithOverlaySettings({
    this.showOverlay = true,
    this.color = RubylithColor.red,
    this.opacity = 0.5,
  });

  final bool showOverlay;
  final RubylithColor color;
  final double opacity;

  RubylithOverlaySettings copyWith({
    bool? showOverlay,
    RubylithColor? color,
    double? opacity,
  }) => RubylithOverlaySettings(
    showOverlay: showOverlay ?? this.showOverlay,
    color: color ?? this.color,
    opacity: opacity ?? this.opacity,
  );
}

class RubylithOverlayNotifier extends Notifier<RubylithOverlaySettings> {
  @override
  RubylithOverlaySettings build() => const RubylithOverlaySettings();

  void toggleShowOverlay() => state = state.copyWith(showOverlay: !state.showOverlay);
  void setShowOverlay(bool value) => state = state.copyWith(showOverlay: value);
  void setColor(RubylithColor color) => state = state.copyWith(color: color);
  void setOpacity(double opacity) => state = state.copyWith(opacity: opacity);
}

final rubylithOverlayProvider =
    NotifierProvider<RubylithOverlayNotifier, RubylithOverlaySettings>(
  RubylithOverlayNotifier.new,
);

/// Local-adjustment (masking) controls: add analytic masks and manage the
/// layer stack. Masks are parametric, so no brush data is stored (#18).
/// Supports mask groups with Boolean Add/Subtract/Intersect coverage algebra (ADR 0013 / #92).
class MaskControls extends ConsumerWidget {
  const MaskControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final layers = recipe.layers;
    final maskGroups = recipe.maskGroups;
    final notifier = ref.read(recipeControllerProvider.notifier);
    final stylusOnly = ref.watch(stylusOnlyModeProvider);
    final nodeMode = ref.watch(nodeEditorProvider.select((s) => s.enabled));
    final selectedIndex = ref.watch(nodeEditorProvider.select((s) => s.selected));
    final groupIds = {for (final g in maskGroups) g.id};
    final isInferring = ref.watch(aiMaskInferringProvider);
    final scheme = Theme.of(context).colorScheme;

    final isEmpty = layers.isEmpty && maskGroups.isEmpty;

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // 1. Persistent Rubylith Overlay Bar
        const _RubylithOverlayBar(),

        // 2. Primary Action Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: Insets.xs),
          child: Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                key: const Key('mask-create-primary'),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary.withValues(alpha: 0.16),
                  foregroundColor: scheme.primary,
                  side: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
                ),
                onPressed: () => _showCreateMaskSheet(context, ref),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text(
                  '+ Create Mask',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('mask-new-group'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
                ),
                onPressed: () {
                  final gid = 'group_${DateTime.now().microsecondsSinceEpoch}';
                  final num = maskGroups.length + 1;
                  notifier.addMaskGroup(MaskGroup(id: gid, name: 'Mask $num'));
                },
                icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                label: const Text('New Group +', style: TextStyle(fontSize: 12)),
              ),
              OutlinedButton(
                key: const Key('edit-on-canvas'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: nodeMode ? scheme.primaryContainer : null,
                  foregroundColor: nodeMode ? scheme.onPrimaryContainer : null,
                  side: BorderSide(
                    color: nodeMode ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
                ),
                onPressed: () => ref.read(nodeEditorProvider.notifier).toggle(),
                child: Icon(nodeMode ? Icons.check : Icons.touch_app, size: 16),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: stylusOnly ? 'Touch mode' : 'Stylus mode',
                icon: Icon(Icons.gesture, size: 18, color: stylusOnly ? scheme.primary : null),
                onPressed: () => _toggleStylusOnly(ref, !stylusOnly),
              ),
            ],
          ),
        ),

        // 3. Categorized Creation Panel (Prompt & Grouped Hierarchy)
        if (isEmpty)
          _CreateMaskCategorizedSection(
            context: context,
            ref: ref,
            isInferring: isInferring,
            onAddMask: (kind, {inverted = false, exposure}) =>
                _addMask(context, ref, kind, inverted: inverted, exposure: exposure),
            onAddAiSubject: ({required inverted}) =>
                _addAiSubjectMask(context, ref, inverted: inverted),
            onAddAiFace: () => _addAiFaceMask(context, ref),
            onAddSky: () => _addSkyMask(context, ref),
            onAddDepthMap: () => _addDepthMapMask(context, ref),
            onToolTap: null,
          )
        else
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const Key('mask-add-tools-expansion'),
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: Insets.sm),
              childrenPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add_circle_outline, size: 18),
              title: const Text(
                'Add Mask Tool',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              children: [
                _CreateMaskCategorizedSection(
                  context: context,
                  ref: ref,
                  isInferring: isInferring,
                  onAddMask: (kind, {inverted = false, exposure}) =>
                      _addMask(context, ref, kind, inverted: inverted, exposure: exposure),
                  onAddAiSubject: ({required inverted}) =>
                      _addAiSubjectMask(context, ref, inverted: inverted),
                  onAddAiFace: () => _addAiFaceMask(context, ref),
                  onAddSky: () => _addSkyMask(context, ref),
                  onAddDepthMap: () => _addDepthMapMask(context, ref),
                  onToolTap: null,
                ),
              ],
            ),
          ),

        // Animated AI Progress Indicator (#83, #89, #96)
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: isInferring
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Container(
                    key: const Key('ai-mask-progress-banner'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                ref.watch(aiMaskStatusMessageProvider) ??
                                    'Processing with on-device AI… Please wait a moment',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(minHeight: 3),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        if (layers.isEmpty && maskGroups.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No local adjustments. Add a mask above.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),

        // --- MASK GROUPS (ADR 0013 / #92) ---
        for (final group in maskGroups)
          _buildGroupCard(
            context,
            ref,
            group: group,
            layers: layers,
            selectedIndex: selectedIndex,
            notifier: notifier,
          ),

        // --- UNGROUPED LAYERS (Backward-compatible / standalone) ---
        if (maskGroups.isNotEmpty && layers.any((l) => l.groupId == null || !groupIds.contains(l.groupId)))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'UNGROUPED MASKS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        for (var i = 0; i < layers.length; i++)
          if (layers[i].groupId == null || !groupIds.contains(layers[i].groupId)) ...[
            _buildLayerTile(
              context,
              ref,
              i: i,
              layer: layers[i],
              isSelected: i == selectedIndex,
              notifier: notifier,
              showJoinOp: false,
            ),
            if (i == selectedIndex)
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: _buildInlineCard(context, ref, i: i, layer: layers[i], notifier: notifier),
              ),
          ],
      ],
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    WidgetRef ref, {
    required MaskGroup group,
    required List<AdjustmentLayer> layers,
    required int? selectedIndex,
    required RecipeController notifier,
  }) {
    final theme = Theme.of(context);
    final memberIndices = [for (var i = 0; i < layers.length; i++) if (layers[i].groupId == group.id) i];

    return Card(
      key: Key('mask-group-${group.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Group Header
            Row(
              children: [
                _GroupThumbnail(group: group),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    group.name,
                    key: Key('group-title-${group.id}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                if (group.inverted) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Inverted',
                      style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  key: Key('group-visibility-${group.id}'),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  tooltip: group.amount > 0 ? 'Hide group' : 'Show group',
                  icon: Icon(
                    group.amount > 0 ? Icons.visibility : Icons.visibility_off,
                    color: group.amount > 0 ? null : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    notifier.updateMaskGroup(
                      group.copyWith(amount: group.amount > 0 ? 0.0 : 1.0),
                    );
                  },
                ),
                IconButton(
                  key: Key('group-invert-${group.id}'),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  tooltip: 'Invert Group Coverage',
                  icon: Icon(
                    group.inverted ? Icons.swap_horiz : Icons.swap_horizontal_circle_outlined,
                    color: group.inverted ? Colors.orange : null,
                    size: 20,
                  ),
                  onPressed: () => notifier.updateMaskGroup(group.copyWith(inverted: !group.inverted)),
                ),
                IconButton(
                  key: Key('group-delete-${group.id}'),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  tooltip: 'Delete Group and Members',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => notifier.removeMaskGroup(group.id),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Group-level Amount Slider (0..200%)
            _MaskSlider(
              label: 'Group Amt',
              sliderKey: Key('group-amount-${group.id}'),
              value: group.amount,
              min: 0.0,
              max: 2.0,
              displayValue: '${(group.amount * 100).round()}%',
              onChanged: (val) => notifier.updateMaskGroup(group.copyWith(amount: val)),
            ),

            // Group-level Light & Color Sliders
            _MaskSlider(
              label: 'Exposure',
              sliderKey: Key('group-exposure-${group.id}'),
              value: group.exposure,
              min: -2.0,
              max: 2.0,
              onChanged: (val) => notifier.updateMaskGroup(group.copyWith(exposure: val)),
            ),
            _MaskSlider(
              label: 'Contrast',
              sliderKey: Key('group-contrast-${group.id}'),
              value: group.contrast,
              min: -1.0,
              max: 1.0,
              onChanged: (val) => notifier.updateMaskGroup(group.copyWith(contrast: val)),
            ),
            _MaskSlider(
              label: 'Highlights',
              sliderKey: Key('group-highlights-${group.id}'),
              value: group.highlights,
              min: -1.0,
              max: 1.0,
              onChanged: (val) => notifier.updateMaskGroup(group.copyWith(highlights: val)),
            ),
            _MaskSlider(
              label: 'Shadows',
              sliderKey: Key('group-shadows-${group.id}'),
              value: group.shadows,
              min: -1.0,
              max: 1.0,
              onChanged: (val) => notifier.updateMaskGroup(group.copyWith(shadows: val)),
            ),
            _MaskSlider(
              label: 'Temp',
              sliderKey: Key('group-temp-${group.id}'),
              value: group.temperature,
              min: -1.0,
              max: 1.0,
              onChanged: (val) => notifier.updateMaskGroup(group.copyWith(temperature: val)),
            ),
            _MaskSlider(
              label: 'Tint',
              sliderKey: Key('group-tint-${group.id}'),
              value: group.tint,
              min: -1.0,
              max: 1.0,
              onChanged: (val) => notifier.updateMaskGroup(group.copyWith(tint: val)),
            ),
            _MaskSlider(
              label: 'Saturation',
              sliderKey: Key('group-saturation-${group.id}'),
              value: group.saturation,
              min: -1.0,
              max: 1.0,
              onChanged: (val) => notifier.updateMaskGroup(group.copyWith(saturation: val)),
            ),

            _MaskColorGradingSection(
              segmentedKey: Key('group-grade-zone-segmented-${group.id}'),
              hueKey: Key('group-grade-hue-${group.id}'),
              satKey: Key('group-grade-sat-${group.id}'),
              lumKey: Key('group-grade-lum-${group.id}'),
              blendingKey: Key('group-grade-blending-${group.id}'),
              balanceKey: Key('group-grade-balance-${group.id}'),
              shadowHue: group.gradeShadowHue,
              shadowSat: group.gradeShadowSat,
              shadowLum: group.gradeShadowLum,
              midHue: group.gradeMidHue,
              midSat: group.gradeMidSat,
              midLum: group.gradeMidLum,
              highlightHue: group.gradeHighlightHue,
              highlightSat: group.gradeHighlightSat,
              highlightLum: group.gradeHighlightLum,
              blending: group.gradeBlending,
              balance: group.gradeBalance,
              onZoneChanged: (zone, {hue, sat, lum}) {
                final updated = switch (zone) {
                  GradeWheelZone.shadows => group.copyWith(
                    gradeShadowHue: hue ?? group.gradeShadowHue,
                    gradeShadowSat: sat ?? group.gradeShadowSat,
                    gradeShadowLum: lum ?? group.gradeShadowLum,
                  ),
                  GradeWheelZone.midtones => group.copyWith(
                    gradeMidHue: hue ?? group.gradeMidHue,
                    gradeMidSat: sat ?? group.gradeMidSat,
                    gradeMidLum: lum ?? group.gradeMidLum,
                  ),
                  GradeWheelZone.highlights => group.copyWith(
                    gradeHighlightHue: hue ?? group.gradeHighlightHue,
                    gradeHighlightSat: sat ?? group.gradeHighlightSat,
                    gradeHighlightLum: lum ?? group.gradeHighlightLum,
                  ),
                };
                notifier.updateMaskGroup(updated);
              },
              onGlobalChanged: ({blending, balance}) {
                notifier.updateMaskGroup(
                  group.copyWith(
                    gradeBlending: blending ?? group.gradeBlending,
                    gradeBalance: balance ?? group.gradeBalance,
                  ),
                );
              },
            ),

            const Divider(height: 16),

            // Group Action Toolbar (Add / Subtract / Intersect)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PopupMenuButton<MaskKind>(
                  key: Key('group-add-${group.id}'),
                  tooltip: 'Add mask to group',
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: MaskKind.brush, child: Text('Brush')),
                    PopupMenuItem(value: MaskKind.linear, child: Text('Linear Gradient')),
                    PopupMenuItem(value: MaskKind.radial, child: Text('Radial Gradient')),
                    PopupMenuItem(value: MaskKind.subject, child: Text('Subject')),
                    PopupMenuItem(value: MaskKind.sky, child: Text('Sky')),
                    PopupMenuItem(value: MaskKind.luminance, child: Text('Luminance')),
                    PopupMenuItem(value: MaskKind.colorRange, child: Text('Color Range')),
                    PopupMenuItem(value: MaskKind.autoBrush, child: Text('Auto Brush')),
                    PopupMenuItem(value: MaskKind.depthRange, child: Text('Depth Range')),
                  ],
                  onSelected: (kind) => _addMask(context, ref, kind, groupId: group.id, joinOp: MaskJoinOp.add),
                  child: const Chip(
                    avatar: Icon(Icons.add, size: 14),
                    label: Text('Add', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuButton<MaskKind>(
                  key: Key('group-subtract-${group.id}'),
                  tooltip: 'Subtract mask from group',
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: MaskKind.brush, child: Text('Brush')),
                    PopupMenuItem(value: MaskKind.linear, child: Text('Linear Gradient')),
                    PopupMenuItem(value: MaskKind.radial, child: Text('Radial Gradient')),
                    PopupMenuItem(value: MaskKind.subject, child: Text('Subject')),
                    PopupMenuItem(value: MaskKind.sky, child: Text('Sky')),
                    PopupMenuItem(value: MaskKind.luminance, child: Text('Luminance')),
                    PopupMenuItem(value: MaskKind.colorRange, child: Text('Color Range')),
                    PopupMenuItem(value: MaskKind.autoBrush, child: Text('Auto Brush')),
                    PopupMenuItem(value: MaskKind.depthRange, child: Text('Depth Range')),
                  ],
                  onSelected: (kind) => _addMask(context, ref, kind, groupId: group.id, joinOp: MaskJoinOp.subtract),
                  child: const Chip(
                    avatar: Icon(Icons.remove, size: 14),
                    label: Text('Subtract', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuButton<MaskKind>(
                  key: Key('group-intersect-${group.id}'),
                  tooltip: 'Intersect mask with group',
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: MaskKind.brush, child: Text('Brush')),
                    PopupMenuItem(value: MaskKind.linear, child: Text('Linear Gradient')),
                    PopupMenuItem(value: MaskKind.radial, child: Text('Radial Gradient')),
                    PopupMenuItem(value: MaskKind.subject, child: Text('Subject')),
                    PopupMenuItem(value: MaskKind.sky, child: Text('Sky')),
                    PopupMenuItem(value: MaskKind.luminance, child: Text('Luminance')),
                    PopupMenuItem(value: MaskKind.colorRange, child: Text('Color Range')),
                    PopupMenuItem(value: MaskKind.autoBrush, child: Text('Auto Brush')),
                    PopupMenuItem(value: MaskKind.depthRange, child: Text('Depth Range')),
                  ],
                  onSelected: (kind) => _addMask(context, ref, kind, groupId: group.id, joinOp: MaskJoinOp.intersect),
                  child: const Chip(
                    avatar: Icon(Icons.join_inner, size: 14),
                    label: Text('Intersect', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),

            if (memberIndices.isNotEmpty) const SizedBox(height: 8),

            // Members inside this group
            for (final i in memberIndices) ...[
              _buildLayerTile(
                context,
                ref,
                i: i,
                layer: layers[i],
                isSelected: i == selectedIndex,
                notifier: notifier,
                showJoinOp: true,
                // Grouped members carry no grade of their own (ADR 0013) —
                // show the group's EV, which is what actually renders.
                evOverride: group.exposure,
              ),
              if (i == selectedIndex)
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: _buildInlineCard(
                    context,
                    ref,
                    i: i,
                    layer: layers[i],
                    notifier: notifier,
                    showGradeControls: false,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLayerTile(
    BuildContext context,
    WidgetRef ref, {
    required int i,
    required AdjustmentLayer layer,
    required bool isSelected,
    required RecipeController notifier,
    required bool showJoinOp,
    double? evOverride,
  }) {
    final ev = evOverride ?? layer.exposure;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          dense: true,
          selected: isSelected,
          leading: _MaskThumbnail(
            kind: layer.maskKind,
            isSelected: isSelected,
            inverted: layer.inverted,
          ),
          title: Text(
            '${layer.maskKind.name.toUpperCase()} layer ${i + 1}  '
            'EV ${ev >= 0 ? '+' : ''}${ev.toStringAsFixed(2)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (layer.inverted)
                const Text(
                  'Inverted (Reversed)',
                  style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                ),
              if (layer.aiIntent != null || showJoinOp)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (layer.aiIntent != null) ...[
                        Tooltip(
                          message: 'AI masks run on-device; no image leaves your device',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, size: 10),
                                const SizedBox(width: 2),
                                Text(
                                  'AI ${layer.aiIntent} ✓',
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (showJoinOp) ...[
                        ChoiceChip(
                          key: Key('mask-join-add-$i'),
                          label: const Text('+', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          selected: layer.joinOp == MaskJoinOp.add,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          showCheckmark: false,
                          onSelected: (val) {
                            if (val) notifier.updateLayerAt(i, layer.copyWith(joinOp: MaskJoinOp.add));
                          },
                        ),
                        ChoiceChip(
                          key: Key('mask-join-subtract-$i'),
                          label: const Text('-', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          selected: layer.joinOp == MaskJoinOp.subtract,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          showCheckmark: false,
                          onSelected: (val) {
                            if (val) notifier.updateLayerAt(i, layer.copyWith(joinOp: MaskJoinOp.subtract));
                          },
                        ),
                        ChoiceChip(
                          key: Key('mask-join-intersect-$i'),
                          label: const Text('⋂', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          selected: layer.joinOp == MaskJoinOp.intersect,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          showCheckmark: false,
                          onSelected: (val) {
                            if (val) notifier.updateLayerAt(i, layer.copyWith(joinOp: MaskJoinOp.intersect));
                          },
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          onTap: () {
            ref.read(nodeEditorProvider.notifier).select(i);
            ref.read(nodeEditorProvider.notifier).enable();
          },
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: Key('mask-visibility-$i'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                tooltip: layer.amount > 0 ? 'Hide mask' : 'Show mask',
                icon: Icon(
                  layer.amount > 0 ? Icons.visibility : Icons.visibility_off,
                  size: 18,
                  color: layer.amount > 0 ? null : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  notifier.updateLayerAt(i, layer.copyWith(amount: layer.amount > 0 ? 0.0 : 1.0));
                },
              ),
              IconButton(
                key: Key('mask-refine-$i'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                tooltip: 'Refine mask edges',
                icon: const Icon(Icons.auto_fix_high, size: 18),
                onPressed: () async {
                  final bytes = ref.read(activeImageBytesProvider);
                  if (bytes == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No photo loaded to refine mask')),
                    );
                    return;
                  }
                  final refiner = ref.read(maskRefinerProvider);
                  final refined = await refiner(layer, bytes);
                  if (refined != null) {
                    notifier.updateLayerAt(i, refined);
                    HapticFeedback.selectionClick();
                  }
                },
              ),
              IconButton(
                key: Key('mask-invert-$i'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                tooltip: 'Invert / Reverse mask',
                icon: Icon(
                  layer.inverted ? Icons.swap_horiz : Icons.swap_horizontal_circle_outlined,
                  size: 18,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  notifier.updateLayerAt(i, layer.copyWith(inverted: !layer.inverted));
                },
              ),
              IconButton(
                key: Key('mask-duplicate-$i'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                tooltip: 'Duplicate mask',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  notifier.addLayer(layer.copyWith());
                },
              ),
              IconButton(
                key: Key('mask-delete-$i'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                tooltip: 'Remove layer',
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  notifier.removeLayerAt(i);
                  if (ref.read(nodeEditorProvider).selected == i) {
                    ref.read(nodeEditorProvider.notifier).select(null);
                  }
                },
              ),
            ],
          ),
      ),
      ),
    );
  }

  Widget _buildInlineCard(
    BuildContext context,
    WidgetRef ref, {
    required int i,
    required AdjustmentLayer layer,
    required RecipeController notifier,
    bool showGradeControls = true,
  }) {
    final isInferring = ref.watch(aiMaskInferringProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    key: const Key('mask-inline-invert'),
                    label: const Text('Invert', style: TextStyle(fontSize: 11)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    selected: layer.inverted,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onSelected: (val) {
                      notifier.updateLayerAt(i, layer.copyWith(inverted: val));
                    },
                  ),
                  if (layer.maskKind == MaskKind.brush) ...[
                    ChoiceChip(
                      key: const Key('mask-inline-brush-paint'),
                      label: const Text('Paint', style: TextStyle(fontSize: 11)),
                      selected: !ref.watch(nodeEditorProvider.select((s) => s.eraserMode)) &&
                          !ref.watch(nodeEditorProvider.select((s) => s.refineBrushMode)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      showCheckmark: false,
                      onSelected: (val) {
                        if (val) {
                          ref.read(nodeEditorProvider.notifier).setEraserMode(false);
                          ref.read(nodeEditorProvider.notifier).setRefineBrushMode(false);
                        }
                      },
                    ),
                    ChoiceChip(
                      key: const Key('mask-inline-brush-erase'),
                      label: const Text('Erase', style: TextStyle(fontSize: 11)),
                      selected: ref.watch(nodeEditorProvider.select((s) => s.eraserMode)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      showCheckmark: false,
                      onSelected: (val) {
                        if (val) ref.read(nodeEditorProvider.notifier).setEraserMode(true);
                      },
                    ),
                    FilterChip(
                      key: const Key('mask-inline-auto-mask'),
                      label: const Text('Auto Mask', style: TextStyle(fontSize: 11)),
                      selected: layer.maskKind == MaskKind.autoBrush,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        notifier.updateLayerAt(
                          i,
                          layer.copyWith(maskKind: val ? MaskKind.autoBrush : MaskKind.brush),
                        );
                      },
                    ),
                  ] else ...[
                    ActionChip(
                      key: const Key('mask-subtract'),
                      avatar: const Icon(Icons.remove_circle_outline, size: 14),
                      label: const Text('Subtract', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        notifier.updateLayerAt(i, layer.copyWith(inverted: true));
                      },
                    ),
                  ],
                  ChoiceChip(
                    key: const Key('mask-inline-refine-brush'),
                    label: const Text('Refine Brush', style: TextStyle(fontSize: 11)),
                    selected: ref.watch(nodeEditorProvider.select((s) => s.refineBrushMode)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    showCheckmark: false,
                    onSelected: (val) {
                      if (val) {
                        ref.read(nodeEditorProvider.notifier).setRefineBrushMode(true);
                        ref.read(nodeEditorProvider.notifier).enable();
                      } else {
                        ref.read(nodeEditorProvider.notifier).setRefineBrushMode(false);
                      }
                    },
                  ),
                  ActionChip(
                    key: const Key('mask-inline-refine-edge'),
                    avatar: const Icon(Icons.auto_fix_high, size: 14),
                    label: const Text('Refine Edge', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: isInferring
                        ? null
                        : () async {
                            final bytes = ref.read(activeImageBytesProvider);
                            if (bytes == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No photo loaded to refine mask')),
                              );
                              return;
                            }
                            ref.read(aiMaskInferringProvider.notifier).setInferring(true);
                            ref.read(aiMaskStatusMessageProvider.notifier).setMessage(
                                'Refining mask edges with guided filter… Please wait a moment');
                            try {
                              final refiner = ref.read(maskRefinerProvider);
                              final refined = await refiner(layer, bytes);
                              if (refined != null) {
                                notifier.updateLayerAt(i, refined);
                                HapticFeedback.mediumImpact();
                              }
                            } finally {
                              ref.read(aiMaskInferringProvider.notifier).setInferring(false);
                              ref.read(aiMaskStatusMessageProvider.notifier).setMessage(null);
                            }
                          },
                  ),
                  ActionChip(
                    key: const Key('mask-inline-duplicate'),
                    avatar: const Icon(Icons.copy, size: 14),
                    label: const Text('Duplicate', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: () => notifier.addLayer(layer.copyWith()),
                  ),
                  if (layer.maskKind == MaskKind.luminance)
                    ActionChip(
                      key: const Key('mask-luma-eyedropper'),
                      avatar: const Icon(Icons.colorize, size: 14),
                      label: const Text('Sample Luma', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        ref.read(nodeEditorProvider.notifier).enable();
                        ref.read(nodeEditorProvider.notifier).select(i);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tap photo to sample luminance band'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  if (layer.maskKind == MaskKind.brush && layer.brushPointCount > 0)
                    TextButton.icon(
                      key: const Key('mask-inline-brush-clear'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.clear, size: 14),
                      label: const Text('Clear', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        notifier.updateLayerAt(i, layer.withClearedStrokes());
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'EV ${layer.exposure >= 0 ? '+' : ''}${layer.exposure.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (layer.maskKind == MaskKind.brush || layer.maskKind == MaskKind.autoBrush) ...[
                _MaskSlider(
                  label: 'Brush Size',
                  sliderKey: const Key('mask-inline-brush-size-slider'),
                  value: layer.brushRadius,
                  min: 0.01,
                  max: 0.5,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.withBrushRadius(val)),
                ),
                _MaskSlider(
                  label: 'Feather',
                  sliderKey: const Key('mask-inline-brush-feather-slider'),
                  value: layer.brushFeather,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.withBrushFeather(val)),
                ),
                _MaskSlider(
                  label: 'Flow',
                  sliderKey: const Key('mask-inline-brush-flow-slider'),
                  value: layer.amount.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  displayValue: '${(layer.amount.clamp(0.0, 1.0) * 100).round()}%',
                  onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(amount: val)),
                ),
              ],
              if (layer.maskKind == MaskKind.sky) ...[
                _MaskSlider(
                  label: 'Horizon',
                  sliderKey: const Key('mask-inline-sky-horizon-slider'),
                  value: layer.skyHorizon,
                  min: 0.05,
                  max: 0.95,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.withSkyHorizon(val)),
                ),
                _MaskSlider(
                  label: 'Feather',
                  sliderKey: const Key('mask-inline-sky-feather-slider'),
                  value: layer.skyFeather,
                  min: 0.01,
                  max: 0.5,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.withSkyFeather(val)),
                ),
                _MaskSlider(
                  label: 'Blue Weight',
                  sliderKey: const Key('mask-inline-sky-blue-weight-slider'),
                  value: layer.skyBlueWeight,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.withSkyBlueWeight(val)),
                ),
              ],
              if (layer.maskKind == MaskKind.luminance) ...[
                const SizedBox(height: 6),
                Text(
                  'ANSEL ADAMS ZONE SYSTEM',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var z = 0; z <= 10; z++) ...[
                        ChoiceChip(
                          key: Key('mask-zone-chip-$z'),
                          label: Text(
                            _zoneRoman(z),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          selected: layer.lumaZone == z,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          showCheckmark: false,
                          onSelected: (selected) {
                            if (selected) {
                              notifier.updateLayerAt(i, layer.withZone(z));
                            }
                          },
                        ),
                        if (z < 10) const SizedBox(width: 4),
                      ],
                    ],
                  ),
                ),
                _MaskSlider(
                  label: 'Min Luma',
                  sliderKey: const Key('mask-inline-luma-min-slider'),
                  value: layer.lumaMin,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.withLumaBand(min: val)),
                ),
                _MaskSlider(
                  label: 'Max Luma',
                  sliderKey: const Key('mask-inline-luma-max-slider'),
                  value: layer.lumaMax,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.withLumaBand(max: val)),
                ),
                _MaskSlider(
                  label: 'Feather',
                  sliderKey: const Key('mask-inline-luma-feather-slider'),
                  value: layer.lumaFeatherLo,
                  min: 0.01,
                  max: 0.5,
                  onChanged: (val) => notifier.updateLayerAt(
                    i,
                    layer.withLumaBand(featherLo: val, featherHi: val),
                  ),
                ),
              ],
              if (layer.maskKind == MaskKind.colorRange) ...[
                const SizedBox(height: 6),
                Text(
                  'COLOR RANGE MASK',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                _MaskSlider(
                  label: 'Target Hue',
                  sliderKey: const Key('mask-inline-color-hue-slider'),
                  value: layer.colorRangeTargetHue,
                  min: 0.0,
                  max: 360.0,
                  displayValue: '${layer.colorRangeTargetHue.round()}°',
                  onChanged: (val) => notifier.updateLayerAt(
                    i,
                    layer.withColorRange(targetHue: val),
                  ),
                ),
                _MaskSlider(
                  label: 'Hue Width',
                  sliderKey: const Key('mask-inline-color-width-slider'),
                  value: layer.colorRangeHueWidth,
                  min: 0.0,
                  max: 180.0,
                  displayValue: '${layer.colorRangeHueWidth.round()}°',
                  onChanged: (val) => notifier.updateLayerAt(
                    i,
                    layer.withColorRange(hueWidth: val),
                  ),
                ),
                _MaskSlider(
                  label: 'Sat Min',
                  sliderKey: const Key('mask-inline-color-sat-min-slider'),
                  value: layer.colorRangeSatMin,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(
                    i,
                    layer.withColorRange(satMin: val),
                  ),
                ),
                _MaskSlider(
                  label: 'Sat Max',
                  sliderKey: const Key('mask-inline-color-sat-max-slider'),
                  value: layer.colorRangeSatMax,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(
                    i,
                    layer.withColorRange(satMax: val),
                  ),
                ),
                _MaskSlider(
                  label: 'Lum Min',
                  sliderKey: const Key('mask-inline-color-lum-min-slider'),
                  value: layer.colorRangeLumMin,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(
                    i,
                    layer.withColorRange(lumMin: val),
                  ),
                ),
                _MaskSlider(
                  label: 'Lum Max',
                  sliderKey: const Key('mask-inline-color-lum-max-slider'),
                  value: layer.colorRangeLumMax,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(
                    i,
                    layer.withColorRange(lumMax: val),
                  ),
                ),
                _MaskSlider(
                  label: 'Softness',
                  sliderKey: const Key('mask-inline-color-softness-slider'),
                  value: layer.colorRangeSoftness,
                  min: 0.0,
                  max: 0.5,
                  onChanged: (val) => notifier.updateLayerAt(
                    i,
                    layer.withColorRange(softness: val),
                  ),
                ),
                ActionChip(
                  key: const Key('mask-inline-color-eyedropper'),
                  avatar: const Icon(Icons.color_lens, size: 14),
                  label: const Text('Sample Color', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    ref.read(nodeEditorProvider.notifier).enable();
                    ref.read(nodeEditorProvider.notifier).select(i);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tap photo to sample target color'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 6),
              _MaskSlider(
                label: 'Amount',
                sliderKey: const Key('mask-inline-amount-slider'),
                value: layer.amount,
                min: 0.0,
                max: 2.0,
                displayValue: '${(layer.amount * 100).round()}%',
                onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(amount: val)),
              ),
              const SizedBox(height: 6),
              if (showGradeControls) ...[
                Text(
                  'LIGHT CONTROLS',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                _MaskSlider(
                  label: 'Exposure',
                  sliderKey: const Key('mask-inline-exposure-slider'),
                  value: layer.exposure,
                  min: -2.0,
                  max: 2.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(exposure: val)),
                ),
                _MaskSlider(
                  label: 'Contrast',
                  sliderKey: const Key('mask-inline-contrast-slider'),
                  value: layer.contrast,
                  min: -1.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(contrast: val)),
                ),
                _MaskSlider(
                  label: 'Highlights',
                  sliderKey: const Key('mask-inline-highlights-slider'),
                  value: layer.highlights,
                  min: -1.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(highlights: val)),
                ),
                _MaskSlider(
                  label: 'Shadows',
                  sliderKey: const Key('mask-inline-shadows-slider'),
                  value: layer.shadows,
                  min: -1.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(shadows: val)),
                ),
                const SizedBox(height: 6),
                Text(
                  'COLOR CONTROLS',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                _MaskSlider(
                  label: 'Temp',
                  sliderKey: const Key('mask-inline-temp-slider'),
                  value: layer.temperature,
                  min: -1.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(temperature: val)),
                ),
                _MaskSlider(
                  label: 'Tint',
                  sliderKey: const Key('mask-inline-tint-slider'),
                  value: layer.tint,
                  min: -1.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(tint: val)),
                ),
                _MaskSlider(
                  label: 'Saturation',
                  sliderKey: const Key('mask-inline-saturation-slider'),
                  value: layer.saturation,
                  min: -1.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(saturation: val)),
                ),
                _MaskColorGradingSection(
                  segmentedKey: const Key('mask-grade-zone-segmented'),
                  hueKey: const Key('mask-inline-grade-hue-slider'),
                  satKey: const Key('mask-inline-grade-sat-slider'),
                  lumKey: const Key('mask-inline-grade-lum-slider'),
                  blendingKey: const Key('mask-inline-grade-blending-slider'),
                  balanceKey: const Key('mask-inline-grade-balance-slider'),
                  shadowHue: layer.gradeShadowHue,
                  shadowSat: layer.gradeShadowSat,
                  shadowLum: layer.gradeShadowLum,
                  midHue: layer.gradeMidHue,
                  midSat: layer.gradeMidSat,
                  midLum: layer.gradeMidLum,
                  highlightHue: layer.gradeHighlightHue,
                  highlightSat: layer.gradeHighlightSat,
                  highlightLum: layer.gradeHighlightLum,
                  blending: layer.gradeBlending,
                  balance: layer.gradeBalance,
                  onZoneChanged: (zone, {hue, sat, lum}) {
                    final updated = switch (zone) {
                      GradeWheelZone.shadows => layer.copyWith(
                        gradeShadowHue: hue ?? layer.gradeShadowHue,
                        gradeShadowSat: sat ?? layer.gradeShadowSat,
                        gradeShadowLum: lum ?? layer.gradeShadowLum,
                      ),
                      GradeWheelZone.midtones => layer.copyWith(
                        gradeMidHue: hue ?? layer.gradeMidHue,
                        gradeMidSat: sat ?? layer.gradeMidSat,
                        gradeMidLum: lum ?? layer.gradeMidLum,
                      ),
                      GradeWheelZone.highlights => layer.copyWith(
                        gradeHighlightHue: hue ?? layer.gradeHighlightHue,
                        gradeHighlightSat: sat ?? layer.gradeHighlightSat,
                        gradeHighlightLum: lum ?? layer.gradeHighlightLum,
                      ),
                    };
                    notifier.updateLayerAt(i, updated);
                  },
                  onGlobalChanged: ({blending, balance}) {
                    notifier.updateLayerAt(
                      i,
                      layer.copyWith(
                        gradeBlending: blending ?? layer.gradeBlending,
                        gradeBalance: balance ?? layer.gradeBalance,
                      ),
                    );
                  },
                ),
              ] else ...[
                Text(
                  'Graded on the group card above',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addAiSubjectMask(
    BuildContext context,
    WidgetRef ref, {
    bool inverted = false,
  }) async {
    final bytes = ref.read(activeImageBytesProvider);
    if (bytes == null) {
      _addMask(
        context,
        ref,
        MaskKind.subject,
        inverted: inverted,
        exposure: inverted ? -0.4 : 0.5,
      );
      return;
    }

    // 1. Consent check
    final consent =
        await ref.read(aiConsentProvider.notifier).requestConsentDialog(context);
    if (!consent) {
      if (context.mounted) {
        _addMask(
          context,
          ref,
          MaskKind.subject,
          inverted: inverted,
          exposure: inverted ? -0.4 : 0.5,
        );
      }
      return;
    }

    // 2. Segmenter with progress & cancellation handling
    ref.read(aiMaskInferringProvider.notifier).setInferring(true);
    ref.read(aiMaskStatusMessageProvider.notifier).setMessage(inverted
        ? 'Segmenting background on-device… Please wait a moment'
        : 'Finding subject on-device… Please wait a moment');
    try {
      final segmenter = ref.read(subjectSegmenterProvider);
      final alphas =
          await segmenter(bytes, targetWidth: 256, targetHeight: 256);
      if (alphas != null && alphas.isNotEmpty) {
        final notifier = ref.read(recipeControllerProvider.notifier);
        final layers = ref.read(recipeControllerProvider).recipe.layers;
        final idx = layers.length;
        notifier.addLayer(
          AdjustmentLayer.bitmap(
            width: 256,
            height: 256,
            alphas: alphas,
            inverted: inverted,
            exposure: inverted ? -0.4 : 0.5,
            aiIntent: inverted ? 'background' : 'subject',
          ),
        );
        ref.read(nodeEditorProvider.notifier).enable();
        ref.read(nodeEditorProvider.notifier).select(idx);
        HapticFeedback.selectionClick();
        return;
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI segmentation failed; using fallback subject mask'),
          ),
        );
      }
    } finally {
      ref.read(aiMaskInferringProvider.notifier).setInferring(false);
      ref.read(aiMaskStatusMessageProvider.notifier).setMessage(null);
    }

    // 3. Fallback path
    if (context.mounted) {
      _addMask(
        context,
        ref,
        MaskKind.subject,
        inverted: inverted,
        exposure: inverted ? -0.4 : 0.5,
      );
    }
  }

  Future<void> _addAiFaceMask(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bytes = ref.read(activeImageBytesProvider);
    if (bytes == null) {
      _addMask(
        context,
        ref,
        MaskKind.radial,
        exposure: 0.35,
      );
      return;
    }

    // 1. Consent check
    final consent =
        await ref.read(aiConsentProvider.notifier).requestConsentDialog(context);
    if (!consent) {
      if (context.mounted) {
        _addMask(
          context,
          ref,
          MaskKind.radial,
          exposure: 0.35,
        );
      }
      return;
    }

    // 2. Face detection with progress
    ref.read(aiMaskInferringProvider.notifier).setInferring(true);
    ref.read(aiMaskStatusMessageProvider.notifier).setMessage(
        'Detecting portrait face on-device… Please wait a moment');
    try {
      final detector = ref.read(faceDetectorProvider);
      final face = await detector(bytes);
      if (face != null) {
        final notifier = ref.read(recipeControllerProvider.notifier);
        final layers = ref.read(recipeControllerProvider).recipe.layers;
        final idx = layers.length;
        notifier.addLayer(
          AdjustmentLayer(
            maskKind: MaskKind.radial,
            maskParams: [
              face.cx.clamp(0.05, 0.95),
              face.cy.clamp(0.05, 0.95),
              (face.rx * 1.15).clamp(0.04, 0.45),
              (face.ry * 1.25).clamp(0.05, 0.50),
              0.35,
            ],
            exposure: 0.35,
            aiIntent: 'face',
          ),
        );
        ref.read(nodeEditorProvider.notifier).enable();
        ref.read(nodeEditorProvider.notifier).select(idx);
        HapticFeedback.selectionClick();
        return;
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face detection failed; using fallback face mask'),
          ),
        );
      }
    } finally {
      ref.read(aiMaskInferringProvider.notifier).setInferring(false);
      ref.read(aiMaskStatusMessageProvider.notifier).setMessage(null);
    }

    // 3. Fallback path
    if (context.mounted) {
      _addMask(
        context,
        ref,
        MaskKind.radial,
        exposure: 0.35,
      );
    }
  }

  Future<void> _addSkyMask(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(recipeControllerProvider.notifier);
    final layers = ref.read(recipeControllerProvider).recipe.layers;
    final idx = layers.length;
    var horizon = 0.5;
    var feather = 0.15;
    var blueWeight = 0.6;

    final bytes = ref.read(activeImageBytesProvider);
    if (bytes != null) {
      ref.read(aiMaskInferringProvider.notifier).setInferring(true);
      ref.read(aiMaskStatusMessageProvider.notifier).setMessage(
          'Detecting sky boundary… Please wait a moment');
      try {
        final detector = ref.read(skyDetectorProvider);
        final detected = await detector(bytes);
        if (detected != null) {
          horizon = detected.horizonY;
          feather = detected.feather;
          blueWeight = detected.blueWeight;
        }
      } catch (_) {
        // Fallback to default params
      } finally {
        ref.read(aiMaskInferringProvider.notifier).setInferring(false);
        ref.read(aiMaskStatusMessageProvider.notifier).setMessage(null);
      }
    }

    notifier.addLayer(
      AdjustmentLayer(
        maskKind: MaskKind.sky,
        maskParams: [horizon, feather, blueWeight],
        highlights: -0.6,
        saturation: 0.2,
        aiIntent: 'sky',
      ),
    );
    ref.read(nodeEditorProvider.notifier).enable();
    ref.read(nodeEditorProvider.notifier).select(idx);
  }

  Future<void> _addDepthMapMask(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(recipeControllerProvider.notifier);
    final layers = ref.read(recipeControllerProvider).recipe.layers;
    Uint8List? bytes = ref.read(activeImageBytesProvider);
    final asset = ref.read(currentEditingAssetProvider);
    if (asset != null) {
      try {
        final original =
            await ref.read(gallerySourceProvider).loadImage(asset.id);
        if (original.isNotEmpty) bytes = original;
      } catch (_) {
        // Fall back to the preview bytes when the original is unavailable.
      }
    }
    if (!context.mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No photo loaded for depth extraction')),
      );
      return;
    }
    ref.read(aiMaskInferringProvider.notifier).setInferring(true);
    ref.read(aiMaskStatusMessageProvider.notifier).setMessage(
        'Extracting portrait depth map… Please wait a moment');
    try {
      final depthResult =
          await ref.read(embeddedDepthExtractorProvider)(bytes);
      if (depthResult != null) {
        final alphas = depthResult.depth.map((b) => b / 255.0).toList();
        final idx = layers.length;
        notifier.addLayer(
          AdjustmentLayer.bitmap(
            width: depthResult.width,
            height: depthResult.height,
            alphas: alphas,
            exposure: 0.3,
            aiIntent: 'depth',
          ),
        );
        ref.read(nodeEditorProvider.notifier).enable();
        ref.read(nodeEditorProvider.notifier).select(idx);
        HapticFeedback.selectionClick();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Loaded embedded portrait depth mask')),
          );
        }
      } else {
        ref.read(aiMaskStatusMessageProvider.notifier).setMessage(
            'Synthesizing AI monocular depth map…');
        final decoded = await AxEngine.decodeAnalysisProxy(bytes);
        final estimated = await ref.read(depthEstimatorProvider)(
          decoded.rgba,
          decoded.width,
          decoded.height,
        );
        final idx = layers.length;
        notifier.addLayer(
          AdjustmentLayer.bitmap(
            width: decoded.width,
            height: decoded.height,
            alphas: estimated.toList(),
            exposure: 0.3,
            aiIntent: 'depth',
          ),
        );
        ref.read(nodeEditorProvider.notifier).enable();
        ref.read(nodeEditorProvider.notifier).select(idx);
        HapticFeedback.selectionClick();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Generated AI neural depth mask')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate depth mask')),
        );
      }
    } finally {
      ref.read(aiMaskInferringProvider.notifier).setInferring(false);
      ref.read(aiMaskStatusMessageProvider.notifier).setMessage(null);
    }
  }

  void _showCreateMaskSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (modalCtx) {
        final isInferring = ref.watch(aiMaskInferringProvider);
        return Padding(
          padding: Insets.sheet,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add New Mask',
                      style: Theme.of(modalCtx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(modalCtx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.xs),
                _CreateMaskCategorizedSection(
                  context: modalCtx,
                  ref: ref,
                  isInferring: isInferring,
                  onAddMask: (kind, {inverted = false, exposure}) =>
                      _addMask(context, ref, kind, inverted: inverted, exposure: exposure),
                  onAddAiSubject: ({required inverted}) =>
                      _addAiSubjectMask(context, ref, inverted: inverted),
                  onAddAiFace: () => _addAiFaceMask(context, ref),
                  onAddSky: () => _addSkyMask(context, ref),
                  onAddDepthMap: () => _addDepthMapMask(context, ref),
                  onToolTap: () => Navigator.of(modalCtx).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addMask(
    BuildContext context,
    WidgetRef ref,
    MaskKind kind, {
    String? groupId,
    MaskJoinOp joinOp = MaskJoinOp.add,
    bool inverted = false,
    double? exposure,
  }) {
    final notifier = ref.read(recipeControllerProvider.notifier);
    final transform = ref.read(canvasTransformProvider);
    final center = transform?.viewportCenterNormalized() ?? const Offset(0.5, 0.5);
    final halfSpan = (0.25 / (transform?.scale ?? 1.0)).clamp(0.06, 0.35);
    final p0y = (center.dy - halfSpan).clamp(0.02, 0.98);
    final p1y = (center.dy + halfSpan).clamp(0.02, 0.98);
    final rx = (0.25 / (transform?.scale ?? 1.0)).clamp(0.05, 0.4);
    final ry = rx * (transform?.aspect ?? 1.0);

    final AdjustmentLayer layer = switch (kind) {
      MaskKind.brush => AdjustmentLayer(
        maskKind: MaskKind.brush,
        maskParams: const [0.06, 0.25, 0],
        inverted: inverted,
        groupId: groupId,
        joinOp: joinOp,
        exposure: exposure ?? 0.6,
      ),
      MaskKind.linear => AdjustmentLayer(
        maskKind: MaskKind.linear,
        maskParams: [center.dx, p0y, center.dx, p1y],
        inverted: inverted,
        groupId: groupId,
        joinOp: joinOp,
        exposure: exposure ?? 0.6,
      ),
      MaskKind.radial => AdjustmentLayer(
        maskKind: MaskKind.radial,
        maskParams: [center.dx, center.dy, rx, ry, 0.3],
        inverted: inverted,
        groupId: groupId,
        joinOp: joinOp,
        exposure: exposure ?? 0.7,
      ),
      MaskKind.subject => AdjustmentLayer(
        maskKind: MaskKind.subject,
        maskParams: [center.dx, center.dy, 0.28, 0.38, 0.25],
        inverted: inverted,
        groupId: groupId,
        joinOp: joinOp,
        exposure: exposure ?? (inverted ? -0.4 : 0.5),
      ),
      MaskKind.sky => AdjustmentLayer(
        maskKind: MaskKind.sky,
        maskParams: const [0.5, 0.15, 0.6],
        inverted: inverted,
        groupId: groupId,
        joinOp: joinOp,
        highlights: -0.6,
        saturation: 0.2,
      ),
      MaskKind.luminance => AdjustmentLayer(
        maskKind: MaskKind.luminance,
        maskParams: const [0, 0.4],
        inverted: inverted,
        groupId: groupId,
        joinOp: joinOp,
        exposure: exposure ?? 0.8,
      ),
      MaskKind.bitmap => AdjustmentLayer(
        maskKind: MaskKind.brush,
        maskParams: const [0.06, 0.25, 0],
        inverted: inverted,
        groupId: groupId,
        joinOp: joinOp,
        exposure: exposure ?? 0.6,
      ),
      MaskKind.colorRange => AdjustmentLayer(
        maskKind: MaskKind.colorRange,
        maskParams: const [0.0, 30.0, 0.0, 1.0, 0.0, 1.0, 0.1],
        inverted: inverted,
        groupId: groupId,
        joinOp: joinOp,
        saturation: 0.2,
      ),
      MaskKind.autoBrush => AdjustmentLayer(
        maskKind: MaskKind.autoBrush,
        maskParams: const [0.06, 0.25, 0.25, 0.5, 0.5, 0.5, 0],
        inverted: inverted,
        groupId: groupId,
        joinOp: joinOp,
        exposure: exposure ?? 0.6,
      ),
      MaskKind.depthRange => AdjustmentLayer(
        maskKind: MaskKind.depthRange,
        maskParams: const [0.2, 0.6, 0.1],
        inverted: inverted,
        groupId: groupId,
        joinOp: joinOp,
        exposure: exposure ?? 0.5,
      ),
    };

    final idx = ref.read(recipeControllerProvider).recipe.layers.length;
    if (groupId != null) {
      // ADR 0013 §2.2: the group owns the grade, members own coverage only.
      // A fresh group takes over the member's stamped defaults (e.g. the
      // exposure every add-chip ships with) so the chip visibly does
      // something; the member's copy is dropped either way, so the group
      // card's sliders are the single source of truth.
      final groups = ref.read(recipeControllerProvider).recipe.maskGroups;
      final gi = groups.indexWhere((g) => g.id == groupId);
      if (gi != -1 && groups[gi].isGradeNeutral) {
        notifier.updateMaskGroup(groups[gi].withGradeOf(layer));
      }
      notifier.addLayerToGroup(
        groupId: groupId,
        layer: layer.withoutGrade,
        joinOp: joinOp,
      );
    } else {
      notifier.addLayer(layer);
    }
    ref.read(nodeEditorProvider.notifier).enable();
    ref.read(nodeEditorProvider.notifier).select(idx);
  }

  static const List<String> _zoneRomans = [
    '0', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'
  ];

  static String _zoneRoman(int z) => _zoneRomans[z.clamp(0, 10)];

  void _toggleStylusOnly(WidgetRef ref, bool value) {
    ref.read(stylusOnlyModeProvider.notifier).set(value);
  }
}

class _MaskSlider extends StatelessWidget {
  const _MaskSlider({
    required this.label,
    required this.sliderKey,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.displayValue,
  });

  final String label;
  final Key sliderKey;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String? displayValue;

  @override
  Widget build(BuildContext context) {
    return ParameterSliderRow(
      label: label,
      sliderKey: sliderKey,
      value: value,
      defaultValue: 0.0,
      min: min,
      max: max,
      onChanged: onChanged,
      displayValue: displayValue,
    );
  }
}

class _MaskColorGradingSection extends StatefulWidget {
  const _MaskColorGradingSection({
    required this.segmentedKey,
    required this.hueKey,
    required this.satKey,
    required this.lumKey,
    required this.blendingKey,
    required this.balanceKey,
    required this.shadowHue,
    required this.shadowSat,
    required this.shadowLum,
    required this.midHue,
    required this.midSat,
    required this.midLum,
    required this.highlightHue,
    required this.highlightSat,
    required this.highlightLum,
    required this.blending,
    required this.balance,
    required this.onZoneChanged,
    required this.onGlobalChanged,
  });

  final Key segmentedKey;
  final Key hueKey;
  final Key satKey;
  final Key lumKey;
  final Key blendingKey;
  final Key balanceKey;
  final double shadowHue;
  final double shadowSat;
  final double shadowLum;
  final double midHue;
  final double midSat;
  final double midLum;
  final double highlightHue;
  final double highlightSat;
  final double highlightLum;
  final double blending;
  final double balance;
  final void Function(GradeWheelZone zone, {double? hue, double? sat, double? lum}) onZoneChanged;
  final void Function({double? blending, double? balance}) onGlobalChanged;

  @override
  State<_MaskColorGradingSection> createState() => _MaskColorGradingSectionState();
}

class _MaskColorGradingSectionState extends State<_MaskColorGradingSection> {
  GradeWheelZone _zone = GradeWheelZone.shadows;

  (double hue, double sat, double lum) get _currentZoneValues => switch (_zone) {
        GradeWheelZone.shadows => (widget.shadowHue, widget.shadowSat, widget.shadowLum),
        GradeWheelZone.midtones => (widget.midHue, widget.midSat, widget.midLum),
        GradeWheelZone.highlights => (widget.highlightHue, widget.highlightSat, widget.highlightLum),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (rawHue, sat, lum) = _currentZoneValues;
    final hue = (rawHue <= 1.0 && rawHue > 0) ? rawHue * 360.0 : rawHue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          'COLOR GRADING',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w700,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        SegmentedButton<GradeWheelZone>(
          key: widget.segmentedKey,
          segments: const [
            ButtonSegment(
              value: GradeWheelZone.shadows,
              label: Text('Shadows'),
            ),
            ButtonSegment(
              value: GradeWheelZone.midtones,
              label: Text('Midtones'),
            ),
            ButtonSegment(
              value: GradeWheelZone.highlights,
              label: Text('Highlights'),
            ),
          ],
          selected: {_zone},
          onSelectionChanged: (selected) {
            setState(() => _zone = selected.first);
          },
        ),
        const SizedBox(height: 6),
        Center(
          child: ColorGradingWheel(
            hue: hue,
            saturation: sat,
            size: 140,
            onChanged: (newHue, newSat) {
              widget.onZoneChanged(_zone, hue: newHue, sat: newSat);
            },
            onChangeEnd: () {},
            onReset: () {
              widget.onZoneChanged(_zone, hue: 0.0, sat: 0.0);
            },
          ),
        ),
        _MaskSlider(
          label: 'Hue',
          sliderKey: widget.hueKey,
          value: hue,
          min: 0.0,
          max: 360.0,
          displayValue: '${hue.round()}°',
          onChanged: (val) => widget.onZoneChanged(_zone, hue: val),
        ),
        _MaskSlider(
          label: 'Sat',
          sliderKey: widget.satKey,
          value: sat,
          min: 0.0,
          max: 1.0,
          displayValue: '${(sat * 100).round()}%',
          onChanged: (val) => widget.onZoneChanged(_zone, sat: val),
        ),
        _MaskSlider(
          label: 'Luminance',
          sliderKey: widget.lumKey,
          value: lum,
          min: -1.0,
          max: 1.0,
          onChanged: (val) => widget.onZoneChanged(_zone, lum: val),
        ),
        _MaskSlider(
          label: 'Blending',
          sliderKey: widget.blendingKey,
          value: widget.blending,
          min: 0.0,
          max: 1.0,
          displayValue: '${(widget.blending * 100).round()}%',
          onChanged: (val) => widget.onGlobalChanged(blending: val),
        ),
        _MaskSlider(
          label: 'Balance',
          sliderKey: widget.balanceKey,
          value: widget.balance,
          min: -1.0,
          max: 1.0,
          onChanged: (val) => widget.onGlobalChanged(balance: val),
        ),
      ],
    );
  }
}

/// Persistent Rubylith Overlay Bar docked at the top of masking controls.
class _RubylithOverlayBar extends ConsumerWidget {
  const _RubylithOverlayBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final rubylith = ref.watch(rubylithOverlayProvider);
    final notifier = ref.read(rubylithOverlayProvider.notifier);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: Insets.xs),
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: Radii.mdAll,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              InkWell(
                key: const Key('mask-overlay-toggle'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  notifier.toggleShowOverlay();
                },
                borderRadius: Radii.smAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        rubylith.showOverlay ? Icons.visibility : Icons.visibility_off,
                        size: 16,
                        color: rubylith.showOverlay ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Overlay [O]',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: rubylith.showOverlay ? scheme.onSurface : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final rc in RubylithColor.values)
                    GestureDetector(
                      key: Key('mask-rubylith-${rc.name}'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        notifier.setColor(rc);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: rc.color,
                          border: Border.all(
                            color: rubylith.color == rc ? scheme.onSurface : scheme.outlineVariant,
                            width: rubylith.color == rc ? 2 : 1,
                          ),
                          boxShadow: rubylith.color == rc
                              ? [BoxShadow(color: rc.color.withValues(alpha: 0.6), blurRadius: 4)]
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  'Opacity',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    activeTrackColor: rubylith.color.color,
                    inactiveTrackColor: scheme.surfaceContainerHighest,
                    thumbColor: rubylith.color.color,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  ),
                  child: Slider(
                    key: const Key('mask-rubylith-opacity'),
                    value: rubylith.opacity,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) => notifier.setOpacity(v),
                  ),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${(rubylith.opacity * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// High-contrast miniature thumbnail for individual mask layer cards.
class _MaskThumbnail extends StatelessWidget {
  const _MaskThumbnail({
    required this.kind,
    required this.isSelected,
    this.inverted = false,
  });

  final MaskKind kind;
  final bool isSelected;
  final bool inverted;

  IconData _iconForKind(MaskKind k) {
    return switch (k) {
      MaskKind.radial => Icons.brightness_5,
      MaskKind.linear => Icons.gradient,
      MaskKind.luminance => Icons.brightness_6,
      MaskKind.brush => Icons.brush,
      MaskKind.autoBrush => Icons.auto_fix_normal,
      MaskKind.subject => Icons.person,
      MaskKind.sky => Icons.cloud_outlined,
      MaskKind.bitmap => Icons.grain,
      MaskKind.colorRange => Icons.colorize,
      MaskKind.depthRange => Icons.layers_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: Radii.smAll,
        border: Border.all(
          color: isSelected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.4),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: inverted ? 0.08 : 0.18),
            ),
          ),
          Icon(
            _iconForKind(kind),
            size: 18,
            color: isSelected ? scheme.primary : scheme.onSurface,
          ),
          if (inverted)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// High-contrast miniature thumbnail for mask group cards.
class _GroupThumbnail extends StatelessWidget {
  const _GroupThumbnail({required this.group});

  final MaskGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: Radii.smAll,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.layers,
          size: 18,
          color: group.amount > 0 ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

/// Categorized creation section grouped into AI Masks, Manual Tools, and Range Masks.
class _CreateMaskCategorizedSection extends StatelessWidget {
  const _CreateMaskCategorizedSection({
    required this.context,
    required this.ref,
    required this.isInferring,
    required this.onAddMask,
    required this.onAddAiSubject,
    required this.onAddAiFace,
    required this.onAddSky,
    required this.onAddDepthMap,
    this.onToolTap,
  });

  final BuildContext context;
  final WidgetRef ref;
  final bool isInferring;
  final void Function(MaskKind kind, {bool inverted, double? exposure}) onAddMask;
  final void Function({required bool inverted}) onAddAiSubject;
  final VoidCallback onAddAiFace;
  final VoidCallback onAddSky;
  final VoidCallback onAddDepthMap;
  final VoidCallback? onToolTap;

  Widget _buildToolTile({
    Key? key,
    required BuildContext ctx,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isTonal = false,
  }) {
    final scheme = Theme.of(ctx).colorScheme;
    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        backgroundColor: isTonal ? scheme.primary.withValues(alpha: 0.08) : null,
        foregroundColor: isTonal ? scheme.primary : scheme.onSurface,
        side: BorderSide(
          color: isTonal ? scheme.primary.withValues(alpha: 0.35) : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isTonal ? scheme.primary : scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext buildContext) {
    final scheme = Theme.of(buildContext).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. AI MASKS
        Container(
          margin: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
          padding: const EdgeInsets.all(Insets.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
            borderRadius: Radii.mdAll,
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: scheme.primary),
                  Text(
                    'AI MASKS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'On-Device AI',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildToolTile(
                    key: const Key('mask-add-subject'),
                    ctx: buildContext,
                    icon: Icons.person,
                    label: 'Subject +',
                    isTonal: true,
                    onPressed: isInferring
                        ? null
                        : () {
                            onToolTap?.call();
                            onAddAiSubject(inverted: false);
                          },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-sky'),
                    ctx: buildContext,
                    icon: Icons.cloud_outlined,
                    label: 'Sky +',
                    isTonal: true,
                    onPressed: isInferring
                        ? null
                        : () {
                            onToolTap?.call();
                            onAddSky();
                          },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-background'),
                    ctx: buildContext,
                    icon: Icons.wallpaper,
                    label: 'Background +',
                    isTonal: true,
                    onPressed: isInferring
                        ? null
                        : () {
                            onToolTap?.call();
                            onAddAiSubject(inverted: true);
                            HapticFeedback.selectionClick();
                          },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-face'),
                    ctx: buildContext,
                    icon: Icons.face_retouching_natural,
                    label: 'Face +',
                    isTonal: true,
                    onPressed: isInferring
                        ? null
                        : () {
                            onToolTap?.call();
                            onAddAiFace();
                            HapticFeedback.selectionClick();
                          },
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. MANUAL TOOLS
        Container(
          margin: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
          padding: const EdgeInsets.all(Insets.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.35),
            borderRadius: Radii.mdAll,
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.gesture, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'MANUAL TOOLS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildToolTile(
                    key: const Key('mask-add-brush'),
                    ctx: buildContext,
                    icon: Icons.brush,
                    label: 'Brush +',
                    onPressed: () {
                      onToolTap?.call();
                      onAddMask(MaskKind.brush);
                    },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-autobrush'),
                    ctx: buildContext,
                    icon: Icons.auto_fix_normal,
                    label: 'Auto Brush +',
                    onPressed: () {
                      onToolTap?.call();
                      onAddMask(MaskKind.autoBrush);
                    },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-linear'),
                    ctx: buildContext,
                    icon: Icons.gradient,
                    label: 'Linear +',
                    onPressed: () {
                      onToolTap?.call();
                      onAddMask(MaskKind.linear);
                    },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-radial'),
                    ctx: buildContext,
                    icon: Icons.brightness_5,
                    label: 'Radial +',
                    onPressed: () {
                      onToolTap?.call();
                      onAddMask(MaskKind.radial);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // 3. RANGE MASKS
        Container(
          margin: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
          padding: const EdgeInsets.all(Insets.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.35),
            borderRadius: Radii.mdAll,
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'RANGE MASKS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildToolTile(
                    key: const Key('mask-add-color-range'),
                    ctx: buildContext,
                    icon: Icons.colorize,
                    label: 'Color Range +',
                    onPressed: () {
                      onToolTap?.call();
                      onAddMask(MaskKind.colorRange);
                    },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-luminance'),
                    ctx: buildContext,
                    icon: Icons.brightness_6,
                    label: 'Darks +',
                    onPressed: () {
                      onToolTap?.call();
                      onAddMask(MaskKind.luminance);
                    },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-depth-range'),
                    ctx: buildContext,
                    icon: Icons.layers_outlined,
                    label: 'Depth Range +',
                    onPressed: () {
                      onToolTap?.call();
                      onAddMask(MaskKind.depthRange);
                    },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-depth'),
                    ctx: buildContext,
                    icon: Icons.blur_on,
                    label: 'Depth +',
                    onPressed: isInferring
                        ? null
                        : () {
                            onToolTap?.call();
                            onAddDepthMap();
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}