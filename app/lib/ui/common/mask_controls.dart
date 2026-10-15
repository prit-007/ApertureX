import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/adjustment_layer.dart';
import '../../edit/node_editor.dart';
import '../../viewport/mask_peek.dart';
import '../../edit/recipe_controller.dart';

/// Local-adjustment (masking) controls: add analytic masks and manage the
/// layer stack. Masks are parametric, so no brush data is stored (#18).
class MaskControls extends ConsumerWidget {
  const MaskControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layers = ref.watch(recipeControllerProvider).recipe.layers;
    final notifier = ref.read(recipeControllerProvider.notifier);
    final stylusOnly = ref.watch(stylusOnlyModeProvider);
    final nodeMode = ref.watch(nodeEditorProvider.select((s) => s.enabled));

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('edit-on-canvas'),
                onPressed: () =>
                    ref.read(nodeEditorProvider.notifier).toggle(),
                icon: Icon(
                  nodeMode ? Icons.check : Icons.touch_app,
                ),
                label: Text(
                  nodeMode ? 'Done placing' : 'Edit on canvas',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final idx = layers.length;
                  notifier.addLayer(
                    const AdjustmentLayer(
                      maskKind: MaskKind.brush,
                      maskParams: [0.06, 0.25, 0],
                      exposure: 0.6,
                    ),
                  );
                  ref.read(nodeEditorProvider.notifier).enable();
                  ref.read(nodeEditorProvider.notifier).select(idx);
                },
                icon: const Icon(Icons.brush),
                label: const Text('Brush +'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final idx = layers.length;
                  notifier.addLayer(
                    const AdjustmentLayer(
                      maskKind: MaskKind.linear,
                      maskParams: [0.5, 0.2, 0.5, 0.8],
                      exposure: 0.6,
                    ),
                  );
                  ref.read(nodeEditorProvider.notifier).enable();
                  ref.read(nodeEditorProvider.notifier).select(idx);
                },
                icon: const Icon(Icons.gradient),
                label: const Text('Linear +'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final idx = layers.length;
                  notifier.addLayer(
                    const AdjustmentLayer(
                      maskKind: MaskKind.radial,
                      maskParams: [0.5, 0.5, 0.25, 0.25, 0.3],
                      exposure: 0.7,
                    ),
                  );
                  ref.read(nodeEditorProvider.notifier).enable();
                  ref.read(nodeEditorProvider.notifier).select(idx);
                },
                icon: const Icon(Icons.brightness_5),
                label: const Text('Radial +'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final idx = layers.length;
                  notifier.addLayer(
                    const AdjustmentLayer(
                      maskKind: MaskKind.subject,
                      maskParams: [0.5, 0.5, 0.28, 0.38, 0.25],
                      exposure: 0.5,
                    ),
                  );
                  ref.read(nodeEditorProvider.notifier).enable();
                  ref.read(nodeEditorProvider.notifier).select(idx);
                },
                icon: const Icon(Icons.person),
                label: const Text('Subject +'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final idx = layers.length;
                  notifier.addLayer(
                    const AdjustmentLayer(
                      maskKind: MaskKind.sky,
                      maskParams: [0.5, 0.15, 0.6],
                      highlights: -0.6,
                      saturation: 0.2,
                    ),
                  );
                  ref.read(nodeEditorProvider.notifier).enable();
                  ref.read(nodeEditorProvider.notifier).select(idx);
                },
                icon: const Icon(Icons.cloud_outlined),
                label: const Text('Sky +'),
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
              OutlinedButton.icon(
                onPressed: () => _toggleStylusOnly(ref, !stylusOnly),
                icon: const Icon(Icons.gesture),
                label: stylusOnly
                    ? const Text('Touch mode')
                    : const Text('Stylus mode'),
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
            selected: i == ref.watch(nodeEditorProvider.select((s) => s.selected)),
            leading: Icon(_maskIcon(layers[i].maskKind), size: 18),
            title: Text(
              '${layers[i].maskKind.name.toUpperCase()} layer  '
              'EV ${layers[i].exposure.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: layers[i].inverted
                ? const Text('Inverted', style: TextStyle(fontSize: 11, color: Colors.orange))
                : null,
            onTap: () {
              ref.read(nodeEditorProvider.notifier).select(i);
              ref.read(nodeEditorProvider.notifier).enable();
            },
            trailing: IconButton(
              tooltip: 'Remove layer',
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () => notifier.removeLayerAt(i),
            ),
          ),
      ],
    );
  }

  IconData _maskIcon(MaskKind kind) => switch (kind) {
    MaskKind.brush => Icons.brush,
    MaskKind.linear => Icons.gradient,
    MaskKind.radial => Icons.brightness_5,
    MaskKind.subject => Icons.person,
    MaskKind.sky => Icons.cloud_outlined,
    MaskKind.luminance => Icons.dark_mode,
  };

  void _toggleStylusOnly(WidgetRef ref, bool value) {
    ref.read(stylusOnlyModeProvider.notifier).set(value);
  }
}