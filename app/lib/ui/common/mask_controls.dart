import 'dart:typed_data';

import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

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

/// Whether the user has requested reduced motion (accessibility setting).
bool get _reduceMotion =>
    PlatformDispatcher.instance.accessibilityFeatures.reduceMotion;

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

/// Function signature for extracting an embedded depth map from original bytes.
typedef EmbeddedDepthExtractorFn = Future<EmbeddedDepthResult?> Function(
  Uint8List jpeg,
);

/// Riverpod provider for embedded depth extraction, overridable in tests.
final embeddedDepthExtractorProvider = Provider<EmbeddedDepthExtractorFn>((ref) {
  return (Uint8List bytes) => AxEngine.extractEmbeddedDepth(bytes);
});

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
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final layers = recipe.layers;
    final maskGroups = recipe.maskGroups;
    final notifier = ref.read(recipeControllerProvider.notifier);
    final stylusOnly = ref.watch(stylusOnlyModeProvider);
    final nodeMode = ref.watch(nodeEditorProvider.select((s) => s.enabled));
    final selectedIndex = ref.watch(nodeEditorProvider.select((s) => s.selected));
    final groupIds = {for (final g in maskGroups) g.id};
    final isInferring = ref.watch(aiMaskInferringProvider);

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('edit-on-canvas'),
                onPressed: () => ref.read(nodeEditorProvider.notifier).toggle(),
                icon: Icon(nodeMode ? Icons.check : Icons.touch_app),
                label: Text(nodeMode ? 'Done placing' : 'Edit on canvas'),
              ),
              OutlinedButton.icon(
                key: const Key('mask-new-group'),
                onPressed: () {
                  final gid = 'group_${DateTime.now().microsecondsSinceEpoch}';
                  final num = maskGroups.length + 1;
                  notifier.addMaskGroup(MaskGroup(id: gid, name: 'Mask $num'));
                },
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('New Group +'),
              ),
              OutlinedButton.icon(
                onPressed: () => _addMask(context, ref, MaskKind.brush),
                icon: const Icon(Icons.brush),
                label: const Text('Brush +'),
              ),
              OutlinedButton.icon(
                onPressed: () => _addMask(context, ref, MaskKind.linear),
                icon: const Icon(Icons.gradient),
                label: const Text('Linear +'),
              ),
              OutlinedButton.icon(
                onPressed: () => _addMask(context, ref, MaskKind.radial),
                icon: const Icon(Icons.brightness_5),
                label: const Text('Radial +'),
              ),
              OutlinedButton.icon(
                key: const Key('mask-add-subject'),
                onPressed: isInferring
                    ? null
                    : () => _addAiSubjectMask(context, ref, inverted: false),
                icon: isInferring
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person),
                label: const Text('Subject +'),
              ),
              OutlinedButton.icon(
                key: const Key('mask-add-background'),
                onPressed: isInferring
                    ? null
                    : () {
                        _addAiSubjectMask(context, ref, inverted: true);
                        HapticFeedback.selectionClick();
                      },
                icon: isInferring
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wallpaper),
                label: const Text('Background +'),
              ),
              OutlinedButton.icon(
                key: const Key('mask-add-sky'),
                onPressed: isInferring
                    ? null
                    : () async {
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
                      },
                icon: const Icon(Icons.cloud_outlined),
                label: const Text('Sky +'),
              ),
              OutlinedButton.icon(
                onPressed: () => _addMask(context, ref, MaskKind.luminance),
                icon: const Icon(Icons.dark_mode),
                label: const Text('Darks +'),
              ),
              OutlinedButton.icon(
                key: const Key('mask-add-depth'),
                onPressed: isInferring
                    ? null
                    : () async {
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
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No embedded depth map in photo metadata')),
                            );
                          }
                        } finally {
                          ref.read(aiMaskInferringProvider.notifier).setInferring(false);
                          ref.read(aiMaskStatusMessageProvider.notifier).setMessage(null);
                        }
                      },
                icon: const Icon(Icons.blur_on),
                label: const Text('Depth +'),
              ),
              OutlinedButton.icon(
                onPressed: () => _toggleStylusOnly(ref, !stylusOnly),
                icon: const Icon(Icons.gesture),
                label: stylusOnly ? const Text('Touch mode') : const Text('Stylus mode'),
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
                duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
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
                Icon(Icons.layers, size: 20, color: theme.colorScheme.primary),
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
                  key: Key('group-invert-${group.id}'),
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
          leading: Icon(_maskIcon(layer.maskKind), size: 18),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '${layer.maskKind.name.toUpperCase()} layer ${i + 1}  '
                  'EV ${ev >= 0 ? '+' : ''}${ev.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
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
                const SizedBox(width: 4),
              ],
              if (showJoinOp) ...[
                Wrap(
                  spacing: 4,
                children: [
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
              ),
            ],
          ],
        ),
        subtitle: layer.inverted
            ? const Text(
                'Inverted (Reversed)',
                style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
              )
            : null,
        onTap: () {
          ref.read(nodeEditorProvider.notifier).select(i);
          ref.read(nodeEditorProvider.notifier).enable();
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: Key('mask-refine-$i'),
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
              tooltip: 'Invert / Reverse mask',
              icon: Icon(
                layer.inverted ? Icons.swap_horiz : Icons.swap_horizontal_circle_outlined,
                size: 18,
              ),
              onPressed: () => notifier.updateLayerAt(i, layer.copyWith(inverted: !layer.inverted)),
            ),
            IconButton(
              key: Key('mask-duplicate-$i'),
              tooltip: 'Duplicate mask',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => notifier.addLayer(layer.copyWith()),
            ),
            IconButton(
              key: Key('mask-delete-$i'),
              tooltip: 'Remove layer',
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () {
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
              if (layer.maskKind == MaskKind.brush) ...[
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

  IconData _maskIcon(MaskKind kind) => switch (kind) {
    MaskKind.brush => Icons.brush,
    MaskKind.linear => Icons.gradient,
    MaskKind.radial => Icons.brightness_5,
    MaskKind.subject => Icons.person,
    MaskKind.sky => Icons.cloud_outlined,
    MaskKind.luminance => Icons.dark_mode,
    MaskKind.bitmap => Icons.auto_awesome,
    MaskKind.colorRange => Icons.color_lens,
  };

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
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label, style: const TextStyle(fontSize: 12)),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                key: sliderKey,
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              displayValue ?? '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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