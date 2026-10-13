import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/adjustment_layer.dart';
import '../../edit/recipe_controller.dart';

/// Local-adjustment (masking) controls: add analytic masks and manage the
/// layer stack. Masks are parametric, so no brush data is stored (#18).
class MaskControls extends ConsumerWidget {
  const MaskControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layers = ref.watch(recipeControllerProvider).recipe.layers;
    final notifier = ref.read(recipeControllerProvider.notifier);

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => notifier.addLayer(
                  const AdjustmentLayer(exposure: 0.7),
                ),
                icon: const Icon(Icons.brightness_5),
                label: const Text('Radial +'),
              ),
              OutlinedButton.icon(
                onPressed: () => notifier.addLayer(
                  const AdjustmentLayer(
                    maskKind: MaskKind.linear,
                    maskParams: [0, 0, 0, 1],
                    exposure: 0.6,
                  ),
                ),
                icon: const Icon(Icons.gradient),
                label: const Text('Linear +'),
              ),
              OutlinedButton.icon(
                onPressed: () => notifier.addLayer(
                  const AdjustmentLayer(
                    maskKind: MaskKind.luminance,
                    maskParams: [0, 0.4],
                    exposure: 0.8,
                  ),
                ),
                icon: const Icon(Icons.dark_mode),
                label: const Text('Darks +'),
              ),
            ],
          ),
        ),
        if (layers.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No local adjustments. Add a mask above.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        for (var i = 0; i < layers.length; i++)
          ListTile(
            dense: true,
            leading: const Icon(Icons.adjust, size: 18),
            title: Text(
              '${layers[i].maskKind.name} layer  '
              'EV ${layers[i].exposure.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13),
            ),
            trailing: IconButton(
              tooltip: 'Remove layer',
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () => notifier.removeLayerAt(i),
            ),
          ),
      ],
    );
  }
}
