import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/haptics.dart';
import '../edit/parameter.dart';
import '../edit/recipe_controller.dart';
import 'histogram_view.dart';

/// The live histogram, made interactive (ADR 0011): dragging the left third
/// adjusts Blacks, the middle Exposure, the right third Whites — desktop-
/// Lightroom ergonomics on a phone, without opening a panel.
class InteractiveHistogram extends ConsumerWidget {
  const InteractiveHistogram({super.key, this.height = 72});

  final double height;

  Parameter _parameterFor(double fraction) {
    if (fraction < 1 / 3) return Parameter.blacks;
    if (fraction > 2 / 3) return Parameter.whites;
    return Parameter.exposure;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histogram = ref.watch(histogramProvider);
    if (histogram == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            final fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
            final parameter = _parameterFor(fraction);
            final spec = specOf(parameter);
            final delta = details.delta.dx / width;
            final previous = valueOf(
              ref.read(recipeControllerProvider).recipe,
              parameter,
            );
            ref.read(recipeControllerProvider.notifier).applyDelta(
              parameter,
              delta,
            );
            final next = clampParameter(
              parameter,
              previous + delta * spec.scale,
            );
            fireHaptic(hapticFor(previous, next, spec.min, spec.max));
          },
          child: HistogramView(histogram: histogram, height: height),
        );
      },
    );
  }
}
