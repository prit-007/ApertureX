import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../color/tat.dart';
import '../../core/theme/design_tokens.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe_mapping.dart';
import '../../gesture/gesture_interpreter.dart';
import '../../l10n/app_strings.dart';
import 'snapseed_hud_hosts.dart';

String _categoryLabel(ToolCategory c, [AppStrings? strings]) => switch (c) {
  ToolCategory.light => strings?.light ?? 'Light',
  ToolCategory.color => strings?.color ?? 'Color',
  ToolCategory.effects => strings?.effects ?? 'Effects',
  ToolCategory.detail => strings?.detail ?? 'Detail',
};

/// Responsive tablet sidebar variant for the Snapseed shell dock (Flaw 15).
///
/// On large and extra-large displays (e.g. tablet landscape, iPad Pro, desktop),
/// replaces the cramped bottom horizontal dock with a dedicated right sidebar
/// featuring full-width tool buttons, labels, and clean vertical alignment.
class SnapseedDockSidebar extends ConsumerWidget {
  const SnapseedDockSidebar({
    super.key,
    required this.tool,
    required this.category,
    this.categoryLabel,
    required this.onCycleCategory,
    required this.onOpenToolsSheet,
    required this.onOpenStacks,
    required this.onToggleLooks,
    required this.looksOpen,
    required this.onOpenMasks,
    required this.onOpenLensBlur,
    required this.onToggleStraighten,
    required this.straightenOpen,
    required this.onOpenRadial,
    required this.onEnableSelective,
    required this.hasHistogram,
    required this.histogramOpen,
    required this.onToggleHistogram,
  });

  final GradeTool tool;
  final ToolCategory category;
  final String? categoryLabel;
  final VoidCallback onCycleCategory;
  final VoidCallback onOpenToolsSheet;
  final VoidCallback onOpenStacks;
  final VoidCallback onToggleLooks;
  final bool looksOpen;
  final VoidCallback onOpenMasks;
  final VoidCallback onOpenLensBlur;
  final VoidCallback onToggleStraighten;
  final bool straightenOpen;
  final VoidCallback onOpenRadial;
  final VoidCallback onEnableSelective;
  final bool hasHistogram;
  final bool histogramOpen;
  final VoidCallback? onToggleHistogram;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final parameter = primaryParameterForTool(tool);
    final spec = specOf(parameter);
    final tatActive = ref.watch(tatModeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.sm, Insets.sm, Insets.xl, Insets.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.onSurface.withValues(alpha: 0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Container(
                width: 260,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height - 120,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Active Tool & Category Header
                      _buildHeaderCard(context, scheme, spec),
                      const SizedBox(height: 8),
                      Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 6),
                      // Tool Actions
                      _buildActionItem(
                        key: const Key('snapseed-tools-sheet-toggle'),
                        icon: Icons.grid_view,
                        label: 'All Tools',
                        tooltip: 'All Tools',
                        onTap: onOpenToolsSheet,
                        scheme: scheme,
                      ),
                      _buildActionItem(
                        key: const Key('snapseed-stacks-toggle'),
                        icon: Icons.layers,
                        label: 'View Edits (Stacks)',
                        tooltip: 'View Edits (Stacks)',
                        onTap: onOpenStacks,
                        scheme: scheme,
                      ),
                      _buildActionItem(
                        key: const Key('snapseed-looks-toggle'),
                        icon: looksOpen ? Icons.style : Icons.style_outlined,
                        label: 'Looks & Presets',
                        tooltip: 'Looks & Presets',
                        isSelected: looksOpen,
                        onTap: onToggleLooks,
                        scheme: scheme,
                      ),
                      _buildActionItem(
                        key: const Key('snapseed-mask-toggle'),
                        icon: Icons.layers_outlined,
                        label: 'Masks & Layers',
                        tooltip: 'Masks & Layers',
                        onTap: onOpenMasks,
                        scheme: scheme,
                      ),
                      _buildActionItem(
                        key: const Key('snapseed-lens-blur-toggle'),
                        icon: Icons.blur_on,
                        label: 'Lens Blur & Bokeh',
                        tooltip: 'Lens Blur & Bokeh',
                        onTap: onOpenLensBlur,
                        scheme: scheme,
                      ),
                      _buildActionItem(
                        key: const Key('snapseed-straighten-toggle'),
                        icon: Icons.crop_rotate,
                        label: 'Straighten & Rotate',
                        tooltip: 'Straighten & Rotate',
                        isSelected: straightenOpen,
                        onTap: onToggleStraighten,
                        scheme: scheme,
                      ),
                      _buildActionItem(
                        icon: Icons.radio_button_checked,
                        label: 'Radial Tools',
                        tooltip: 'Tools',
                        onTap: onOpenRadial,
                        scheme: scheme,
                      ),
                      const SizedBox(height: 6),
                      Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 6),
                      // Assist & Selective
                      _buildActionItem(
                        icon: Icons.colorize,
                        label: 'HSL Target',
                        tooltip: 'HSL target: tap a colour in the photo, then drag to adjust it',
                        isSelected: tatActive,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(tatModeProvider.notifier).toggle();
                        },
                        scheme: scheme,
                      ),
                      _buildActionItem(
                        key: const Key('selective-toggle'),
                        icon: Icons.add_location_alt,
                        label: 'Selective',
                        tooltip: 'Selective',
                        onTap: onEnableSelective,
                        scheme: scheme,
                      ),
                      if (hasHistogram)
                        _buildActionItem(
                          key: const Key('histogram-toggle'),
                          icon: Icons.bar_chart,
                          label: histogramOpen ? 'Hide Histogram' : 'Show Histogram',
                          tooltip: histogramOpen ? 'Hide histogram' : 'Show histogram',
                          isSelected: histogramOpen,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onToggleHistogram?.call();
                          },
                          scheme: scheme,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, ColorScheme scheme, ParameterSpec spec) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onCycleCategory();
            },
            borderRadius: Radii.smAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.category_outlined, size: 14, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        categoryLabel ?? _categoryLabel(category, AppStrings.of(context)),
                        style: themeStyle(context, FontWeight.w600).copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.unfold_more, size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  tool.is2D
                      ? switch (tool) {
                          GradeTool.shadowsGrade => 'Shadows Grade',
                          GradeTool.midtonesGrade => 'Midtones Grade',
                          GradeTool.highlightsGrade => 'Highlights Grade',
                          _ => spec.label,
                        }
                      : spec.label,
                  overflow: TextOverflow.ellipsis,
                  style: themeStyle(context, FontWeight.w700).copyWith(fontSize: 13),
                ),
              ),
              if (tool.is2D)
                Snapseed2DColorIndicator(tool: tool)
              else
                Snapseed1DValueIndicator(tool: tool),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    Key? key,
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onTap,
    required ColorScheme scheme,
    bool isSelected = false,
  }) {
    const minConstraints = BoxConstraints(minWidth: 48, minHeight: 48);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? scheme.primaryContainer.withValues(alpha: 0.7)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                IconButton(
                  key: key,
                  tooltip: tooltip,
                  visualDensity: VisualDensity.compact,
                  constraints: minConstraints,
                  padding: EdgeInsets.zero,
                  isSelected: isSelected,
                  onPressed: onTap,
                  icon: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  selectedIcon: Icon(
                    icon,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
