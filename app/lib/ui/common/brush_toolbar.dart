import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/adjustment_layer.dart';
import '../../edit/node_editor.dart';
import '../../edit/recipe_controller.dart';

/// A floating, compact on-canvas toolbar for manual brush masking.
///
/// Provides instant access to:
/// - Paint / Erase mode switching
/// - Dynamic brush radius slider
/// - Feather softness adjustment
/// - Invert mask toggle
/// - Clear painted strokes
/// - Checkmark to complete brush editing session
class BrushToolbar extends ConsumerWidget {
  const BrushToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(nodeEditorProvider);
    if (!editor.enabled) return const SizedBox.shrink();

    final layers = ref.watch(
      recipeControllerProvider.select((s) => s.recipe.layers),
    );
    final idx = editor.selected;
    if (idx == null || idx < 0 || idx >= layers.length) {
      return const SizedBox.shrink();
    }

    final layer = layers[idx];
    if (layer.maskKind != MaskKind.brush) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final notifier = ref.read(recipeControllerProvider.notifier);

    return Material(
      key: const Key('brush-toolbar'),
      elevation: 4,
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
      borderRadius: Radii.pillAll,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: Radii.pillAll,
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mode toggle: Paint vs Erase
            ChoiceChip(
              key: const Key('brush-toolbar-paint'),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.brush,
                    size: 14,
                    color: !editor.eraserMode ? scheme.primary : null,
                  ),
                  const SizedBox(width: 4),
                  const Text('Paint', style: TextStyle(fontSize: 11)),
                ],
              ),
              selected: !editor.eraserMode,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              showCheckmark: false,
              onSelected: (val) {
                if (val) {
                  HapticFeedback.selectionClick();
                  ref.read(nodeEditorProvider.notifier).setEraserMode(false);
                }
              },
            ),
            const SizedBox(width: 4),
            ChoiceChip(
              key: const Key('brush-toolbar-erase'),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_fix_normal,
                    size: 14,
                    color: editor.eraserMode ? scheme.primary : null,
                  ),
                  const SizedBox(width: 4),
                  const Text('Erase', style: TextStyle(fontSize: 11)),
                ],
              ),
              selected: editor.eraserMode,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              showCheckmark: false,
              onSelected: (val) {
                if (val) {
                  HapticFeedback.selectionClick();
                  ref.read(nodeEditorProvider.notifier).setEraserMode(true);
                }
              },
            ),
            const SizedBox(width: 8),

            // Size icon and compact slider
            const Icon(Icons.circle, size: 10),
            SizedBox(
              width: 90,
              child: Slider(
                key: const Key('brush-toolbar-size-slider'),
                value: layer.brushRadius.clamp(0.01, 0.4),
                min: 0.01,
                max: 0.4,
                onChanged: (val) =>
                    notifier.updateLayerAt(idx, layer.withBrushRadius(val)),
              ),
            ),

            // Invert toggle
            IconButton(
              key: const Key('brush-toolbar-invert'),
              tooltip: 'Invert mask',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              isSelected: layer.inverted,
              icon: const Icon(Icons.invert_colors_off),
              selectedIcon: Icon(Icons.invert_colors, color: scheme.primary),
              onPressed: () {
                HapticFeedback.selectionClick();
                notifier.updateLayerAt(idx, layer.copyWith(inverted: !layer.inverted));
              },
            ),

            // Clear strokes button
            if (layer.brushPointCount > 0)
              IconButton(
                key: const Key('brush-toolbar-clear'),
                tooltip: 'Clear brush strokes',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  notifier.updateLayerAt(idx, layer.withClearedStrokes());
                },
              ),

            const SizedBox(width: 4),
            // Done button
            FilledButton.tonalIcon(
              key: const Key('brush-toolbar-done'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                ref.read(nodeEditorProvider.notifier).disable();
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Done', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
