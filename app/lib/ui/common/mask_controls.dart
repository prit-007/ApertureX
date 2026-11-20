import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';

import '../../edit/adjustment_layer.dart';
import '../../edit/node_editor.dart';
import '../../edit/recipe_controller.dart';
import '../../engine/engine.dart';
import '../../l10n/app_strings.dart';
import '../../viewport/mask_peek.dart';
import '../mask/ai_mask_actions.dart';
import '../mask/create_mask_section.dart';
import '../mask/mask_group_card.dart';
import '../mask/mask_inline_card.dart';
import '../mask/mask_layer_tile.dart';
import '../mask/rubylith_overlay.dart';

export '../mask/ai_mask_actions.dart';
export '../mask/create_mask_section.dart';
export '../mask/mask_color_grading_section.dart';
export '../mask/mask_group_card.dart';
export '../mask/mask_inline_card.dart';
export '../mask/mask_layer_tile.dart';
export '../mask/mask_thumbnails.dart';
export '../mask/rubylith_overlay.dart';

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

/// Local-adjustment (masking) controls: add analytic masks and manage the
/// layer stack. Masks are parametric, so no brush data is stored (#18).
/// Supports mask groups with Boolean Add/Subtract/Intersect coverage algebra (ADR 0013 / #92).
class MaskControls extends ConsumerWidget {
  const MaskControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (layers, maskGroups) = ref.watch(
      recipeControllerProvider.select((s) => (s.recipe.layers, s.recipe.maskGroups)),
    );
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
        const RubylithOverlayBar(),

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
                onPressed: () => showCreateMaskSheet(context, ref),
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
                label: Text(AppStrings.of(context).maskNewGroupPlus, style: const TextStyle(fontSize: 12)),
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
                onPressed: () => ref.read(stylusOnlyModeProvider.notifier).set(!stylusOnly),
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

        // 3. Categorized Creation Panel (Prompt & Grouped Hierarchy)
        if (isEmpty)
          CreateMaskCategorizedSection(
            context: context,
            ref: ref,
            isInferring: isInferring,
            onAddMask: (kind, {inverted = false, exposure}) =>
                addMask(context, ref, kind, inverted: inverted, exposure: exposure),
            onAddAiSubject: ({required inverted}) =>
                addAiSubjectMask(context, ref, inverted: inverted),
            onAddAiFace: () => addAiFaceMask(context, ref),
            onAddAiSkin: () => addAiSkinMask(context, ref),
            onAddAiHair: () => addAiHairMask(context, ref),
            onAddAiObject: () => addAiObjectMask(context, ref),
            onAddSky: () => addSkyMask(context, ref),
            onAddDepthMap: () => addDepthMapMask(context, ref),
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
                CreateMaskCategorizedSection(
                  context: context,
                  ref: ref,
                  isInferring: isInferring,
                  onAddMask: (kind, {inverted = false, exposure}) =>
                      addMask(context, ref, kind, inverted: inverted, exposure: exposure),
                  onAddAiSubject: ({required inverted}) =>
                      addAiSubjectMask(context, ref, inverted: inverted),
                  onAddAiFace: () => addAiFaceMask(context, ref),
                  onAddAiSkin: () => addAiSkinMask(context, ref),
                  onAddAiHair: () => addAiHairMask(context, ref),
                  onAddAiObject: () => addAiObjectMask(context, ref),
                  onAddSky: () => addSkyMask(context, ref),
                  onAddDepthMap: () => addDepthMapMask(context, ref),
                  onToolTap: null,
                ),
              ],
            ),
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
          MaskGroupCard(
            group: group,
            layers: layers,
            selectedIndex: selectedIndex,
            notifier: notifier,
            onAddMask: addMask,
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
            MaskLayerTile(
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
                child: MaskInlineCard(i: i, layer: layers[i], notifier: notifier),
              ),
          ],
      ],
    );
  }
}
