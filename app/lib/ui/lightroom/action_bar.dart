import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../color/tat.dart';
import '../../edit/active_image.dart' show activeImageBytesProvider;
import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/snapshots_provider.dart';
import '../../features/guide/app_guide_screen.dart';
import '../../features/guide/tool_guide_model.dart';
import '../../viewport/compare_hold.dart';
import '../../viewport/exposure_assist.dart';
import '../../viewport/soft_proofing.dart';
import '../../viewport/split_compare.dart';
import '../../viewport/wiper_compare.dart';
import '../common/history_tree_sheet.dart';
import 'lightroom_shell.dart';

/// The Lightroom shell action bar: Cancel, TAT, Undo, Redo, History,
/// Compare, Wiper, Split Compare, Exposure Assist, Snapshot Compare,
/// Soft Proofing, Tool Guide, and Apply buttons.
class LightroomActionBar extends ConsumerWidget {
  const LightroomActionBar({
    super.key,
    required this.hasTabChanges,
    required this.controller,
    required this.activeTab,
    required this.onCancel,
    required this.onApply,
    required this.onSoftProofing,
    required this.onToolGuideSelect,
  });

  final bool hasTabChanges;
  final RecipeController controller;
  final MasterTab activeTab;
  final VoidCallback onCancel;
  final VoidCallback onApply;
  final VoidCallback onSoftProofing;
  final ValueChanged<String> onToolGuideSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final canUndo = ref.watch(
      recipeControllerProvider.select((s) => s.index > 0),
    );
    final canRedo = ref.watch(
      recipeControllerProvider.select((s) => s.index < s.history.length - 1),
    );
    final undoLabel = ref.watch(
      recipeControllerProvider.select(
        (s) => s.index > 0 ? s.history[s.index].label : null,
      ),
    );
    final redoLabel = ref.watch(
      recipeControllerProvider.select(
        (s) => s.index < s.history.length - 1
            ? s.history[s.index + 1].label
            : null,
      ),
    );
    final undoTooltip = undoLabel != null ? 'Undo: $undoLabel' : 'Undo';
    final redoTooltip = redoLabel != null ? 'Redo: $redoLabel' : 'Redo';

    return SizedBox(
      height: 38,
      child: Row(
        children: [
          IconButton(
            key: const Key('tray-cancel'),
            tooltip: 'Discard changes',
            visualDensity: VisualDensity.compact,
            onPressed: hasTabChanges
                ? () {
                    HapticFeedback.lightImpact();
                    onCancel();
                  }
                : null,
            icon: Icon(
              Icons.close,
              size: 20,
              color: hasTabChanges
                  ? scheme.error
                  : scheme.onSurfaceVariant.withValues(alpha: 0.38),
            ),
          ),
          VerticalDivider(
            width: 12,
            indent: 8,
            endIndent: 8,
            color: scheme.outlineVariant.withValues(alpha: 0.2),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ref.watch(tatModeProvider)) ...[
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: () =>
                          ref.read(tatComponentProvider.notifier).cycle(),
                      child: Text(
                        tatComponentLabels[ref.watch(tatComponentProvider)],
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (activeTab == MasterTab.lightColor)
                    IconButton(
                      tooltip:
                          'Auto Tone: analyze image and apply balanced adjustments',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        final bytes = ref.read(activeImageBytesProvider);
                        if (bytes == null) return;
                        final auto = await ref.read(autoToneProvider)(bytes);
                        if (auto == null) return;
                        controller.update(
                            Parameter.exposure, auto['exposure'] as double);
                        controller.update(
                            Parameter.contrast, auto['contrast'] as double);
                        controller.update(
                            Parameter.highlights, auto['highlights'] as double);
                        controller.update(
                            Parameter.shadows, auto['shadows'] as double);
                        controller.update(
                            Parameter.whites, auto['whites'] as double);
                        controller.update(
                            Parameter.blacks, auto['blacks'] as double);
                        controller.update(
                            Parameter.temperature, auto['temperature'] as double);
                        controller.update(
                            Parameter.tint, auto['tint'] as double);
                        if (auto.containsKey('vibrance')) {
                          controller.update(
                              Parameter.vibrance, auto['vibrance'] as double);
                        }
                        controller.commit(label: 'Auto Tone');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Auto-tone applied'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.auto_awesome, size: 18),
                    ),
                  const SizedBox(width: Insets.sm),
                  IconButton(
                    tooltip:
                        'Target Adjustment: drag the image to target the HSL '
                        'colour under your finger',
                    visualDensity: VisualDensity.compact,
                    isSelected: ref.watch(tatModeProvider),
                    onPressed: () =>
                        ref.read(tatModeProvider.notifier).toggle(),
                    icon: const Icon(Icons.colorize),
                    selectedIcon: Icon(
                      Icons.colorize,
                      color: scheme.primary,
                    ),
                  ),
                  VerticalDivider(
                    width: 12,
                    indent: 8,
                    endIndent: 8,
                    color: scheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                  IconButton(
                    tooltip: undoTooltip,
                    visualDensity: VisualDensity.compact,
                    onPressed: canUndo ? controller.undo : null,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    tooltip: redoTooltip,
                    visualDensity: VisualDensity.compact,
                    onPressed: canRedo ? controller.redo : null,
                    icon: const Icon(Icons.redo),
                  ),
                  IconButton(
                    tooltip: 'Edit History & Branches (Git-style)',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => HistoryTreeSheet.show(context),
                    icon: const Icon(Icons.alt_route),
                  ),
                  VerticalDivider(
                    width: 12,
                    indent: 8,
                    endIndent: 8,
                    color: scheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                  Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) =>
                        ref.read(compareHoldProvider.notifier).hold(),
                    onPointerUp: (_) =>
                        ref.read(compareHoldProvider.notifier).release(),
                    onPointerCancel: (_) =>
                        ref.read(compareHoldProvider.notifier).release(),
                    child: IconButton(
                      tooltip: 'Hold to compare',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {},
                      icon: const Icon(Icons.compare),
                    ),
                  ),
                  IconButton(
                    key: const Key('tray-wiper-compare'),
                    tooltip: 'Split Curtain Wiper Compare (120 FPS)',
                    visualDensity: VisualDensity.compact,
                    isSelected: ref.watch(wiperCompareProvider).isActive,
                    onPressed: () {
                      ref.read(wiperCompareProvider.notifier).toggle();
                      HapticFeedback.selectionClick();
                    },
                    icon: const Icon(Icons.splitscreen),
                    selectedIcon: Icon(
                      Icons.splitscreen,
                      color: scheme.primary,
                    ),
                  ),
                  IconButton(
                    key: const Key('tray-split-compare'),
                    tooltip:
                        'Before/After Split View (Y - long press for orientation)',
                    visualDensity: VisualDensity.compact,
                    isSelected: ref.watch(splitCompareProvider).isEnabled,
                    onPressed: () {
                      ref.read(splitCompareProvider.notifier).toggle();
                      HapticFeedback.selectionClick();
                    },
                    icon: const Icon(Icons.view_column_outlined),
                    selectedIcon: Icon(
                      Icons.view_column,
                      color: scheme.primary,
                    ),
                  ),
                  IconButton(
                    tooltip:
                        'Exposure Assist: Zebras & False Color Heatmap (ARRI IRE)',
                    visualDensity: VisualDensity.compact,
                    isSelected: ref.watch(exposureAssistProvider).isActive,
                    onPressed: () {
                      ref.read(exposureAssistProvider.notifier).cycleMode();
                      HapticFeedback.selectionClick();
                    },
                    icon: const Icon(Icons.wb_iridescent_outlined),
                    selectedIcon: Icon(
                      Icons.wb_iridescent,
                      color: scheme.primary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Snapshot A/B Compare',
                    visualDensity: VisualDensity.compact,
                    isSelected: ref.watch(snapshotCompareEnabledProvider),
                    onPressed: () {
                      ref.read(snapshotCompareEnabledProvider.notifier).toggle();
                      HapticFeedback.selectionClick();
                    },
                    icon: const Icon(Icons.compare_arrows),
                    selectedIcon: Icon(
                      Icons.compare_arrows,
                      color: scheme.primary,
                    ),
                  ),
                  IconButton(
                    key: const Key('tray-soft-proofing'),
                    tooltip:
                        'Soft Proofing: simulate printer ICC profiles and gamut clipping',
                    visualDensity: VisualDensity.compact,
                    isSelected: ref.watch(softProofingProvider).enabled,
                    onPressed: () {
                      onSoftProofing();
                      HapticFeedback.selectionClick();
                    },
                    icon: const Icon(Icons.print_outlined),
                    selectedIcon: Icon(
                      Icons.print,
                      color: scheme.primary,
                    ),
                  ),
                  IconButton(
                    key: const Key('tray-tool-guide'),
                    tooltip: 'Tool Guide & Academy',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final category = switch (activeTab) {
                        MasterTab.lightColor => ToolCategory.light,
                        MasterTab.effectsDetail => ToolCategory.detail,
                        MasterTab.cropGeometry => ToolCategory.geometry,
                        MasterTab.proTools => ToolCategory.optics,
                        MasterTab.masks => ToolCategory.masking,
                        _ => null,
                      };
                      AppGuideScreen.showModal(
                        context,
                        initialCategory: category,
                        onSelectTool: onToolGuideSelect,
                      );
                    },
                    icon: const Icon(Icons.school_outlined),
                  ),
                ],
              ),
            ),
          ),
          VerticalDivider(
            width: 12,
            indent: 8,
            endIndent: 8,
            color: scheme.outlineVariant.withValues(alpha: 0.2),
          ),
          IconButton(
            key: const Key('tray-apply'),
            tooltip: 'Apply changes',
            visualDensity: VisualDensity.compact,
            onPressed: hasTabChanges
                ? () {
                    HapticFeedback.lightImpact();
                    onApply();
                  }
                : null,
            icon: Icon(
              Icons.check,
              size: 20,
              color: hasTabChanges
                  ? scheme.primary
                  : scheme.onSurfaceVariant.withValues(alpha: 0.38),
            ),
          ),
        ],
      ),
    );
  }
}
