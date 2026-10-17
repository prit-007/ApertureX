import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../color/tat.dart';
import '../../core/theme/design_tokens.dart';
import '../../edit/node_editor.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/recipe_mapping.dart';
import '../../gesture/gesture_interpreter.dart';
import '../../gesture/zone_mask.dart';
import '../common/precision_rotation_dial.dart';
import 'edit_hud.dart';
import 'snapseed_tools_sheet.dart';

/// Index of the radial-menu item nearest [pointer], for a menu centred at
/// [center] with [count] items at [radius]. Item 0 sits at the top (−90°),
/// going clockwise. Pure — unit-tested.
int nearestRadialItem(Offset center, Offset pointer, int count, double radius) {
  var best = 0;
  var bestD = double.infinity;
  for (var i = 0; i < count; i++) {
    final angle = -math.pi / 2 + i * 2 * math.pi / count;
    final c = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    final d = (c - pointer).distanceSquared;
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return best;
}

/// The Snapseed shell is a pure **HUD**: it owns no gestures and no edit state.
/// The shared [ImageCanvas] owns the touch model (1-finger edit, 2-finger
/// zoom/pan), routes 1-finger drags to the interpreter, and this layer floats
/// the active tool + recent changes over an edge-to-edge image, plus the radial
/// tool menu.
class SnapseedShell extends ConsumerStatefulWidget {
  const SnapseedShell({
    super.key,
    required this.tool,
    required this.category,
    required this.tools,
    required this.onCycleCategory,
    required this.onPickTool,
    this.onSelectCategoryAndTool,
    this.histogramOpen = false,
    this.hasHistogram = false,
    this.onToggleHistogram,
  });

  final GradeTool tool;
  final ToolCategory category;
  final List<GradeTool> tools;
  final VoidCallback onCycleCategory;
  final ValueChanged<GradeTool> onPickTool;
  final void Function(ToolCategory category, GradeTool tool)? onSelectCategoryAndTool;
  final bool histogramOpen;
  final bool hasHistogram;
  final VoidCallback? onToggleHistogram;

  @override
  ConsumerState<SnapseedShell> createState() => _SnapseedShellState();
}

String _categoryLabel(ToolCategory c) => switch (c) {
  ToolCategory.light => 'Light',
  ToolCategory.color => 'Color',
  ToolCategory.effects => 'Effects',
  ToolCategory.detail => 'Detail',
};

class _SnapseedShellState extends ConsumerState<SnapseedShell> {
  bool _radialOpen = false;
  bool _straightenOpen = false;

  static IconData _icon(GradeTool tool) => switch (tool) {
    GradeTool.exposure => Icons.exposure,
    GradeTool.contrast => Icons.contrast,
    GradeTool.highlights => Icons.brightness_high,
    GradeTool.shadows => Icons.brightness_low,
    GradeTool.whites => Icons.brightness_7,
    GradeTool.blacks => Icons.brightness_4,
    GradeTool.temperature => Icons.thermostat,
    GradeTool.tint => Icons.color_lens,
    GradeTool.vibrance => Icons.auto_awesome,
    GradeTool.saturation => Icons.water_drop,
    GradeTool.clarity => Icons.blur_on,
    GradeTool.dehaze => Icons.filter_drama,
    GradeTool.vignette => Icons.vignette,
    GradeTool.grain => Icons.grain,
    GradeTool.sharpen => Icons.details,
    GradeTool.shadowsGrade => Icons.tonality,
    GradeTool.midtonesGrade => Icons.brightness_medium,
    GradeTool.highlightsGrade => Icons.wb_sunny,
  };

  void _openToolsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.70,
        child: SnapseedToolsSheet(
          onSelectCategoryAndTool: (cat, tool) {
            if (widget.onSelectCategoryAndTool != null) {
              widget.onSelectCategoryAndTool!(cat, tool);
            } else {
              widget.onPickTool(tool);
            }
          },
          onOpenStraighten: () {
            setState(() => _straightenOpen = true);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final parameter = snapseedToolParameters[widget.tool]!.first;
    final spec = specOf(parameter);
    final zoneMask = ref.watch(zoneMaskProvider);
    final lockedLayer = (zoneMask.lockedLayerIndex != null &&
            zoneMask.lockedLayerIndex! < recipe.layers.length)
        ? recipe.layers[zoneMask.lockedLayerIndex!]
        : null;
    final value = lockedLayer != null
        ? switch (parameter) {
            Parameter.exposure => lockedLayer.exposure,
            Parameter.contrast => lockedLayer.contrast,
            Parameter.highlights => lockedLayer.highlights,
            Parameter.shadows => lockedLayer.shadows,
            Parameter.saturation => lockedLayer.saturation,
            Parameter.temperature => lockedLayer.temperature,
            Parameter.tint => lockedLayer.tint,
            _ => valueOf(recipe, parameter),
          }
        : valueOf(recipe, parameter);
    final scheme = Theme.of(context).colorScheme;
    // Node mode swaps the bottom chrome for the node adjust bar, so the
    // tool pill (and its Selective entry) steps aside until Done.
    final nodeMode = ref.watch(nodeEditorProvider.select((s) => s.enabled));

    return Stack(
      children: [
        // Recent-changes HUD: float below top bar (top: 56), or below histogram (top: 140)
        // so it never collides with the histogram or status bar.
        Positioned(
          top: widget.histogramOpen ? 140 : 56,
          right: 0,
          child: const SafeArea(left: false, bottom: false, child: EditHud()),
        ),

        // Ansel Adams Haptic Zone Masking targeting overlay
        if (zoneMask.isTargeting)
          Positioned(
            top: 72,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.blur_circular, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Zone ${zoneMask.activeZone} (${(zoneMask.activeZone / 10.0 * 100).round()}%) · Luminosity Mask',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Ansel Adams Haptic Zone Masking locked pill
        if (zoneMask.lockedLayerIndex != null && !nodeMode)
          Positioned(
            bottom: 64,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.6),
                    width: 1.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, color: scheme.primary, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Zone ${zoneMask.activeZone} Mask Locked · ${spec.label}',
                      style: themeStyle(context, FontWeight.w600).copyWith(
                        color: scheme.onSurface,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      icon: const Icon(Icons.close, size: 15),
                      tooltip: 'Remove Zone Mask',
                      onPressed: () {
                        ref.read(zoneMaskProvider.notifier).removeLockedMask();
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Unified Material 3 bottom dock (zero-overlap, integrated actions).
        if (!nodeMode)
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Insets.sm, 0, Insets.sm, Insets.sm),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const Key('snapseed-tools-sheet-toggle'),
                          tooltip: 'All Tools',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () => _openToolsSheet(context),
                          icon: const Icon(Icons.grid_view, size: 17),
                        ),
                        IconButton(
                          key: const Key('snapseed-straighten-toggle'),
                          tooltip: 'Straighten & Rotate',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          isSelected: _straightenOpen,
                          onPressed: () =>
                              setState(() => _straightenOpen = !_straightenOpen),
                          icon: const Icon(Icons.crop_rotate, size: 17),
                          selectedIcon: Icon(Icons.crop_rotate, size: 17, color: scheme.primary),
                        ),
                        IconButton(
                          tooltip: 'Tools',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () => setState(() => _radialOpen = true),
                          icon: const Icon(Icons.radio_button_checked, size: 17),
                        ),
                        Container(
                          width: 1,
                          height: 18,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          color: scheme.outlineVariant,
                        ),
                        InkWell(
                          onTap: widget.onCycleCategory,
                          borderRadius: Radii.smAll,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _categoryLabel(widget.category),
                                  style: themeStyle(context, FontWeight.w600)
                                      .copyWith(color: scheme.onSurfaceVariant, fontSize: 11),
                                ),
                                const Icon(Icons.unfold_more, size: 12),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.tool.is2D
                                ? switch (widget.tool) {
                                    GradeTool.shadowsGrade => 'Shadows Grade',
                                    GradeTool.midtonesGrade => 'Midtones Grade',
                                    GradeTool.highlightsGrade => 'Highlights Grade',
                                    _ => spec.label,
                                  }
                                : spec.label,
                            overflow: TextOverflow.ellipsis,
                            style: themeStyle(context, FontWeight.w600).copyWith(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (widget.tool.is2D) ...[
                          Builder(builder: (_) {
                            final (h, s) = switch (widget.tool) {
                              GradeTool.shadowsGrade => (recipe.gradeShadowHue, recipe.gradeShadowSat),
                              GradeTool.midtonesGrade => (recipe.gradeMidHue, recipe.gradeMidSat),
                              GradeTool.highlightsGrade => (recipe.gradeHighlightHue, recipe.gradeHighlightSat),
                              _ => (0.0, 0.0),
                            };
                            final swatch = HSVColor.fromAHSV(1.0, h, s, 0.85).toColor();
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: s > 0.01 ? swatch : scheme.outline,
                                    border: Border.all(color: Colors.white24, width: 0.5),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'H:${h.round()}° S:${(s * 100).round()}%',
                                  style: themeStyle(context, FontWeight.w700).copyWith(
                                    color: scheme.primary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ] else
                          Text(
                            '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}',
                            style: themeStyle(context, FontWeight.w700).copyWith(
                              color: scheme.primary,
                              fontSize: 11,
                            ),
                          ),
                        Container(
                          width: 1,
                          height: 18,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          color: scheme.outlineVariant,
                        ),
                        IconButton(
                          tooltip: 'HSL target: tap a colour in the photo, then '
                              'drag to adjust it',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          isSelected: ref.watch(tatModeProvider),
                          onPressed: () =>
                              ref.read(tatModeProvider.notifier).toggle(),
                          icon: const Icon(Icons.colorize, size: 17),
                          selectedIcon: Icon(Icons.colorize, size: 17, color: scheme.primary),
                        ),
                        IconButton(
                          key: const Key('selective-toggle'),
                          tooltip: 'Selective',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () => ref.read(nodeEditorProvider.notifier).enable(),
                          icon: const Icon(Icons.add_location_alt, size: 17),
                        ),
                        if (widget.hasHistogram)
                          IconButton(
                            key: const Key('histogram-toggle'),
                            tooltip: widget.histogramOpen ? 'Hide histogram' : 'Show histogram',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                            isSelected: widget.histogramOpen,
                            onPressed: widget.onToggleHistogram,
                            icon: const Icon(Icons.bar_chart, size: 17),
                            selectedIcon: Icon(Icons.bar_chart, size: 17, color: scheme.primary),
                          ),
                      ],
                    ),
                  ),
                ),
                ),
              ),
            ),
          ),

        // Floating straighten & rotation dial HUD
        if (_straightenOpen && !nodeMode)
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 74),
                child: DecoratedBox(
                  key: const Key('snapseed-straighten-panel'),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
                    borderRadius: Radii.mdAll,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
                    child: SizedBox(
                      width: 330,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Straighten & Rotate',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: scheme.onSurface,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                iconSize: 18,
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _straightenOpen = false),
                              ),
                            ],
                          ),
                          const PrecisionRotationDial(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),


        // Radial tool menu.
        if (_radialOpen)
          Positioned.fill(
            child: _RadialMenu(
              active: widget.tool,
              tools: widget.tools,
              iconOf: _icon,
              onDismiss: () => setState(() => _radialOpen = false),
              onPick: (t) {
                setState(() => _radialOpen = false);
                widget.onPickTool(t);
              },
            ),
          ),
      ],
    );
  }
}

TextStyle themeStyle(BuildContext context, FontWeight weight) =>
    Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: weight);

/// A tap-to-pick radial menu of every gesture tool.
class _RadialMenu extends StatelessWidget {
  const _RadialMenu({
    required this.active,
    required this.tools,
    required this.iconOf,
    required this.onDismiss,
    required this.onPick,
  });

  final GradeTool active;
  final List<GradeTool> tools;
  final IconData Function(GradeTool) iconOf;
  final VoidCallback onDismiss;
  final ValueChanged<GradeTool> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = 96.0;
    // Fixed hit-box (issue #46): each item paints a 56px circle + label but
    // gets a symmetric target around its ring point. The box is larger than
    // the painted circle so taps just outside the ring still hit the item
    // instead of the dismiss backdrop; Containers don't clip, so the label
    // painting past the box is fine.
    const hitW = 88.0;
    const hitH = 100.0;
    const half = radius + hitW / 2;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: ColoredBox(color: scheme.surface.withValues(alpha: 0.5)),
            ),
          ),
        ),
        // Recenter the ring inside the safe area so side cutouts (issue #47)
        // don't clip the outermost items; the dismiss backdrop stays full-bleed.
        SafeArea(
          child: Center(
            child: SizedBox(
              width: half * 2,
              height: half * 2,
              child: Stack(
                children: [
                  for (var i = 0; i < tools.length; i++)
                    Positioned(
                      left: half +
                          math.cos(-math.pi / 2 + i * 2 * math.pi / tools.length) *
                              radius -
                          hitW / 2,
                      top: half +
                          math.sin(-math.pi / 2 + i * 2 * math.pi / tools.length) *
                              radius -
                          hitH / 2,
                      child: GestureDetector(
                        key: Key('radial-${tools[i].name}'),
                        onTap: () => onPick(tools[i]),
                        child: Container(
                          width: hitW,
                          height: hitH,
                          color: Colors.transparent,
                          alignment: Alignment.topCenter,
                          child: _RadialItem(
                            icon: iconOf(tools[i]),
                            label: tools[i].name,
                            selected: tools[i] == active,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RadialItem extends StatelessWidget {
  const _RadialItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          ),
          child: Icon(
            icon,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
