import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/adjustment_layer.dart';
import '../../edit/recipe_controller.dart';
import '../../l10n/app_strings.dart';
import 'mask_color_grading_section.dart';
import 'mask_inline_card.dart';
import 'mask_layer_tile.dart';
import 'mask_thumbnails.dart';

typedef AddMaskCallback = void Function(
  BuildContext context,
  WidgetRef ref,
  MaskKind kind, {
  String? groupId,
  MaskJoinOp joinOp,
});

class MaskGroupCard extends ConsumerWidget {
  const MaskGroupCard({
    super.key,
    required this.group,
    required this.layers,
    required this.selectedIndex,
    required this.notifier,
    required this.onAddMask,
  });

  final MaskGroup group;
  final List<AdjustmentLayer> layers;
  final int? selectedIndex;
  final RecipeController notifier;
  final AddMaskCallback onAddMask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final memberIndices = [for (var i = 0; i < layers.length; i++) if (layers[i].groupId == group.id) i];

    return Card(
      key: Key('mask-group-${group.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Group Header
            Row(
              children: [
                GroupThumbnail(group: group),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    group.name,
                    key: Key('group-title-${group.id}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                if (group.inverted) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Inverted',
                      style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  key: Key('group-visibility-${group.id}'),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  tooltip: group.amount > 0 ? 'Hide group' : 'Show group',
                  icon: Icon(
                    group.amount > 0 ? Icons.visibility : Icons.visibility_off,
                    color: group.amount > 0 ? null : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    notifier.updateMaskGroup(
                      group.copyWith(amount: group.amount > 0 ? 0.0 : 1.0),
                    );
                  },
                ),
                IconButton(
                  key: Key('group-invert-${group.id}'),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  tooltip: 'Invert Group Coverage',
                  icon: Icon(
                    group.inverted ? Icons.swap_horiz : Icons.swap_horizontal_circle_outlined,
                    color: group.inverted ? Colors.orange : null,
                    size: 20,
                  ),
                  onPressed: () => notifier.updateMaskGroup(group.copyWith(inverted: !group.inverted)),
                ),
                IconButton(
                  key: Key('group-delete-${group.id}'),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  tooltip: 'Delete Group and Members',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => notifier.removeMaskGroup(group.id),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Group-level Amount Slider (0..200%)
            MaskSlider(
              label: 'Group Amt',
              sliderKey: Key('group-amount-${group.id}'),
              value: group.amount,
              min: 0.0,
              max: 2.0,
              displayValue: '${(group.amount * 100).round()}%',
              onChanged: (val) => notifier.updateMaskGroup(group.copyWith(amount: val)),
            ),

            // Group-level Light & Color Sliders
            MaskSlider(
              label: 'Exposure',
              sliderKey: Key('group-exposure-${group.id}'),
              value: group.exposure,
              min: -2.0,
              max: 2.0,
              onChanged: (val) => notifier.updateMaskGroup(group.copyWith(exposure: val)),
            ),
            MaskSlider(
              label: 'Contrast',
              sliderKey: Key('group-contrast-${group.id}'),
              value: group.contrast,
              min: -1.0,
              max: 1.0,
              onChanged: (val) => notifier.updateMaskGroup(group.copyWith(contrast: val)),
            ),
            MaskSlider(
              label: 'Highlights',
              sliderKey: Key('group-highlights-${group.id}'),
              value: group.highlights,
              min: -1.0,
              max: 1.0,
              onChanged: (val) => notifier.updateMaskGroup(group.copyWith(highlights: val)),
            ),
            MaskSlider(
              label: 'Shadows',
              sliderKey: Key('group-shadows-${group.id}'),
              value: group.shadows,
              min: -1.0,
              max: 1.0,
              onChanged: (val) => notifier.updateMaskGroup(group.copyWith(shadows: val)),
            ),
            MaskSlider(
              label: 'Temp',
              sliderKey: Key('group-temp-${group.id}'),
              value: group.temperature,
              min: -1.0,
              max: 1.0,
              onChanged: (val) => notifier.updateMaskGroup(group.copyWith(temperature: val)),
            ),
            MaskSlider(
              label: 'Tint',
              sliderKey: Key('group-tint-${group.id}'),
              value: group.tint,
              min: -1.0,
              max: 1.0,
              onChanged: (val) => notifier.updateMaskGroup(group.copyWith(tint: val)),
            ),
            MaskSlider(
              label: 'Saturation',
              sliderKey: Key('group-saturation-${group.id}'),
              value: group.saturation,
              min: -1.0,
              max: 1.0,
              onChanged: (val) => notifier.updateMaskGroup(group.copyWith(saturation: val)),
            ),

            MaskColorGradingSection(
              segmentedKey: Key('group-grade-zone-segmented-${group.id}'),
              hueKey: Key('group-grade-hue-${group.id}'),
              satKey: Key('group-grade-sat-${group.id}'),
              lumKey: Key('group-grade-lum-${group.id}'),
              blendingKey: Key('group-grade-blending-${group.id}'),
              balanceKey: Key('group-grade-balance-${group.id}'),
              shadowHue: group.gradeShadowHue,
              shadowSat: group.gradeShadowSat,
              shadowLum: group.gradeShadowLum,
              midHue: group.gradeMidHue,
              midSat: group.gradeMidSat,
              midLum: group.gradeMidLum,
              highlightHue: group.gradeHighlightHue,
              highlightSat: group.gradeHighlightSat,
              highlightLum: group.gradeHighlightLum,
              blending: group.gradeBlending,
              balance: group.gradeBalance,
              onZoneChanged: (zone, {hue, sat, lum}) {
                final updated = switch (zone) {
                  GradeWheelZone.shadows => group.copyWith(
                    gradeShadowHue: hue ?? group.gradeShadowHue,
                    gradeShadowSat: sat ?? group.gradeShadowSat,
                    gradeShadowLum: lum ?? group.gradeShadowLum,
                  ),
                  GradeWheelZone.midtones => group.copyWith(
                    gradeMidHue: hue ?? group.gradeMidHue,
                    gradeMidSat: sat ?? group.gradeMidSat,
                    gradeMidLum: lum ?? group.gradeMidLum,
                  ),
                  GradeWheelZone.highlights => group.copyWith(
                    gradeHighlightHue: hue ?? group.gradeHighlightHue,
                    gradeHighlightSat: sat ?? group.gradeHighlightSat,
                    gradeHighlightLum: lum ?? group.gradeHighlightLum,
                  ),
                };
                notifier.updateMaskGroup(updated);
              },
              onGlobalChanged: ({blending, balance}) {
                notifier.updateMaskGroup(
                  group.copyWith(
                    gradeBlending: blending ?? group.gradeBlending,
                    gradeBalance: balance ?? group.gradeBalance,
                  ),
                );
              },
            ),

            const Divider(height: 16),

            // Group Action Toolbar (Add / Subtract / Intersect)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PopupMenuButton<MaskKind>(
                  key: Key('group-add-${group.id}'),
                  tooltip: 'Add mask to group',
                  itemBuilder: (context) => [
                    PopupMenuItem(value: MaskKind.brush, child: Text(AppStrings.of(context).maskBrush)),
                    PopupMenuItem(value: MaskKind.linear, child: Text(AppStrings.of(context).maskLinearGradient)),
                    PopupMenuItem(value: MaskKind.radial, child: Text(AppStrings.of(context).maskRadialGradient)),
                    PopupMenuItem(value: MaskKind.subject, child: Text(AppStrings.of(context).maskSubject)),
                    PopupMenuItem(value: MaskKind.sky, child: Text(AppStrings.of(context).maskSky)),
                    PopupMenuItem(value: MaskKind.luminance, child: Text(AppStrings.of(context).maskLuminance)),
                    PopupMenuItem(value: MaskKind.colorRange, child: Text(AppStrings.of(context).maskColorRange)),
                    PopupMenuItem(value: MaskKind.autoBrush, child: Text(AppStrings.of(context).maskAutoBrush)),
                    PopupMenuItem(value: MaskKind.depthRange, child: Text(AppStrings.of(context).maskDepthRange)),
                    PopupMenuItem(value: MaskKind.background, child: Text(AppStrings.of(context).maskBackground)),
                    PopupMenuItem(value: MaskKind.personFace, child: Text(AppStrings.of(context).maskPersonFace)),
                    PopupMenuItem(value: MaskKind.personSkin, child: Text(AppStrings.of(context).maskPersonSkin)),
                    PopupMenuItem(value: MaskKind.personHair, child: Text(AppStrings.of(context).maskPersonHair)),
                    PopupMenuItem(value: MaskKind.object, child: Text(AppStrings.of(context).maskObject)),
                  ],
                  onSelected: (kind) => onAddMask(context, ref, kind, groupId: group.id, joinOp: MaskJoinOp.add),
                  child: Chip(
                    avatar: const Icon(Icons.add, size: 14),
                    label: Text(AppStrings.of(context).maskAdd, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuButton<MaskKind>(
                  key: Key('group-subtract-${group.id}'),
                  tooltip: 'Subtract mask from group',
                  itemBuilder: (context) => [
                    PopupMenuItem(value: MaskKind.brush, child: Text(AppStrings.of(context).maskBrush)),
                    PopupMenuItem(value: MaskKind.linear, child: Text(AppStrings.of(context).maskLinearGradient)),
                    PopupMenuItem(value: MaskKind.radial, child: Text(AppStrings.of(context).maskRadialGradient)),
                    PopupMenuItem(value: MaskKind.subject, child: Text(AppStrings.of(context).maskSubject)),
                    PopupMenuItem(value: MaskKind.sky, child: Text(AppStrings.of(context).maskSky)),
                    PopupMenuItem(value: MaskKind.luminance, child: Text(AppStrings.of(context).maskLuminance)),
                    PopupMenuItem(value: MaskKind.colorRange, child: Text(AppStrings.of(context).maskColorRange)),
                    PopupMenuItem(value: MaskKind.autoBrush, child: Text(AppStrings.of(context).maskAutoBrush)),
                    PopupMenuItem(value: MaskKind.depthRange, child: Text(AppStrings.of(context).maskDepthRange)),
                    PopupMenuItem(value: MaskKind.background, child: Text(AppStrings.of(context).maskBackground)),
                    PopupMenuItem(value: MaskKind.personFace, child: Text(AppStrings.of(context).maskPersonFace)),
                    PopupMenuItem(value: MaskKind.personSkin, child: Text(AppStrings.of(context).maskPersonSkin)),
                    PopupMenuItem(value: MaskKind.personHair, child: Text(AppStrings.of(context).maskPersonHair)),
                    PopupMenuItem(value: MaskKind.object, child: Text(AppStrings.of(context).maskObject)),
                  ],
                  onSelected: (kind) => onAddMask(context, ref, kind, groupId: group.id, joinOp: MaskJoinOp.subtract),
                  child: Chip(
                    avatar: const Icon(Icons.remove, size: 14),
                    label: Text(AppStrings.of(context).maskSubtract, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuButton<MaskKind>(
                  key: Key('group-intersect-${group.id}'),
                  tooltip: 'Intersect mask with group',
                  itemBuilder: (context) => [
                    PopupMenuItem(value: MaskKind.brush, child: Text(AppStrings.of(context).maskBrush)),
                    PopupMenuItem(value: MaskKind.linear, child: Text(AppStrings.of(context).maskLinearGradient)),
                    PopupMenuItem(value: MaskKind.radial, child: Text(AppStrings.of(context).maskRadialGradient)),
                    PopupMenuItem(value: MaskKind.subject, child: Text(AppStrings.of(context).maskSubject)),
                    PopupMenuItem(value: MaskKind.sky, child: Text(AppStrings.of(context).maskSky)),
                    PopupMenuItem(value: MaskKind.luminance, child: Text(AppStrings.of(context).maskLuminance)),
                    PopupMenuItem(value: MaskKind.colorRange, child: Text(AppStrings.of(context).maskColorRange)),
                    PopupMenuItem(value: MaskKind.autoBrush, child: Text(AppStrings.of(context).maskAutoBrush)),
                    PopupMenuItem(value: MaskKind.depthRange, child: Text(AppStrings.of(context).maskDepthRange)),
                    PopupMenuItem(value: MaskKind.background, child: Text(AppStrings.of(context).maskBackground)),
                    PopupMenuItem(value: MaskKind.personFace, child: Text(AppStrings.of(context).maskPersonFace)),
                    PopupMenuItem(value: MaskKind.personSkin, child: Text(AppStrings.of(context).maskPersonSkin)),
                    PopupMenuItem(value: MaskKind.personHair, child: Text(AppStrings.of(context).maskPersonHair)),
                    PopupMenuItem(value: MaskKind.object, child: Text(AppStrings.of(context).maskObject)),
                  ],
                  onSelected: (kind) => onAddMask(context, ref, kind, groupId: group.id, joinOp: MaskJoinOp.intersect),
                  child: Chip(
                    avatar: const Icon(Icons.join_inner, size: 14),
                    label: Text(AppStrings.of(context).maskIntersect, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),

            if (memberIndices.isNotEmpty) const SizedBox(height: 8),

            // Members inside this group
            for (final i in memberIndices) ...[
              MaskLayerTile(
                i: i,
                layer: layers[i],
                isSelected: i == selectedIndex,
                notifier: notifier,
                showJoinOp: true,
                // Grouped members carry no grade of their own (ADR 0013) —
                // show the group's EV, which is what actually renders.
                evOverride: group.exposure,
              ),
              if (i == selectedIndex)
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: MaskInlineCard(
                    i: i,
                    layer: layers[i],
                    notifier: notifier,
                    showGradeControls: false,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
