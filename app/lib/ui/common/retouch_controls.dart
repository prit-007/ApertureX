import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/retouch_patch.dart';
import '../../viewport/canvas_transform.dart';

/// Currently selected retouch patch index for inspector/editing (null = none).
class SelectedRetouchPatchIndex extends Notifier<int?> {
  @override
  int? build() => null;
  void select(int? index) => state = index;
}

final selectedRetouchPatchIndexProvider =
    NotifierProvider<SelectedRetouchPatchIndex, int?>(
  SelectedRetouchPatchIndex.new,
);

/// Active brush settings for retouching.
class RetouchBrushSettings {
  const RetouchBrushSettings({
    this.mode = RetouchMode.heal,
    this.radius = 0.05,
    this.feather = 0.5,
    this.opacity = 1.0,
  });

  final RetouchMode mode;
  final double radius;
  final double feather;
  final double opacity;

  RetouchBrushSettings copyWith({
    RetouchMode? mode,
    double? radius,
    double? feather,
    double? opacity,
  }) => RetouchBrushSettings(
    mode: mode ?? this.mode,
    radius: radius ?? this.radius,
    feather: feather ?? this.feather,
    opacity: opacity ?? this.opacity,
  );
}

class RetouchBrushNotifier extends Notifier<RetouchBrushSettings> {
  @override
  RetouchBrushSettings build() => const RetouchBrushSettings();

  void setMode(RetouchMode mode) => state = state.copyWith(mode: mode);
  void setRadius(double radius) => state = state.copyWith(radius: radius);
  void setFeather(double feather) => state = state.copyWith(feather: feather);
  void setOpacity(double opacity) => state = state.copyWith(opacity: opacity);
}

final retouchBrushProvider =
    NotifierProvider<RetouchBrushNotifier, RetouchBrushSettings>(
  RetouchBrushNotifier.new,
);

/// Retouch & Blemish Removal Controls (Lightroom Parity).
class RetouchControls extends ConsumerWidget {
  const RetouchControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final notifier = ref.read(recipeControllerProvider.notifier);
    final patches = recipe.retouchPatches;
    final selectedIndex = ref.watch(selectedRetouchPatchIndexProvider);
    final brush = ref.watch(retouchBrushProvider);
    final brushNotifier = ref.read(retouchBrushProvider.notifier);

    // If a patch is selected, controls edit that patch; otherwise they edit defaults.
    final selectedPatch = (selectedIndex != null &&
            selectedIndex >= 0 &&
            selectedIndex < patches.length)
        ? patches[selectedIndex]
        : null;

    final currentMode = selectedPatch?.mode ?? brush.mode;
    final currentRadius = selectedPatch?.radius ?? brush.radius;
    final currentFeather = selectedPatch?.feather ?? brush.feather;
    final currentOpacity = selectedPatch?.opacity ?? brush.opacity;

    void addSpot(RetouchMode mode) {
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
        mode: mode,
      );

      final idx = patches.length;
      notifier.addRetouchPatch(newPatch);
      ref.read(selectedRetouchPatchIndexProvider.notifier).select(idx);
    }

    return Material(
      type: MaterialType.transparency,
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          // Studio Action Card: add heal/clone points directly
          Container(
            padding: const EdgeInsets.all(Insets.sm),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.65),
              borderRadius: const BorderRadius.all(Radius.circular(Radii.md)),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: Insets.xs,
                  runSpacing: Insets.xs,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.tonalIcon(
                      key: const Key('retouch-add-heal'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: scheme.primary.withValues(alpha: 0.15),
                        foregroundColor: scheme.primary,
                        side: BorderSide(color: scheme.primary.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 8),
                      ),
                      onPressed: () => addSpot(RetouchMode.heal),
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: const Text('Heal Spot +', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    FilledButton.tonalIcon(
                      key: const Key('retouch-add-clone'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: scheme.secondary.withValues(alpha: 0.15),
                        foregroundColor: scheme.secondary,
                        side: BorderSide(color: scheme.secondary.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 8),
                      ),
                      onPressed: () => addSpot(RetouchMode.clone),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Clone Spot +', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    if (selectedPatch != null && selectedIndex != null)
                      OutlinedButton.icon(
                        key: const Key('retouch-reset-source'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 8),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          final p = selectedPatch;
                          final sx = (p.targetX > 0.5 ? p.targetX - 0.08 : p.targetX + 0.08).clamp(0.05, 0.95);
                          final sy = (p.targetY > 0.5 ? p.targetY - 0.08 : p.targetY + 0.08).clamp(0.05, 0.95);
                          notifier.updateRetouchPatchAt(
                            selectedIndex,
                            p.copyWith(sourceX: sx, sourceY: sy),
                          );
                        },
                        icon: const Icon(Icons.replay, size: 16),
                        label: const Text('Reset Source'),
                      ),
                  ],
                ),
                const SizedBox(height: Insets.xs),
                Center(
                  child: SegmentedButton<RetouchMode>(
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      selectedBackgroundColor: scheme.primary.withValues(alpha: 0.25),
                      selectedForegroundColor: scheme.primary,
                    ),
                    segments: const [
                      ButtonSegment<RetouchMode>(
                        value: RetouchMode.heal,
                        label: Text('Heal'),
                        icon: Icon(Icons.auto_fix_high, size: 16),
                      ),
                      ButtonSegment<RetouchMode>(
                        value: RetouchMode.clone,
                        label: Text('Clone'),
                        icon: Icon(Icons.copy, size: 16),
                      ),
                    ],
                    selected: {currentMode},
                    onSelectionChanged: (set) {
                      HapticFeedback.selectionClick();
                      final newMode = set.first;
                      brushNotifier.setMode(newMode);
                      if (selectedPatch != null && selectedIndex != null) {
                        notifier.updateRetouchPatchAt(
                          selectedIndex,
                          selectedPatch.copyWith(mode: newMode),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.sm),

          // If patches exist, show horizontal patch selection bar
          if (patches.isNotEmpty) ...[
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: patches.length,
                itemBuilder: (context, idx) {
                  final p = patches[idx];
                  final isSelected = idx == selectedIndex;
                  final isHeal = p.mode == RetouchMode.heal;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isHeal ? Icons.auto_fix_high : Icons.copy,
                            size: 13,
                            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text('#${idx + 1} ${isHeal ? 'Heal' : 'Clone'}'),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        ref.read(selectedRetouchPatchIndexProvider.notifier).select(idx);
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: Insets.xs),
          ],

          // Spot Parameters Card
          Container(
            padding: const EdgeInsets.all(Insets.sm),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.all(Radius.circular(Radii.md)),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedPatch != null
                          ? 'Spot #${selectedIndex! + 1} (${currentMode == RetouchMode.heal ? 'Heal' : 'Clone'})'
                          : 'Spot Settings',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (selectedPatch != null)
                      Text(
                        '(${((selectedPatch.targetX) * 100).round()}%, ${((selectedPatch.targetY) * 100).round()}%)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Insets.xs),

                // Radius Slider
                _RetouchSliderRow(
                  label: 'Size',
                  value: currentRadius.clamp(0.01, 0.25),
                  min: 0.01,
                  max: 0.25,
                  displayPercent: (currentRadius * 100).round(),
                  scheme: scheme,
                  textTheme: theme.textTheme,
                  onChanged: (val) {
                    brushNotifier.setRadius(val);
                    if (selectedPatch != null && selectedIndex != null) {
                      notifier.updateRetouchPatchAt(
                        selectedIndex,
                        selectedPatch.copyWith(radius: val),
                      );
                    }
                  },
                ),

                // Feather Slider
                _RetouchSliderRow(
                  label: 'Feather',
                  value: currentFeather.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  displayPercent: (currentFeather * 100).round(),
                  scheme: scheme,
                  textTheme: theme.textTheme,
                  onChanged: (val) {
                    brushNotifier.setFeather(val);
                    if (selectedPatch != null && selectedIndex != null) {
                      notifier.updateRetouchPatchAt(
                        selectedIndex,
                        selectedPatch.copyWith(feather: val),
                      );
                    }
                  },
                ),

                // Opacity Slider
                _RetouchSliderRow(
                  label: 'Opacity',
                  value: currentOpacity.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  displayPercent: (currentOpacity * 100).round(),
                  scheme: scheme,
                  textTheme: theme.textTheme,
                  onChanged: (val) {
                    brushNotifier.setOpacity(val);
                    if (selectedPatch != null && selectedIndex != null) {
                      notifier.updateRetouchPatchAt(
                        selectedIndex,
                        selectedPatch.copyWith(opacity: val),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: 8,
            runSpacing: Insets.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${patches.length} ${patches.length == 1 ? 'patch' : 'patches'} applied',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (selectedPatch != null && selectedIndex != null)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete Patch'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                  ),
                  onPressed: () {
                    notifier.removeRetouchPatchAt(selectedIndex);
                    ref.read(selectedRetouchPatchIndexProvider.notifier).select(null);
                  },
                ),
              if (patches.isNotEmpty)
                TextButton(
                  onPressed: () {
                    notifier.clearRetouchPatches();
                    ref.read(selectedRetouchPatchIndexProvider.notifier).select(null);
                  },
                  child: const Text('Clear All'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RetouchSliderRow extends StatelessWidget {
  const _RetouchSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayPercent,
    required this.scheme,
    required this.textTheme,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int displayPercent;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: scheme.primary,
              inactiveTrackColor: scheme.surfaceContainerHighest,
              thumbColor: scheme.primary,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              trackHeight: 3,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        Container(
          width: 44,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          alignment: Alignment.centerRight,
          child: Text(
            '$displayPercent%',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
