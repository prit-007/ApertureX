import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../color/blur_spec.dart';
import '../../edit/active_image.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
import '../../engine/engine.dart';
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
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                ActionChip(
                  key: const Key('blur-detect-depth'),
                  avatar: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Calibrate Embedded Depth'),
                  onPressed: () async {
                    final bytes = ref.read(activeImageBytesProvider);
                    if (bytes == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No photo loaded to read depth metadata')),
                      );
                      return;
                    }
                    final depthResult = await AxEngine.extractEmbeddedDepth(bytes);
                    if (depthResult != null) {
                      HapticFeedback.selectionClick();
                      notifier.update(Parameter.blurFocalPoint, 0.35);
                      notifier.update(Parameter.blurFocalRange, 0.25);
                      notifier.commit(label: 'Calibrate Depth');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Calibrated depth: ${depthResult.width}×${depthResult.height} embedded map',
                            ),
                          ),
                        );
                      }
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No embedded depth map found; using synthetic plane'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
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
