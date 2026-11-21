import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/active_image.dart';
import '../../edit/adjustment_layer.dart';
import '../../edit/node_editor.dart';
import '../../edit/recipe_controller.dart';
import '../../l10n/app_strings.dart';
import '../common/mask_controls.dart'
    show aiMaskInferringProvider, aiMaskStatusMessageProvider, maskRefinerProvider;
import 'mask_color_grading_section.dart';

const List<String> _zoneRomans = [
  '0', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'
];

String zoneRoman(int z) => _zoneRomans[z.clamp(0, 10)];

class MaskInlineCard extends ConsumerWidget {
  const MaskInlineCard({
    super.key,
    required this.i,
    required this.layer,
    required this.notifier,
    this.showGradeControls = true,
  });

  final int i;
  final AdjustmentLayer layer;
  final RecipeController notifier;
  final bool showGradeControls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInferring = ref.watch(aiMaskInferringProvider);
    return Padding(
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
                    label: Text(AppStrings.of(context).maskInvert, style: const TextStyle(fontSize: 11)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    selected: layer.inverted,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onSelected: (val) {
                      notifier.updateLayerAt(i, layer.copyWith(inverted: val));
                    },
                  ),
                  if (layer.maskKind == MaskKind.brush) ...[
                    ChoiceChip(
                      key: const Key('mask-inline-brush-paint'),
                      label: Text(AppStrings.of(context).maskPaint, style: const TextStyle(fontSize: 11)),
                      selected: !ref.watch(nodeEditorProvider.select((s) => s.eraserMode)) &&
                          !ref.watch(nodeEditorProvider.select((s) => s.refineBrushMode)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      showCheckmark: false,
                      onSelected: (val) {
                        if (val) {
                          ref.read(nodeEditorProvider.notifier).setEraserMode(false);
                          ref.read(nodeEditorProvider.notifier).setRefineBrushMode(false);
                        }
                      },
                    ),
                    ChoiceChip(
                      key: const Key('mask-inline-brush-erase'),
                      label: Text(AppStrings.of(context).maskErase, style: const TextStyle(fontSize: 11)),
                      selected: ref.watch(nodeEditorProvider.select((s) => s.eraserMode)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      showCheckmark: false,
                      onSelected: (val) {
                        if (val) ref.read(nodeEditorProvider.notifier).setEraserMode(true);
                      },
                    ),
                    FilterChip(
                      key: const Key('mask-inline-auto-mask'),
                      label: Text(AppStrings.of(context).maskAutoMask, style: const TextStyle(fontSize: 11)),
                      selected: layer.maskKind == MaskKind.autoBrush,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        notifier.updateLayerAt(
                          i,
                          layer.copyWith(maskKind: val ? MaskKind.autoBrush : MaskKind.brush),
                        );
                      },
                    ),
                  ] else ...[
                    ActionChip(
                      key: const Key('mask-subtract'),
                      avatar: const Icon(Icons.remove_circle_outline, size: 14),
                      label: Text(AppStrings.of(context).maskSubtract, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        notifier.updateLayerAt(i, layer.copyWith(inverted: true));
                      },
                    ),
                  ],
                  ChoiceChip(
                    key: const Key('mask-inline-refine-brush'),
                    label: Text(AppStrings.of(context).maskRefineBrush, style: const TextStyle(fontSize: 11)),
                    selected: ref.watch(nodeEditorProvider.select((s) => s.refineBrushMode)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    showCheckmark: false,
                    onSelected: (val) {
                      if (val) {
                        ref.read(nodeEditorProvider.notifier).setRefineBrushMode(true);
                        ref.read(nodeEditorProvider.notifier).enable();
                      } else {
                        ref.read(nodeEditorProvider.notifier).setRefineBrushMode(false);
                      }
                    },
                  ),
                  ActionChip(
                    key: const Key('mask-inline-refine-edge'),
                    avatar: const Icon(Icons.auto_fix_high, size: 14),
                    label: Text(AppStrings.of(context).maskRefineEdge, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: isInferring
                        ? null
                        : () async {
                            final bytes = ref.read(activeImageBytesProvider);
                            if (bytes == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(AppStrings.of(context).maskNoPhotoRefine)),
                              );
                              return;
                            }
                            ref.read(aiMaskInferringProvider.notifier).setInferring(true);
                            ref.read(aiMaskStatusMessageProvider.notifier).setMessage(
                                'Refining mask edges with guided filter… Please wait a moment');
                            try {
                              final refiner = ref.read(maskRefinerProvider);
                              final refined = await refiner(layer, bytes);
                              if (refined != null) {
                                notifier.updateLayerAt(i, refined);
                                HapticFeedback.mediumImpact();
                              }
                            } finally {
                              ref.read(aiMaskInferringProvider.notifier).setInferring(false);
                              ref.read(aiMaskStatusMessageProvider.notifier).setMessage(null);
                            }
                          },
                  ),
                  ActionChip(
                    key: const Key('mask-inline-duplicate'),
                    avatar: const Icon(Icons.copy, size: 14),
                    label: Text(AppStrings.of(context).maskDuplicate, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: () => notifier.addLayer(layer.copyWith()),
                  ),
                  if (layer.maskKind == MaskKind.depthRange || layer.aiIntent == 'depth')
                    ActionChip(
                      key: const Key('mask-blur-refine-brush'),
                      avatar: const Icon(Icons.brush, size: 14),
                      label: Text(AppStrings.of(context).blurRefineBrush, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        ref.read(nodeEditorProvider.notifier).setRefineBrushMode(true);
                        ref.read(nodeEditorProvider.notifier).enable();
                      },
                    ),
                  if (layer.maskKind == MaskKind.luminance)
                    ActionChip(
                      key: const Key('mask-luma-eyedropper'),
                      avatar: const Icon(Icons.colorize, size: 14),
                      label: Text(AppStrings.of(context).maskSampleLuma, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        ref.read(nodeEditorProvider.notifier).enable();
                        ref.read(nodeEditorProvider.notifier).select(i);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppStrings.of(context).maskSampleLuminance),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  if (layer.maskKind == MaskKind.brush && layer.brushPointCount > 0)
                    TextButton.icon(
                      key: const Key('mask-inline-brush-clear'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.clear, size: 14),
                      label: Text(AppStrings.of(context).maskClear, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        notifier.updateLayerAt(i, layer.withClearedStrokes());
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'EV ${layer.exposure >= 0 ? '+' : ''}${layer.exposure.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (layer.maskKind == MaskKind.brush || layer.maskKind == MaskKind.autoBrush) ...[
                MaskSlider(
                  label: 'Brush Size',
                  sliderKey: const Key('mask-inline-brush-size-slider'),
                  value: layer.brushRadius,
                  min: 0.01,
                  max: 0.5,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.withBrushRadius(val)),
                ),
                MaskSlider(
                  label: 'Feather',
                  sliderKey: const Key('mask-inline-brush-feather-slider'),
                  value: layer.brushFeather,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.withBrushFeather(val)),
                ),
                MaskSlider(
                  label: 'Flow',
                  sliderKey: const Key('mask-inline-brush-flow-slider'),
                  value: layer.amount.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  displayValue: '${(layer.amount.clamp(0.0, 1.0) * 100).round()}%',
                  onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(amount: val)),
                ),
              ],
              if (layer.maskKind == MaskKind.sky) ...[
                MaskSlider(
                  label: 'Horizon',
                  sliderKey: const Key('mask-inline-sky-horizon-slider'),
                  value: layer.skyHorizon,
                  min: 0.05,
                  max: 0.95,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.withSkyHorizon(val)),
                ),
                MaskSlider(
                  label: 'Feather',
                  sliderKey: const Key('mask-inline-sky-feather-slider'),
                  value: layer.skyFeather,
                  min: 0.01,
                  max: 0.5,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.withSkyFeather(val)),
                ),
                MaskSlider(
                  label: 'Blue Weight',
                  sliderKey: const Key('mask-inline-sky-blue-weight-slider'),
                  value: layer.skyBlueWeight,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.withSkyBlueWeight(val)),
                ),
              ],
              if (layer.maskKind == MaskKind.luminance) ...[
                const SizedBox(height: 6),
                Text(
                  'ANSEL ADAMS ZONE SYSTEM',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var z = 0; z <= 10; z++) ...[
                        ChoiceChip(
                          key: Key('mask-zone-chip-$z'),
                          label: Text(
                            zoneRoman(z),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          selected: layer.lumaZone == z,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          showCheckmark: false,
                          onSelected: (selected) {
                            if (selected) {
                              notifier.updateLayerAt(i, layer.withZone(z));
                            }
                          },
                        ),
                        if (z < 10) const SizedBox(width: 4),
                      ],
                    ],
                  ),
                ),
                MaskSlider(
                  label: 'Min Luma',
                  sliderKey: const Key('mask-inline-luma-min-slider'),
                  value: layer.lumaMin,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.withLumaBand(min: val)),
                ),
                MaskSlider(
                  label: 'Max Luma',
                  sliderKey: const Key('mask-inline-luma-max-slider'),
                  value: layer.lumaMax,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.withLumaBand(max: val)),
                ),
                MaskSlider(
                  label: 'Feather',
                  sliderKey: const Key('mask-inline-luma-feather-slider'),
                  value: layer.lumaFeatherLo,
                  min: 0.01,
                  max: 0.5,
                  onChanged: (val) => notifier.updateLayerAt(
                    i,
                    layer.withLumaBand(featherLo: val, featherHi: val),
                  ),
                ),
              ],
              if (layer.maskKind == MaskKind.colorRange) ...[
                const SizedBox(height: 6),
                Text(
                  'COLOR RANGE MASK',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                MaskSlider(
                  label: 'Target Hue',
                  sliderKey: const Key('mask-inline-color-hue-slider'),
                  value: layer.colorRangeTargetHue,
                  min: 0.0,
                  max: 360.0,
                  displayValue: '${layer.colorRangeTargetHue.round()}°',
                  onChanged: (val) => notifier.updateLayerAt(
                    i,
                    layer.withColorRange(targetHue: val),
                  ),
                ),
                MaskSlider(
                  label: 'Hue Width',
                  sliderKey: const Key('mask-inline-color-width-slider'),
                  value: layer.colorRangeHueWidth,
                  min: 0.0,
                  max: 180.0,
                  displayValue: '${layer.colorRangeHueWidth.round()}°',
                  onChanged: (val) => notifier.updateLayerAt(
                    i,
                    layer.withColorRange(hueWidth: val),
                  ),
                ),
                MaskSlider(
                  label: 'Sat Min',
                  sliderKey: const Key('mask-inline-color-sat-min-slider'),
                  value: layer.colorRangeSatMin,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(
                    i,
                    layer.withColorRange(satMin: val),
                  ),
                ),
                MaskSlider(
                  label: 'Sat Max',
                  sliderKey: const Key('mask-inline-color-sat-max-slider'),
                  value: layer.colorRangeSatMax,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(
                    i,
                    layer.withColorRange(satMax: val),
                  ),
                ),
                MaskSlider(
                  label: 'Lum Min',
                  sliderKey: const Key('mask-inline-color-lum-min-slider'),
                  value: layer.colorRangeLumMin,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(
                    i,
                    layer.withColorRange(lumMin: val),
                  ),
                ),
                MaskSlider(
                  label: 'Lum Max',
                  sliderKey: const Key('mask-inline-color-lum-max-slider'),
                  value: layer.colorRangeLumMax,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(
                    i,
                    layer.withColorRange(lumMax: val),
                  ),
                ),
                MaskSlider(
                  label: 'Softness',
                  sliderKey: const Key('mask-inline-color-softness-slider'),
                  value: layer.colorRangeSoftness,
                  min: 0.0,
                  max: 0.5,
                  onChanged: (val) => notifier.updateLayerAt(
                    i,
                    layer.withColorRange(softness: val),
                  ),
                ),
                ActionChip(
                  key: const Key('mask-inline-color-eyedropper'),
                  avatar: const Icon(Icons.color_lens, size: 14),
                  label: Text(AppStrings.of(context).maskSampleColorBtn, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    ref.read(nodeEditorProvider.notifier).enable();
                    ref.read(nodeEditorProvider.notifier).select(i);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppStrings.of(context).maskSampleColor),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 6),
              MaskSlider(
                label: 'Amount',
                sliderKey: const Key('mask-inline-amount-slider'),
                value: layer.amount,
                min: 0.0,
                max: 2.0,
                displayValue: '${(layer.amount * 100).round()}%',
                onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(amount: val)),
              ),
              const SizedBox(height: 6),
              if (showGradeControls) ...[
                Text(
                  'LIGHT CONTROLS',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                MaskSlider(
                  label: 'Exposure',
                  sliderKey: const Key('mask-inline-exposure-slider'),
                  value: layer.exposure,
                  min: -2.0,
                  max: 2.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(exposure: val)),
                ),
                MaskSlider(
                  label: 'Contrast',
                  sliderKey: const Key('mask-inline-contrast-slider'),
                  value: layer.contrast,
                  min: -1.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(contrast: val)),
                ),
                MaskSlider(
                  label: 'Highlights',
                  sliderKey: const Key('mask-inline-highlights-slider'),
                  value: layer.highlights,
                  min: -1.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(highlights: val)),
                ),
                MaskSlider(
                  label: 'Shadows',
                  sliderKey: const Key('mask-inline-shadows-slider'),
                  value: layer.shadows,
                  min: -1.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(shadows: val)),
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
                MaskSlider(
                  label: 'Temp',
                  sliderKey: const Key('mask-inline-temp-slider'),
                  value: layer.temperature,
                  min: -1.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(temperature: val)),
                ),
                MaskSlider(
                  label: 'Tint',
                  sliderKey: const Key('mask-inline-tint-slider'),
                  value: layer.tint,
                  min: -1.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(tint: val)),
                ),
                MaskSlider(
                  label: 'Saturation',
                  sliderKey: const Key('mask-inline-saturation-slider'),
                  value: layer.saturation,
                  min: -1.0,
                  max: 1.0,
                  onChanged: (val) => notifier.updateLayerAt(i, layer.copyWith(saturation: val)),
                ),
                MaskColorGradingSection(
                  segmentedKey: const Key('mask-grade-zone-segmented'),
                  hueKey: const Key('mask-inline-grade-hue-slider'),
                  satKey: const Key('mask-inline-grade-sat-slider'),
                  lumKey: const Key('mask-inline-grade-lum-slider'),
                  blendingKey: const Key('mask-inline-grade-blending-slider'),
                  balanceKey: const Key('mask-inline-grade-balance-slider'),
                  shadowHue: layer.gradeShadowHue,
                  shadowSat: layer.gradeShadowSat,
                  shadowLum: layer.gradeShadowLum,
                  midHue: layer.gradeMidHue,
                  midSat: layer.gradeMidSat,
                  midLum: layer.gradeMidLum,
                  highlightHue: layer.gradeHighlightHue,
                  highlightSat: layer.gradeHighlightSat,
                  highlightLum: layer.gradeHighlightLum,
                  blending: layer.gradeBlending,
                  balance: layer.gradeBalance,
                  onZoneChanged: (zone, {hue, sat, lum}) {
                    final updated = switch (zone) {
                      GradeWheelZone.shadows => layer.copyWith(
                        gradeShadowHue: hue ?? layer.gradeShadowHue,
                        gradeShadowSat: sat ?? layer.gradeShadowSat,
                        gradeShadowLum: lum ?? layer.gradeShadowLum,
                      ),
                      GradeWheelZone.midtones => layer.copyWith(
                        gradeMidHue: hue ?? layer.gradeMidHue,
                        gradeMidSat: sat ?? layer.gradeMidSat,
                        gradeMidLum: lum ?? layer.gradeMidLum,
                      ),
                      GradeWheelZone.highlights => layer.copyWith(
                        gradeHighlightHue: hue ?? layer.gradeHighlightHue,
                        gradeHighlightSat: sat ?? layer.gradeHighlightSat,
                        gradeHighlightLum: lum ?? layer.gradeHighlightLum,
                      ),
                    };
                    notifier.updateLayerAt(i, updated);
                  },
                  onGlobalChanged: ({blending, balance}) {
                    notifier.updateLayerAt(
                      i,
                      layer.copyWith(
                        gradeBlending: blending ?? layer.gradeBlending,
                        gradeBalance: balance ?? layer.gradeBalance,
                      ),
                    );
                  },
                ),
              ] else ...[
                Text(
                  'Graded on the group card above',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
