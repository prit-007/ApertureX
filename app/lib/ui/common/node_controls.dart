import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/adjustment_layer.dart';
import '../../edit/node_editor.dart';
import '../../edit/recipe_controller.dart';
import '../../viewport/canvas_transform.dart';

/// The floating adjust bar shown while node mode (issue #25) is active:
/// identifies the selected control point and edits its exposure and radius.
/// With nothing selected it shows a placement hint. "Done" leaves node mode.
class NodeControls extends ConsumerWidget {
  const NodeControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(nodeEditorProvider);
    if (!editor.enabled) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final layers = ref.watch(
      recipeControllerProvider.select((s) => s.recipe.layers),
    );

    Widget card(Widget child) => DecoratedBox(
      key: const Key('node-controls'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.95),
        borderRadius: Radii.mdAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.md,
          Insets.xs,
          Insets.xs,
          Insets.sm,
        ),
        child: child,
      ),
    );

    Widget header(String title) => Row(
      children: [
        Icon(Icons.add_location_alt, size: 16, color: scheme.primary),
        const SizedBox(width: Insets.xs),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const Spacer(),
        TextButton(
          key: const Key('node-done'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
          ),
          onPressed: () => ref.read(nodeEditorProvider.notifier).disable(),
          child: const Text('Done'),
        ),
      ],
    );

    final i = editor.selected;
    if (i == null ||
        i < 0 ||
        i >= layers.length ||
        layers[i].maskKind != MaskKind.radial ||
        layers[i].maskParams.length < 5) {
      // Nothing selected (or the selection went stale after a recipe change).
      return card(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            header('Selective'),
            Padding(
              padding: const EdgeInsets.only(
                left: Insets.xs,
                right: Insets.md,
                bottom: Insets.xs,
              ),
              child: Text(
                'Tap the photo to place a control point; drag it to move, '
                'drag its ring to resize.',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final layer = layers[i];
    return card(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.add_location_alt, size: 16, color: scheme.primary),
              const SizedBox(width: Insets.xs),
              Text(
                'Node ${i + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                key: const Key('node-delete'),
                tooltip: 'Delete control point',
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                onPressed: () {
                  ref.read(recipeControllerProvider.notifier).removeLayerAt(i);
                  ref.read(nodeEditorProvider.notifier).select(null);
                },
                icon: const Icon(Icons.delete_outline),
              ),
              TextButton(
                key: const Key('node-done'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                ),
                onPressed: () =>
                    ref.read(nodeEditorProvider.notifier).disable(),
                child: const Text('Done'),
              ),
            ],
          ),
          _LayerSlider(
            label: 'Exposure',
            valueLabel:
                '${layer.exposure >= 0 ? '+' : ''}'
                '${layer.exposure.toStringAsFixed(2)}',
            value: layer.exposure.clamp(-2.0, 2.0),
            min: -2,
            max: 2,
            sliderKey: const Key('node-exposure-slider'),
            onChanged: (v) => ref
                .read(recipeControllerProvider.notifier)
                .updateLayerAt(i, layer.copyWith(exposure: v)),
          ),
          _LayerSlider(
            label: 'Radius',
            valueLabel: '${(layer.maskParams[2] * 100).round()}%',
            value: layer.maskParams[2].clamp(0.03, 0.6),
            min: 0.03,
            max: 0.6,
            sliderKey: const Key('node-radius-slider'),
            onChanged: (v) {
              // Keep the ellipse circular on screen: ry scales with the
              // image aspect (or the layer's current ratio as fallback).
              final t = ref.read(canvasTransformProvider);
              final p = layer.maskParams;
              final aspect =
                  t != null
                      ? t.aspect
                      : (p[2] > 0 ? p[3] / p[2] : 1.0);
              ref
                  .read(recipeControllerProvider.notifier)
                  .updateLayerAt(
                    i,
                    layer.copyWith(
                      maskParams: [p[0], p[1], v, v * aspect, p[4]],
                    ),
                  );
            },
          ),
        ],
      ),
    );
  }
}

/// One label → slider → value row, matching the geometry panel's layout.
class _LayerSlider extends StatelessWidget {
  const _LayerSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.sliderKey,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final Key sliderKey;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: Slider(
            key: sliderKey,
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            valueLabel,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
