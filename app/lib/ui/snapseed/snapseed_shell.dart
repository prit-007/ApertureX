import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/recipe_mapping.dart';
import '../../gesture/gesture_interpreter.dart';
import 'edit_hud.dart';

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
  });

  final GradeTool tool;
  final ToolCategory category;
  final List<GradeTool> tools;
  final VoidCallback onCycleCategory;
  final ValueChanged<GradeTool> onPickTool;

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
    GradeTool.sharpen => Icons.details,
  };

  @override
  Widget build(BuildContext context) {
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final parameter = snapseedToolParameters[widget.tool]!.first;
    final spec = specOf(parameter);
    final value = valueOf(recipe, parameter);
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Recent-changes HUD (top-right).
        const Positioned(top: 0, right: 0, child: EditHud()),

        // Active-tool HUD (bottom).
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Insets.lg),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
                  borderRadius: Radii.pillAll,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.xs, Insets.sm, Insets.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: widget.onCycleCategory,
                        borderRadius: Radii.smAll,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.sm,
                            vertical: Insets.xs,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _categoryLabel(widget.category),
                                style: themeStyle(
                                  context,
                                  FontWeight.w600,
                                ).copyWith(color: scheme.onSurfaceVariant),
                              ),
                              const Icon(Icons.unfold_more, size: 16),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        color: scheme.outlineVariant,
                      ),
                      const SizedBox(width: Insets.md),
                      Text(
                        spec.label,
                        style: themeStyle(context, FontWeight.w600),
                      ),
                      const SizedBox(width: Insets.md),
                      Text(
                        '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}',
                        style: themeStyle(context, FontWeight.w700).copyWith(
                          color: scheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      IconButton(
                        tooltip: 'Tools',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _radialOpen = true),
                        icon: const Icon(Icons.radio_button_checked, size: 20),
                      ),
                    ],
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
    const itemRadius = 28.0;
    const half = radius + itemRadius;
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
        Center(
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
                        itemRadius,
                    top: half +
                        math.sin(-math.pi / 2 + i * 2 * math.pi / tools.length) *
                            radius -
                        itemRadius,
                    child: _RadialItem(
                      icon: iconOf(tools[i]),
                      label: tools[i].name,
                      selected: tools[i] == active,
                      onTap: () => onPick(tools[i]),
                    ),
                  ),
              ],
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
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      key: Key('radial-$label'),
      onTap: onTap,
      child: Column(
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
      ),
    );
  }
}
