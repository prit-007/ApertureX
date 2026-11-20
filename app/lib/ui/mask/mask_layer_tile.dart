import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/active_image.dart';
import '../../edit/adjustment_layer.dart';
import '../../edit/node_editor.dart';
import '../../edit/recipe_controller.dart';
import '../../l10n/app_strings.dart';
import '../common/mask_controls.dart' show maskRefinerProvider;
import 'mask_thumbnails.dart';

class MaskLayerTile extends StatelessWidget {
  const MaskLayerTile({
    super.key,
    required this.i,
    required this.layer,
    required this.isSelected,
    required this.notifier,
    required this.showJoinOp,
    this.evOverride,
  });

  final int i;
  final AdjustmentLayer layer;
  final bool isSelected;
  final RecipeController notifier;
  final bool showJoinOp;
  final double? evOverride;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final ev = evOverride ?? layer.exposure;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              selected: isSelected,
              leading: MaskThumbnail(
                kind: layer.maskKind,
                isSelected: isSelected,
                inverted: layer.inverted,
              ),
              title: Text(
                '${layer.maskKind.name.toUpperCase()} layer ${i + 1}  '
                'EV ${ev >= 0 ? '+' : ''}${ev.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (layer.inverted)
                    const Text(
                      'Inverted (Reversed)',
                      style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                    ),
                  if (layer.aiIntent != null || showJoinOp)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (layer.aiIntent != null) ...[
                            Tooltip(
                              message: 'AI masks run on-device; no image leaves your device',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.auto_awesome, size: 10),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        'AI ${layer.aiIntent} ✓',
                                        style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (showJoinOp) ...[
                            ChoiceChip(
                              key: Key('mask-join-add-$i'),
                              label: Text(AppStrings.of(context).maskPlus, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              selected: layer.joinOp == MaskJoinOp.add,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              showCheckmark: false,
                              onSelected: (val) {
                                if (val) notifier.updateLayerAt(i, layer.copyWith(joinOp: MaskJoinOp.add));
                              },
                            ),
                            ChoiceChip(
                              key: Key('mask-join-subtract-$i'),
                              label: Text(AppStrings.of(context).maskMinus, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              selected: layer.joinOp == MaskJoinOp.subtract,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              showCheckmark: false,
                              onSelected: (val) {
                                if (val) notifier.updateLayerAt(i, layer.copyWith(joinOp: MaskJoinOp.subtract));
                              },
                            ),
                            ChoiceChip(
                              key: Key('mask-join-intersect-$i'),
                              label: Text(AppStrings.of(context).maskIntersectSymbol, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              selected: layer.joinOp == MaskJoinOp.intersect,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              showCheckmark: false,
                              onSelected: (val) {
                                if (val) notifier.updateLayerAt(i, layer.copyWith(joinOp: MaskJoinOp.intersect));
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
              onTap: () {
                ref.read(nodeEditorProvider.notifier).select(i);
                ref.read(nodeEditorProvider.notifier).enable();
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('mask-visibility-$i'),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                    tooltip: layer.amount > 0 ? 'Hide mask' : 'Show mask',
                    icon: Icon(
                      layer.amount > 0 ? Icons.visibility : Icons.visibility_off,
                      size: 18,
                      color: layer.amount > 0 ? null : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      notifier.updateLayerAt(i, layer.copyWith(amount: layer.amount > 0 ? 0.0 : 1.0));
                    },
                  ),
                  IconButton(
                    key: Key('mask-refine-$i'),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                    tooltip: 'Refine mask edges',
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    onPressed: () async {
                      final bytes = ref.read(activeImageBytesProvider);
                      if (bytes == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppStrings.of(context).maskNoPhotoRefine)),
                        );
                        return;
                      }
                      final refiner = ref.read(maskRefinerProvider);
                      final refined = await refiner(layer, bytes);
                      if (refined != null) {
                        notifier.updateLayerAt(i, refined);
                        HapticFeedback.selectionClick();
                      }
                    },
                  ),
                  IconButton(
                    key: Key('mask-invert-$i'),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                    tooltip: 'Invert / Reverse mask',
                    icon: Icon(
                      layer.inverted ? Icons.swap_horiz : Icons.swap_horizontal_circle_outlined,
                      size: 18,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      notifier.updateLayerAt(i, layer.copyWith(inverted: !layer.inverted));
                    },
                  ),
                  IconButton(
                    key: Key('mask-duplicate-$i'),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                    tooltip: 'Duplicate mask',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      notifier.addLayer(layer.copyWith());
                    },
                  ),
                  IconButton(
                    key: Key('mask-delete-$i'),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                    tooltip: 'Remove layer',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
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
        );
      },
    );
  }
}
