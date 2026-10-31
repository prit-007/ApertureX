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

    Widget card(Widget child) => Material(
      key: const Key('node-controls'),
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.95),
      borderRadius: Radii.mdAll,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: Radii.mdAll,
          border: Border.all(color: scheme.outlineVariant),
        ),
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
    if (i == null || i < 0 || i >= layers.length) {
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
                'Select or add a mask above; drag on canvas to adjust.',
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
    final notifier = ref.read(recipeControllerProvider.notifier);

    return card(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(_maskIcon(layer.maskKind), size: 16, color: scheme.primary),
              const SizedBox(width: Insets.xs),
              Text(
                'Node ${i + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: Insets.xs),
              FilterChip(
                label: const Text('Invert', style: TextStyle(fontSize: 11)),
                selected: layer.inverted,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onSelected: (val) {
                  notifier.updateLayerAt(i, layer.copyWith(inverted: val));
                },
              ),
              const Spacer(),
              IconButton(
                key: const Key('node-delete'),
                tooltip: 'Delete layer',
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                onPressed: () {
                  notifier.removeLayerAt(i);
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
          if (layer.maskKind == MaskKind.brush) ...[
            Row(
              children: [
                ChoiceChip(
                  key: const Key('node-brush-paint'),
                  label: const Text('Paint', style: TextStyle(fontSize: 11)),
                  selected: !editor.eraserMode,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onSelected: (val) {
                    if (val) {
                      ref.read(nodeEditorProvider.notifier).setEraserMode(false);
                    }
                  },
                ),
                const SizedBox(width: Insets.xs),
                ChoiceChip(
                  key: const Key('node-brush-erase'),
                  label: const Text('Erase', style: TextStyle(fontSize: 11)),
                  selected: editor.eraserMode,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onSelected: (val) {
                    if (val) {
                      ref.read(nodeEditorProvider.notifier).setEraserMode(true);
                    }
                  },
                ),
                const Spacer(),
                if (layer.brushPointCount > 0)
                  TextButton.icon(
                    key: const Key('node-brush-clear'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    icon: const Icon(Icons.clear, size: 14),
                    label: const Text('Clear', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      notifier.updateLayerAt(i, layer.withClearedStrokes());
                    },
                  ),
              ],
            ),
            _LayerSlider(
              label: 'Size',
              valueLabel: '${(layer.brushRadius * 100).round()}%',
              value: layer.brushRadius.clamp(0.01, 0.5),
              min: 0.01,
              max: 0.5,
              sliderKey: const Key('node-brush-size-slider'),
              onChanged: (v) => notifier.updateLayerAt(i, layer.withBrushRadius(v)),
            ),
            _LayerSlider(
              label: 'Feather',
              valueLabel: '${(layer.brushFeather * 100).round()}%',
              value: layer.brushFeather.clamp(0.0, 1.0),
              min: 0.0,
              max: 1.0,
              sliderKey: const Key('node-brush-feather-slider'),
              onChanged: (v) => notifier.updateLayerAt(i, layer.withBrushFeather(v)),
            ),
          ],
          if (layer.maskKind == MaskKind.radial && layer.maskParams.length >= 5)
            _LayerSlider(
              label: 'Radius',
              valueLabel: '${(layer.maskParams[2] * 100).round()}%',
              value: layer.maskParams[2].clamp(0.03, 0.6),
              min: 0.03,
              max: 0.6,
              sliderKey: const Key('node-radius-slider'),
              onChanged: (v) {
                final t = ref.read(canvasTransformProvider);
                final p = layer.maskParams;
                final aspect =
                    t != null
                        ? t.aspect
                        : (p[2] > 0 ? p[3] / p[2] : 1.0);
                notifier.updateLayerAt(
                  i,
                  layer.copyWith(
                    maskParams: [p[0], p[1], v, v * aspect, p[4]],
                  ),
                );
              },
            ),
          _LayerSlider(
            label: 'Amount',
            valueLabel: '${(layer.amount * 100).round()}%',
            value: layer.amount.clamp(0.0, 2.0),
            min: 0.0,
            max: 2.0,
            sliderKey: const Key('node-amount-slider'),
            onChanged: (v) => notifier.updateLayerAt(i, layer.copyWith(amount: v)),
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
            onChanged: (v) => notifier.updateLayerAt(i, layer.copyWith(exposure: v)),
          ),
          _LayerSlider(
            label: 'Contrast',
            valueLabel:
                '${layer.contrast >= 0 ? '+' : ''}'
                '${layer.contrast.toStringAsFixed(2)}',
            value: layer.contrast.clamp(-1.0, 1.0),
            min: -1,
            max: 1,
            sliderKey: const Key('node-contrast-slider'),
            onChanged: (v) => notifier.updateLayerAt(i, layer.copyWith(contrast: v)),
          ),
          _LayerSlider(
            label: 'Highlights',
            valueLabel:
                '${layer.highlights >= 0 ? '+' : ''}'
                '${layer.highlights.toStringAsFixed(2)}',
            value: layer.highlights.clamp(-1.0, 1.0),
            min: -1,
            max: 1,
            sliderKey: const Key('node-highlights-slider'),
            onChanged: (v) => notifier.updateLayerAt(i, layer.copyWith(highlights: v)),
          ),
          _LayerSlider(
            label: 'Shadows',
            valueLabel:
                '${layer.shadows >= 0 ? '+' : ''}'
                '${layer.shadows.toStringAsFixed(2)}',
            value: layer.shadows.clamp(-1.0, 1.0),
            min: -1,
            max: 1,
            sliderKey: const Key('node-shadows-slider'),
            onChanged: (v) => notifier.updateLayerAt(i, layer.copyWith(shadows: v)),
          ),
          _LayerSlider(
            label: 'Saturation',
            valueLabel:
                '${layer.saturation >= 0 ? '+' : ''}'
                '${layer.saturation.toStringAsFixed(2)}',
            value: layer.saturation.clamp(-1.0, 1.0),
            min: -1,
            max: 1,
            sliderKey: const Key('node-saturation-slider'),
            onChanged: (v) => notifier.updateLayerAt(i, layer.copyWith(saturation: v)),
          ),
          _LayerSlider(
            label: 'Temp',
            valueLabel:
                '${layer.temperature >= 0 ? '+' : ''}'
                '${layer.temperature.toStringAsFixed(2)}',
            value: layer.temperature.clamp(-1.0, 1.0),
            min: -1,
            max: 1,
            sliderKey: const Key('node-temperature-slider'),
            onChanged: (v) => notifier.updateLayerAt(i, layer.copyWith(temperature: v)),
          ),
          _LayerSlider(
            label: 'Tint',
            valueLabel:
                '${layer.tint >= 0 ? '+' : ''}'
                '${layer.tint.toStringAsFixed(2)}',
            value: layer.tint.clamp(-1.0, 1.0),
            min: -1,
            max: 1,
            sliderKey: const Key('node-tint-slider'),
            onChanged: (v) => notifier.updateLayerAt(i, layer.copyWith(tint: v)),
          ),
        ],
      ),
    );
  }

  static IconData _maskIcon(MaskKind kind) => switch (kind) {
    MaskKind.brush => Icons.brush,
    MaskKind.linear => Icons.gradient,
    MaskKind.radial => Icons.brightness_5,
    MaskKind.subject => Icons.person,
    MaskKind.sky => Icons.cloud_outlined,
    MaskKind.luminance => Icons.dark_mode,
    MaskKind.bitmap => Icons.auto_awesome,
    MaskKind.colorRange => Icons.color_lens_outlined,
    MaskKind.autoBrush => Icons.auto_fix_normal,
    MaskKind.depthRange => Icons.layers_outlined,
  };
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
