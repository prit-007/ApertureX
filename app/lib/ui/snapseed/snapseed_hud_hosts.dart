import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/recipe_mapping.dart';
import '../../gesture/gesture_interpreter.dart';
import '../../gesture/zone_mask.dart';
import 'snapseed_gesture_hud.dart';

TextStyle themeStyle(BuildContext context, FontWeight weight) =>
    (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(fontWeight: weight);

class SnapseedScrubHudHost extends ConsumerWidget {
  const SnapseedScrubHudHost({
    super.key,
    required this.tool,
    required this.gesturePhase,
    required this.scrubVisible,
    required this.nodeMode,
  });

  final GradeTool tool;
  final GesturePhase gesturePhase;
  final bool scrubVisible;
  final bool nodeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parameter = primaryParameterForTool(tool);
    final zoneMask = ref.watch(zoneMaskProvider);
    final value = ref.watch(
      recipeControllerProvider.select((s) {
        final recipe = s.recipe;
        final lockedIdx = zoneMask.lockedLayerIndex;
        if (lockedIdx != null && lockedIdx < recipe.layers.length) {
          final layer = recipe.layers[lockedIdx];
          return switch (parameter) {
            Parameter.exposure => layer.exposure,
            Parameter.contrast => layer.contrast,
            Parameter.highlights => layer.highlights,
            Parameter.shadows => layer.shadows,
            Parameter.saturation => layer.saturation,
            Parameter.temperature => layer.temperature,
            Parameter.tint => layer.tint,
            _ => valueOf(recipe, parameter),
          };
        }
        return valueOf(recipe, parameter);
      }),
    );

    final (hue, sat) = tool.is2D
        ? ref.watch(
            recipeControllerProvider.select((s) {
              final recipe = s.recipe;
              return switch (tool) {
                GradeTool.shadowsGrade => (recipe.gradeShadowHue, recipe.gradeShadowSat),
                GradeTool.midtonesGrade => (recipe.gradeMidHue, recipe.gradeMidSat),
                GradeTool.highlightsGrade => (recipe.gradeHighlightHue, recipe.gradeHighlightSat),
                _ => (0.0, 0.0),
              };
            }),
          )
        : (null, null);

    return AnimatedOpacity(
      opacity: ((gesturePhase == GesturePhase.scrubbing || scrubVisible) && !nodeMode)
          ? 1.0
          : 0.0,
      duration: AppMotion.responsive(context, AppMotion.shortDuration),
      curve: AppMotion.scrubCurve,
      child: IgnorePointer(
        child: SnapseedScrubHud(
          key: const Key('snapseed-scrub-hud-root'),
          tool: tool,
          value: value,
          hue: hue,
          sat: sat,
          visible: true,
        ),
      ),
    );
  }
}

class SnapseedCarouselHost extends ConsumerWidget {
  const SnapseedCarouselHost({
    super.key,
    required this.category,
    required this.tools,
    required this.activeTool,
    required this.visible,
  });

  final ToolCategory category;
  final List<GradeTool> tools;
  final GradeTool activeTool;
  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = ref.watch(
      recipeControllerProvider.select((s) {
        final recipe = s.recipe;
        return {
          for (final t in tools)
            if (!t.is2D && (snapseedToolParameters[t]?.isNotEmpty ?? false))
              t: valueOf(recipe, primaryParameterForTool(t)),
        };
      }),
    );

    return SnapseedParameterCarousel(
      category: category,
      tools: tools,
      activeTool: activeTool,
      values: values,
      visible: visible,
    );
  }
}

class Snapseed2DColorIndicator extends ConsumerWidget {
  const Snapseed2DColorIndicator({super.key, required this.tool});

  final GradeTool tool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final (h, s) = ref.watch(
      recipeControllerProvider.select((s) {
        final recipe = s.recipe;
        return switch (tool) {
          GradeTool.shadowsGrade => (recipe.gradeShadowHue, recipe.gradeShadowSat),
          GradeTool.midtonesGrade => (recipe.gradeMidHue, recipe.gradeMidSat),
          GradeTool.highlightsGrade => (recipe.gradeHighlightHue, recipe.gradeHighlightSat),
          _ => (0.0, 0.0),
        };
      }),
    );
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
            border: Border.all(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
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
  }
}

class Snapseed1DValueIndicator extends ConsumerWidget {
  const Snapseed1DValueIndicator({super.key, required this.tool});

  final GradeTool tool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final parameter = primaryParameterForTool(tool);
    final zoneMask = ref.watch(zoneMaskProvider);
    final value = ref.watch(
      recipeControllerProvider.select((s) {
        final recipe = s.recipe;
        final lockedIdx = zoneMask.lockedLayerIndex;
        if (lockedIdx != null && lockedIdx < recipe.layers.length) {
          final layer = recipe.layers[lockedIdx];
          return switch (parameter) {
            Parameter.exposure => layer.exposure,
            Parameter.contrast => layer.contrast,
            Parameter.highlights => layer.highlights,
            Parameter.shadows => layer.shadows,
            Parameter.saturation => layer.saturation,
            Parameter.temperature => layer.temperature,
            Parameter.tint => layer.tint,
            _ => valueOf(recipe, parameter),
          };
        }
        return valueOf(recipe, parameter);
      }),
    );

    return Text(
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}',
      style: themeStyle(context, FontWeight.w700).copyWith(
        color: scheme.primary,
        fontSize: 11,
      ),
    );
  }
}
