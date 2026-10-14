import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';

/// A persistent, minimalist HUD for the gesture shell: lists **only** the
/// parameters whose value is non-neutral, so you always see what you've changed
/// without losing the invisible canvas (ADR 0011).
class EditHud extends ConsumerWidget {
  const EditHud({super.key});

  /// Half the two-decimal display resolution: a value below this renders as
  /// `±0.00` and counts as neutral (issue #42 — float noise from fractional
  /// drags must not stick a badge in the HUD forever).
  static const double neutralEpsilon = 0.005;

  static const Map<Parameter, String> _abbr = {
    Parameter.exposure: 'EXP',
    Parameter.contrast: 'CON',
    Parameter.highlights: 'HIL',
    Parameter.shadows: 'SHA',
    Parameter.whites: 'WHI',
    Parameter.blacks: 'BLA',
    Parameter.clarity: 'CLA',
    Parameter.texture: 'TEX',
    Parameter.sharpen: 'SHP',
    Parameter.temperature: 'TEM',
    Parameter.tint: 'TIN',
    Parameter.vibrance: 'VIB',
    Parameter.saturation: 'SAT',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final changed = [
      for (final p in Parameter.values)
        if (valueOf(recipe, p).abs() > neutralEpsilon) p,
    ];
    if (changed.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.end,
          children: [
            for (final p in changed)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_abbr[p] ?? p.name.toUpperCase()} '
                  '${valueOf(recipe, p) >= 0 ? '+' : ''}'
                  '${valueOf(recipe, p).toStringAsFixed(2)}',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
