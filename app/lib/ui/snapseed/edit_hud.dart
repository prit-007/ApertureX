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
    final hudData = ref.watch(
      recipeControllerProvider.select((s) {
        final recipe = s.recipe;
        final changed = <Parameter>[];
        for (final p in Parameter.values) {
          if ((valueOf(recipe, p) - specOf(p).neutral).abs() > neutralEpsilon) {
            changed.add(p);
          }
        }
        if (changed.isEmpty) return const _HudData([], 0);
        final visibleParams = changed.take(4);
        final visible = [
          for (final p in visibleParams)
            _HudItem(
              p,
              '${_abbr[p] ?? p.name.toUpperCase()} '
              '${valueOf(recipe, p) >= 0 ? '+' : ''}'
              '${valueOf(recipe, p).toStringAsFixed(2)}',
            ),
        ];
        return _HudData(visible, changed.length - visible.length);
      }),
    );

    if (hudData.visible.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topRight,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: [
              for (final item in hudData.visible)
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
                    item.text,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              if (hudData.overflowCount > 0)
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
                    '+${hudData.overflowCount} more',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudItem {
  const _HudItem(this.param, this.text);

  final Parameter param;
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HudItem && other.param == param && other.text == text;

  @override
  int get hashCode => Object.hash(param, text);
}

class _HudData {
  const _HudData(this.visible, this.overflowCount);

  final List<_HudItem> visible;
  final int overflowCount;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _HudData) return false;
    if (other.overflowCount != overflowCount || other.visible.length != visible.length) return false;
    for (var i = 0; i < visible.length; i++) {
      if (visible[i] != other.visible[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(visible), overflowCount);
}
