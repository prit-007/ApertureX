import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../color/blur_spec.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
import 'app_primitives.dart';
import 'parameter_control.dart';

/// Blur controls: depth-aware synthetic aperture, focal point/range, bokeh blade shapes, and specular highlight boost.
class BlurControls extends ConsumerWidget {
  const BlurControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final notifier = ref.read(recipeControllerProvider.notifier);

    final currentShapeIndex = recipe.blurBokehShape.clamp(0, BokehShape.values.length - 1);
    final currentShape = BokehShape.values[currentShapeIndex];

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        const SectionHeader('Lens Blur'),
        SwitchListTile(
          title: const Text('Depth-Aware Lens Blur'),
          subtitle: const Text('Simulate optical depth-of-field and aperture bokeh'),
          value: recipe.blurEnabled,
          onChanged: (val) {
            notifier.setBlurEnabled(val);
          },
        ),
        if (recipe.blurEnabled) ...[
          const SectionHeader('Focus & Depth'),
          const ParameterControl(parameter: Parameter.blurAmount),
          const ParameterControl(parameter: Parameter.blurFocalPoint),
          const ParameterControl(parameter: Parameter.blurFocalRange),
          const SectionHeader('Bokeh Shape'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final shape in BokehShape.values)
                  ChoiceChip(
                    label: Text(shape.label),
                    selected: shape == currentShape,
                    onSelected: (selected) {
                      if (selected) {
                        notifier.setBlurBokehShape(shape.index);
                      }
                    },
                  ),
              ],
            ),
          ),
          const SectionHeader('Specular Highlights'),
          const ParameterControl(parameter: Parameter.blurBokehBoost),
        ],
      ],
    );
  }
}
