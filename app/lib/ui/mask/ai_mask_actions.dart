import 'dart:typed_data';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/log/activity_log.dart';
import '../../core/log/log_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../edit/active_image.dart';
import '../../edit/adjustment_layer.dart';
import '../../edit/node_editor.dart';
import '../../edit/recipe_controller.dart';
import '../../engine/engine.dart';
import '../../features/ai_plugins/ai_plugin_model.dart';
import '../../features/ai_plugins/ai_plugin_store.dart';
import '../../gallery/gallery_controller.dart' show gallerySourceProvider;
import '../../l10n/app_strings.dart';
import '../../settings/ai_consent.dart';
import '../../viewport/canvas_transform.dart';
import '../common/mask_controls.dart';

Future<void> addAiSubjectMask(
  BuildContext context,
  WidgetRef ref, {
  bool inverted = false,
}) async {
  final bytes = ref.read(activeImageBytesProvider);
  if (bytes == null) {
    addMask(
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
      addMask(
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
  final activeSeg =
      ref.read(aiPluginProvider.notifier).getActivePluginForTask(AiTask.subjectSegmentation);
  final segSuffix = (activeSeg != null && !activeSeg.isBuiltIn) ? ' via ${activeSeg.name}' : '';
  ref.read(aiMaskStatusMessageProvider.notifier).setMessage(inverted
      ? 'Segmenting background on-device$segSuffix… Please wait a moment'
      : 'Finding subject on-device$segSuffix… Please wait a moment');
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
  } catch (e, st) {
    axLog(LogDomain.editor, 'AI segmentation failed: $e', level: LogLevel.warning, error: e.toString(), stack: st.toString());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context).maskAISegmentationFailed),
        ),
      );
    }
  } finally {
    ref.read(aiMaskInferringProvider.notifier).setInferring(false);
    ref.read(aiMaskStatusMessageProvider.notifier).setMessage(null);
  }

  // 3. Fallback path
  if (context.mounted) {
    addMask(
      context,
      ref,
      MaskKind.subject,
      inverted: inverted,
      exposure: inverted ? -0.4 : 0.5,
    );
  }
}

Future<void> addAiFaceMask(
  BuildContext context,
  WidgetRef ref,
) async {
  final bytes = ref.read(activeImageBytesProvider);
  if (bytes == null) {
    addMask(
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
      addMask(
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
  } catch (e, st) {
    axLog(LogDomain.editor, 'Face detection failed: $e', level: LogLevel.warning, error: e.toString(), stack: st.toString());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context).maskFaceDetectionFailed),
        ),
      );
    }
  } finally {
    ref.read(aiMaskInferringProvider.notifier).setInferring(false);
    ref.read(aiMaskStatusMessageProvider.notifier).setMessage(null);
  }

  // 3. Fallback path
  if (context.mounted) {
    addMask(
      context,
      ref,
      MaskKind.radial,
      exposure: 0.35,
    );
  }
}

Future<void> addAiSkinMask(
  BuildContext context,
  WidgetRef ref,
) async {
  final bytes = ref.read(activeImageBytesProvider);
  if (bytes == null) {
    addMask(context, ref, MaskKind.personSkin, exposure: 0.2);
    return;
  }

  final consent =
      await ref.read(aiConsentProvider.notifier).requestConsentDialog(context);
  if (!consent) {
    if (context.mounted) {
      addMask(context, ref, MaskKind.personSkin, exposure: 0.2);
    }
    return;
  }

  ref.read(aiMaskInferringProvider.notifier).setInferring(true);
  ref.read(aiMaskStatusMessageProvider.notifier).setMessage(
      'Detecting portrait skin on-device… Please wait a moment');
  try {
    final detector = ref.read(faceDetectorProvider);
    final face = await detector(bytes);
    final notifier = ref.read(recipeControllerProvider.notifier);
    final layers = ref.read(recipeControllerProvider).recipe.layers;
    final idx = layers.length;
    final cx = face?.cx.clamp(0.05, 0.95) ?? 0.5;
    final cy = face?.cy.clamp(0.05, 0.95) ?? 0.4;
    final rx = ((face?.rx ?? 0.15) * 1.15).clamp(0.04, 0.45);
    final ry = ((face?.ry ?? 0.2) * 1.25).clamp(0.05, 0.50);
    notifier.addLayer(
      AdjustmentLayer(
        maskKind: MaskKind.personSkin,
        maskParams: [cx, cy, rx, ry, 0.35],
        exposure: 0.2,
        aiIntent: 'skin',
      ),
    );
    ref.read(nodeEditorProvider.notifier).enable();
    ref.read(nodeEditorProvider.notifier).select(idx);
    HapticFeedback.selectionClick();
    return;
  } catch (e, st) {
    axLog(LogDomain.editor, 'Skin detection failed: $e', level: LogLevel.warning, error: e.toString(), stack: st.toString());
    if (context.mounted) {
      addMask(context, ref, MaskKind.personSkin, exposure: 0.2);
    }
  } finally {
    ref.read(aiMaskInferringProvider.notifier).setInferring(false);
    ref.read(aiMaskStatusMessageProvider.notifier).setMessage(null);
  }
}

Future<void> addAiHairMask(
  BuildContext context,
  WidgetRef ref,
) async {
  final bytes = ref.read(activeImageBytesProvider);
  if (bytes == null) {
    addMask(context, ref, MaskKind.personHair, exposure: -0.15);
    return;
  }

  final consent =
      await ref.read(aiConsentProvider.notifier).requestConsentDialog(context);
  if (!consent) {
    if (context.mounted) {
      addMask(context, ref, MaskKind.personHair, exposure: -0.15);
    }
    return;
  }

  ref.read(aiMaskInferringProvider.notifier).setInferring(true);
  ref.read(aiMaskStatusMessageProvider.notifier).setMessage(
      'Detecting portrait hair on-device… Please wait a moment');
  try {
    final detector = ref.read(faceDetectorProvider);
    final face = await detector(bytes);
    final notifier = ref.read(recipeControllerProvider.notifier);
    final layers = ref.read(recipeControllerProvider).recipe.layers;
    final idx = layers.length;
    final cx = face?.cx.clamp(0.05, 0.95) ?? 0.5;
    final cy = ((face?.cy ?? 0.4) - (face?.ry ?? 0.2) * 0.4).clamp(0.05, 0.95);
    final rx = ((face?.rx ?? 0.15) * 1.1).clamp(0.04, 0.45);
    final ry = ((face?.ry ?? 0.2) * 0.6).clamp(0.04, 0.45);
    notifier.addLayer(
      AdjustmentLayer(
        maskKind: MaskKind.personHair,
        maskParams: [cx, cy, rx, ry, 0.2],
        exposure: -0.15,
        aiIntent: 'hair',
      ),
    );
    ref.read(nodeEditorProvider.notifier).enable();
    ref.read(nodeEditorProvider.notifier).select(idx);
    HapticFeedback.selectionClick();
    return;
  } catch (e, st) {
    axLog(LogDomain.editor, 'Hair detection failed: $e', level: LogLevel.warning, error: e.toString(), stack: st.toString());
    if (context.mounted) {
      addMask(context, ref, MaskKind.personHair, exposure: -0.15);
    }
  } finally {
    ref.read(aiMaskInferringProvider.notifier).setInferring(false);
    ref.read(aiMaskStatusMessageProvider.notifier).setMessage(null);
  }
}

Future<void> addAiObjectMask(
  BuildContext context,
  WidgetRef ref,
) async {
  final notifier = ref.read(recipeControllerProvider.notifier);
  final layers = ref.read(recipeControllerProvider).recipe.layers;
  final idx = layers.length;
  notifier.addLayer(
    const AdjustmentLayer(
      maskKind: MaskKind.object,
      maskParams: [0.25, 0.25, 0.75, 0.75, 0.1],
      exposure: 0.3,
      aiIntent: 'object',
    ),
  );
  ref.read(nodeEditorProvider.notifier).enable();
  ref.read(nodeEditorProvider.notifier).select(idx);
  HapticFeedback.selectionClick();
}

Future<void> addSkyMask(BuildContext context, WidgetRef ref) async {
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
    } catch (e, st) {
      axLog(LogDomain.editor, 'Sky detection fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
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

Future<void> addDepthMapMask(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(recipeControllerProvider.notifier);
  final layers = ref.read(recipeControllerProvider).recipe.layers;
  Uint8List? bytes = ref.read(activeImageBytesProvider);
  final asset = ref.read(currentEditingAssetProvider);
  if (asset != null) {
    try {
      final original =
          await ref.read(gallerySourceProvider).loadImage(asset.id);
      if (original.isNotEmpty) bytes = original;
    } catch (e, st) {
      axLog(LogDomain.editor, 'Gallery image load for depth fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
    }
  }
  if (!context.mounted) return;
  if (bytes == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).maskNoPhotoDepth)),
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
          SnackBar(content: Text(AppStrings.of(context).maskDepthLoaded)),
        );
      }
    } else {
      final activeDepth =
          ref.read(aiPluginProvider.notifier).getActivePluginForTask(AiTask.depthEstimation);
      final modelName = activeDepth?.name ?? 'Depth Anything V2';
      ref.read(aiMaskStatusMessageProvider.notifier).setMessage(
          'Synthesizing AI monocular depth map via $modelName…');
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
          SnackBar(content: Text(AppStrings.of(context).maskDepthGenerated(modelName))),
        );
      }
    }
  } catch (e, st) {
    axLog(LogDomain.editor, 'Depth map extraction failed: $e', level: LogLevel.warning, error: e.toString(), stack: st.toString());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).maskDepthFailed)),
      );
    }
  } finally {
    ref.read(aiMaskInferringProvider.notifier).setInferring(false);
    ref.read(aiMaskStatusMessageProvider.notifier).setMessage(null);
  }
}

void showCreateMaskSheet(BuildContext context, WidgetRef ref) {
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
              CreateMaskCategorizedSection(
                context: modalCtx,
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
                onToolTap: () => Navigator.of(modalCtx).pop(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void addMask(
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
    MaskKind.background => AdjustmentLayer(
      maskKind: MaskKind.background,
      maskParams: const [],
      inverted: inverted,
      groupId: groupId,
      joinOp: joinOp,
      exposure: exposure ?? -0.3,
    ),
    MaskKind.personFace => AdjustmentLayer(
      maskKind: MaskKind.personFace,
      maskParams: [center.dx, center.dy, rx, ry, 0.2],
      inverted: inverted,
      groupId: groupId,
      joinOp: joinOp,
      exposure: exposure ?? 0.3,
    ),
    MaskKind.personSkin => AdjustmentLayer(
      maskKind: MaskKind.personSkin,
      maskParams: [center.dx, center.dy, rx, ry, 0.2],
      inverted: inverted,
      groupId: groupId,
      joinOp: joinOp,
      contrast: -0.2,
    ),
    MaskKind.personHair => AdjustmentLayer(
      maskKind: MaskKind.personHair,
      maskParams: [center.dx, center.dy, rx, ry, 0.2],
      inverted: inverted,
      groupId: groupId,
      joinOp: joinOp,
      contrast: 0.2,
    ),
    MaskKind.object => AdjustmentLayer(
      maskKind: MaskKind.object,
      maskParams: [center.dx - rx, center.dy - ry, center.dx + rx, center.dy + ry, 0.1],
      inverted: inverted,
      groupId: groupId,
      joinOp: joinOp,
      exposure: exposure ?? 0.4,
    ),
  };

  final idx = ref.read(recipeControllerProvider).recipe.layers.length;
  if (groupId != null) {
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
