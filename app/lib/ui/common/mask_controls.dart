import 'dart:typed_data';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/active_image.dart';
import '../../edit/adjustment_layer.dart';
import '../../edit/node_editor.dart';
import '../../edit/recipe_controller.dart';
import '../../engine/engine.dart';
import '../../engine/image_format.dart';
import '../../viewport/mask_peek.dart';

/// Function signature for sky detection from photo bytes.
typedef SkyDetectorFn = Future<DetectedSky?> Function(Uint8List imageBytes);

/// Riverpod provider for sky detection, overridable in tests.
final skyDetectorProvider = Provider<SkyDetectorFn>((ref) {
  return (Uint8List bytes) async {
    final decoded = isRawImage(bytes)
        ? await AxEngine.decodeRawRgba(bytes)
        : await AxEngine.decodeJpegRgba(bytes);
    return AxEngine.detectSky(
      decoded.rgba,
      width: decoded.width,
      height: decoded.height,
    );
  };
});

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
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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
                key: const Key('mask-add-background'),
                onPressed: () {
                  final idx = layers.length;
                  notifier.addLayer(
                    const AdjustmentLayer(
                      maskKind: MaskKind.subject,
                      maskParams: [0.5, 0.5, 0.28, 0.38, 0.25],
                      inverted: true,
                      exposure: -0.4,
                    ),
                  );
                  ref.read(nodeEditorProvider.notifier).enable();
                  ref.read(nodeEditorProvider.notifier).select(idx);
                  HapticFeedback.selectionClick();
                },
                icon: const Icon(Icons.wallpaper),
                label: const Text('Background +'),
              ),
              OutlinedButton.icon(
                key: const Key('mask-add-sky'),
                onPressed: () async {
                  final idx = layers.length;
                  var horizon = 0.5;
                  var feather = 0.15;
                  var blueWeight = 0.6;

                  final bytes = ref.read(activeImageBytesProvider);
                  if (bytes != null) {
                    try {
                      final detector = ref.read(skyDetectorProvider);
                      final detected = await detector(bytes);
                      if (detected != null) {
                        horizon = detected.horizonY;
                        feather = detected.feather;
                        blueWeight = detected.blueWeight;
                      }
                    } catch (_) {
                      // Fallback to default params
                    }
                  }

                  notifier.addLayer(
                    AdjustmentLayer(
                      maskKind: MaskKind.sky,
                      maskParams: [horizon, feather, blueWeight],
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
                key: const Key('mask-add-depth'),
                onPressed: () async {
                  final bytes = ref.read(activeImageBytesProvider);
                  if (bytes == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No photo loaded for depth extraction')),
                    );
                    return;
                  }
                  final depthResult = await AxEngine.extractEmbeddedDepth(bytes);
                  if (depthResult != null) {
                    final alphas = depthResult.depth.map((b) => b / 255.0).toList();
                    final idx = layers.length;
                    notifier.addLayer(
                      AdjustmentLayer.bitmap(
                        width: depthResult.width,
                        height: depthResult.height,
                        alphas: alphas,
                        exposure: 0.3,
                      ),
                    );
                    ref.read(nodeEditorProvider.notifier).enable();
                    ref.read(nodeEditorProvider.notifier).select(idx);
                    HapticFeedback.selectionClick();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Loaded embedded portrait depth mask')),
                      );
                    }
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No embedded depth map in photo metadata')),
                    );
                  }
                },
                icon: const Icon(Icons.blur_on),
                label: const Text('Depth +'),
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
        for (var i = 0; i < layers.length; i++) ...[
          Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              selected: i == ref.watch(nodeEditorProvider.select((s) => s.selected)),
              leading: Icon(_maskIcon(layers[i].maskKind), size: 18),
              title: Text(
                '${layers[i].maskKind.name.toUpperCase()} layer ${i + 1}  '
                'EV ${layers[i].exposure >= 0 ? '+' : ''}${layers[i].exposure.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: layers[i].inverted
                  ? const Text(
                      'Inverted (Reversed)',
                      style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                    )
                  : null,
              onTap: () {
                ref.read(nodeEditorProvider.notifier).select(i);
                ref.read(nodeEditorProvider.notifier).enable();
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('mask-invert-$i'),
                    tooltip: 'Invert / Reverse mask',
                    icon: Icon(
                      layers[i].inverted ? Icons.swap_horiz : Icons.swap_horizontal_circle_outlined,
                      size: 18,
                    ),
                    onPressed: () =>
                        notifier.updateLayerAt(i, layers[i].copyWith(inverted: !layers[i].inverted)),
                  ),
                  IconButton(
                    key: Key('mask-duplicate-$i'),
                    tooltip: 'Duplicate mask',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => notifier.addLayer(layers[i].copyWith()),
                  ),
                  IconButton(
                    key: Key('mask-delete-$i'),
                    tooltip: 'Remove layer',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () {
                      notifier.removeLayerAt(i);
                      if (ref.read(nodeEditorProvider).selected == i) {
                        ref.read(nodeEditorProvider.notifier).select(null);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          if (i == ref.watch(nodeEditorProvider.select((s) => s.selected)))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilterChip(
                            key: const Key('mask-inline-invert'),
                            label: const Text('Invert', style: TextStyle(fontSize: 11)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            selected: layers[i].inverted,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            onSelected: (val) {
                              notifier.updateLayerAt(i, layers[i].copyWith(inverted: val));
                            },
                          ),
                          if (layers[i].maskKind == MaskKind.brush) ...[
                            ChoiceChip(
                              key: const Key('mask-inline-brush-paint'),
                              label: const Text('Paint', style: TextStyle(fontSize: 11)),
                              selected: !ref.watch(nodeEditorProvider.select((s) => s.eraserMode)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              showCheckmark: false,
                              onSelected: (val) {
                                if (val) ref.read(nodeEditorProvider.notifier).setEraserMode(false);
                              },
                            ),
                            ChoiceChip(
                              key: const Key('mask-inline-brush-erase'),
                              label: const Text('Erase', style: TextStyle(fontSize: 11)),
                              selected: ref.watch(nodeEditorProvider.select((s) => s.eraserMode)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              showCheckmark: false,
                              onSelected: (val) {
                                if (val) ref.read(nodeEditorProvider.notifier).setEraserMode(true);
                              },
                            ),
                          ] else ...[
                            ActionChip(
                              key: const Key('mask-subtract'),
                              avatar: const Icon(Icons.remove_circle_outline, size: 14),
                              label: const Text('Subtract', style: TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                notifier.updateLayerAt(i, layers[i].copyWith(inverted: true));
                              },
                            ),
                          ],
                          ActionChip(
                            key: const Key('mask-inline-duplicate'),
                            avatar: const Icon(Icons.copy, size: 14),
                            label: const Text('Duplicate', style: TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            onPressed: () => notifier.addLayer(layers[i].copyWith()),
                          ),
                          if (layers[i].maskKind == MaskKind.brush && layers[i].brushPointCount > 0)
                            TextButton.icon(
                              key: const Key('mask-inline-brush-clear'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.clear, size: 14),
                              label: const Text('Clear', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                notifier.updateLayerAt(i, layers[i].withClearedStrokes());
                              },
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'EV ${layers[i].exposure >= 0 ? '+' : ''}${layers[i].exposure.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      if (layers[i].maskKind == MaskKind.brush) ...[
                        _MaskSlider(
                          label: 'Brush Size',
                          sliderKey: const Key('mask-inline-brush-size-slider'),
                          value: layers[i].brushRadius,
                          min: 0.01,
                          max: 0.5,
                          onChanged: (val) => notifier.updateLayerAt(i, layers[i].withBrushRadius(val)),
                        ),
                        _MaskSlider(
                          label: 'Feather',
                          sliderKey: const Key('mask-inline-brush-feather-slider'),
                          value: layers[i].brushFeather,
                          min: 0.0,
                          max: 1.0,
                          onChanged: (val) => notifier.updateLayerAt(i, layers[i].withBrushFeather(val)),
                        ),
                      ],
                      if (layers[i].maskKind == MaskKind.sky) ...[
                        _MaskSlider(
                          label: 'Horizon',
                          sliderKey: const Key('mask-inline-sky-horizon-slider'),
                          value: layers[i].skyHorizon,
                          min: 0.05,
                          max: 0.95,
                          onChanged: (val) => notifier.updateLayerAt(i, layers[i].withSkyHorizon(val)),
                        ),
                        _MaskSlider(
                          label: 'Feather',
                          sliderKey: const Key('mask-inline-sky-feather-slider'),
                          value: layers[i].skyFeather,
                          min: 0.01,
                          max: 0.5,
                          onChanged: (val) => notifier.updateLayerAt(i, layers[i].withSkyFeather(val)),
                        ),
                        _MaskSlider(
                          label: 'Blue Weight',
                          sliderKey: const Key('mask-inline-sky-blue-weight-slider'),
                          value: layers[i].skyBlueWeight,
                          min: 0.0,
                          max: 1.0,
                          onChanged: (val) => notifier.updateLayerAt(i, layers[i].withSkyBlueWeight(val)),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'LIGHT CONTROLS',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      _MaskSlider(
                        label: 'Exposure',
                        sliderKey: const Key('mask-inline-exposure-slider'),
                        value: layers[i].exposure,
                        min: -2.0,
                        max: 2.0,
                        onChanged: (val) => notifier.updateLayerAt(i, layers[i].copyWith(exposure: val)),
                      ),
                      _MaskSlider(
                        label: 'Contrast',
                        sliderKey: const Key('mask-inline-contrast-slider'),
                        value: layers[i].contrast,
                        min: -1.0,
                        max: 1.0,
                        onChanged: (val) => notifier.updateLayerAt(i, layers[i].copyWith(contrast: val)),
                      ),
                      _MaskSlider(
                        label: 'Highlights',
                        sliderKey: const Key('mask-inline-highlights-slider'),
                        value: layers[i].highlights,
                        min: -1.0,
                        max: 1.0,
                        onChanged: (val) => notifier.updateLayerAt(i, layers[i].copyWith(highlights: val)),
                      ),
                      _MaskSlider(
                        label: 'Shadows',
                        sliderKey: const Key('mask-inline-shadows-slider'),
                        value: layers[i].shadows,
                        min: -1.0,
                        max: 1.0,
                        onChanged: (val) => notifier.updateLayerAt(i, layers[i].copyWith(shadows: val)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'COLOR CONTROLS',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      _MaskSlider(
                        label: 'Temp',
                        sliderKey: const Key('mask-inline-temp-slider'),
                        value: layers[i].temperature,
                        min: -1.0,
                        max: 1.0,
                        onChanged: (val) => notifier.updateLayerAt(i, layers[i].copyWith(temperature: val)),
                      ),
                      _MaskSlider(
                        label: 'Tint',
                        sliderKey: const Key('mask-inline-tint-slider'),
                        value: layers[i].tint,
                        min: -1.0,
                        max: 1.0,
                        onChanged: (val) => notifier.updateLayerAt(i, layers[i].copyWith(tint: val)),
                      ),
                      _MaskSlider(
                        label: 'Saturation',
                        sliderKey: const Key('mask-inline-saturation-slider'),
                        value: layers[i].saturation,
                        min: -1.0,
                        max: 1.0,
                        onChanged: (val) => notifier.updateLayerAt(i, layers[i].copyWith(saturation: val)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
    MaskKind.bitmap => Icons.auto_awesome,
  };

  void _toggleStylusOnly(WidgetRef ref, bool value) {
    ref.read(stylusOnlyModeProvider.notifier).set(value);
  }
}

class _MaskSlider extends StatelessWidget {
  const _MaskSlider({
    required this.label,
    required this.sliderKey,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final Key sliderKey;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                key: sliderKey,
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}