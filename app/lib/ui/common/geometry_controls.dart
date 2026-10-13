import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/recipe_controller.dart';

/// Geometry controls: rotate (90°), flip, and straighten. Writes to the shared
/// recipe; the transform is non-destructive.
class GeometryControls extends ConsumerWidget {
  const GeometryControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final notifier = ref.read(recipeControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  notifier.rotate(-1);
                  notifier.commit(label: 'Rotate');
                },
                icon: const Icon(Icons.rotate_90_degrees_ccw),
                label: const Text('Left'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  notifier.rotate(1);
                  notifier.commit(label: 'Rotate');
                },
                icon: const Icon(Icons.rotate_90_degrees_cw),
                label: const Text('Right'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  notifier.toggleFlipH();
                  notifier.commit(label: 'Flip H');
                },
                icon: const Icon(Icons.flip),
                label: const Text('Flip H'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  notifier.toggleFlipV();
                  notifier.commit(label: 'Flip V');
                },
                icon: const Icon(Icons.flip_camera_android),
                label: const Text('Flip V'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const SizedBox(
                width: 84,
                child: Text('Straighten'),
              ),
              Expanded(
                child: Slider(
                  value: recipe.straighten.clamp(-45.0, 45.0),
                  min: -45,
                  max: 45,
                  onChanged: notifier.setStraighten,
                  onChangeEnd: (_) => notifier.commit(label: 'Straighten'),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  '${recipe.straighten.toStringAsFixed(1)}°',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
