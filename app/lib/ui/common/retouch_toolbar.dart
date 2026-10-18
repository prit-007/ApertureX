import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/retouch_patch.dart';
import '../../viewport/canvas_transform.dart';
import 'retouch_controls.dart';

/// A floating, compact on-canvas toolbar for retouching (Lightroom Mobile parity).
///
/// Provides instant access to:
/// - Heal / Clone mode switching
/// - Quick "+ Spot" at the current viewport center
/// - Selected spot indicator and one-tap Delete
/// - Pan/zoom guidance
class RetouchToolbar extends ConsumerWidget {
  const RetouchToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final patches = recipe.retouchPatches;
    final selectedIdx = ref.watch(selectedRetouchPatchIndexProvider);
    final brush = ref.watch(retouchBrushProvider);
    final brushNotifier = ref.read(retouchBrushProvider.notifier);
    final notifier = ref.read(recipeControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    final selectedPatch = (selectedIdx != null &&
            selectedIdx >= 0 &&
            selectedIdx < patches.length)
        ? patches[selectedIdx]
        : null;

    final currentMode = selectedPatch?.mode ?? brush.mode;

    void addSpotAtCenter() {
      HapticFeedback.selectionClick();
      final transform = ref.read(canvasTransformProvider);
      final centerNorm = transform?.viewportCenterNormalized();
      final double defaultX = centerNorm?.dx ?? 0.5;
      final double defaultY = centerNorm?.dy ?? 0.5;

      final double tx = patches.isEmpty
          ? defaultX
          : ((defaultX + (patches.length * 0.04 - 0.02)) % 0.8 + 0.1);
      final double ty = patches.isEmpty
          ? defaultY
          : ((defaultY + (patches.length * 0.04 - 0.02)) % 0.8 + 0.1);
      final double sx = (tx > 0.5 ? tx - 0.10 : tx + 0.10).clamp(0.05, 0.95);
      final double sy = (ty > 0.5 ? ty - 0.10 : ty + 0.10).clamp(0.05, 0.95);

      final newPatch = RetouchPatch(
        targetX: tx,
        targetY: ty,
        sourceX: sx,
        sourceY: sy,
        radius: brush.radius,
        feather: brush.feather,
        opacity: brush.opacity,
        mode: currentMode,
      );

      final idx = patches.length;
      notifier.addRetouchPatch(newPatch);
      ref.read(selectedRetouchPatchIndexProvider.notifier).select(idx);
    }

    return Material(
      key: const Key('retouch-toolbar'),
      elevation: 4,
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
      borderRadius: Radii.pillAll,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: Radii.pillAll,
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Mode toggle: Heal
            ChoiceChip(
              key: const Key('retouch-toolbar-heal'),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_fix_high,
                    size: 14,
                    color: currentMode == RetouchMode.heal
                        ? const Color(0xFF00E5FF)
                        : null,
                  ),
                  const SizedBox(width: 4),
                  const Text('Heal', style: TextStyle(fontSize: 11)),
                ],
              ),
              selected: currentMode == RetouchMode.heal,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              showCheckmark: false,
              onSelected: (val) {
                if (val) {
                  HapticFeedback.selectionClick();
                  brushNotifier.setMode(RetouchMode.heal);
                  if (selectedPatch != null && selectedIdx != null) {
                    notifier.updateRetouchPatchAt(
                      selectedIdx,
                      selectedPatch.copyWith(mode: RetouchMode.heal),
                    );
                  }
                }
              },
            ),
            const SizedBox(width: 4),

            // Mode toggle: Clone
            ChoiceChip(
              key: const Key('retouch-toolbar-clone'),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.copy,
                    size: 14,
                    color: currentMode == RetouchMode.clone
                        ? const Color(0xFFFFB300)
                        : null,
                  ),
                  const SizedBox(width: 4),
                  const Text('Clone', style: TextStyle(fontSize: 11)),
                ],
              ),
              selected: currentMode == RetouchMode.clone,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              showCheckmark: false,
              onSelected: (val) {
                if (val) {
                  HapticFeedback.selectionClick();
                  brushNotifier.setMode(RetouchMode.clone);
                  if (selectedPatch != null && selectedIdx != null) {
                    notifier.updateRetouchPatchAt(
                      selectedIdx,
                      selectedPatch.copyWith(mode: RetouchMode.clone),
                    );
                  }
                }
              },
            ),
            const SizedBox(width: 6),

            // Add spot at screen center
            InkWell(
              key: const Key('retouch-toolbar-add'),
              borderRadius: BorderRadius.circular(16),
              onTap: addSpotAtCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline, size: 15, color: scheme.primary),
                    const SizedBox(width: 3),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (selectedPatch != null && selectedIdx != null) ...[
              const SizedBox(width: 4),
              Container(width: 1, height: 16, color: scheme.outlineVariant),
              const SizedBox(width: 4),

              // Delete selected spot
              IconButton(
                key: const Key('retouch-toolbar-delete'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.delete_outline, size: 16),
                color: const Color(0xFFFF5252),
                tooltip: 'Delete spot',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  notifier.removeRetouchPatchAt(selectedIdx);
                  ref.read(selectedRetouchPatchIndexProvider.notifier).select(null);
                },
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }
}
