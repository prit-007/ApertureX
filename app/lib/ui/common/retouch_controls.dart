import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/retouch_patch.dart';
import 'app_primitives.dart';

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

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.sm),
      children: [
        const SectionHeader('Repair Mode'),
        Center(
          child: SegmentedButton<RetouchMode>(
            segments: const [
              ButtonSegment<RetouchMode>(
                value: RetouchMode.heal,
                label: Text('Heal'),
                icon: Icon(Icons.auto_fix_high),
              ),
              ButtonSegment<RetouchMode>(
                value: RetouchMode.clone,
                label: Text('Clone'),
                icon: Icon(Icons.copy),
              ),
            ],
            selected: {currentMode},
            onSelectionChanged: (set) {
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
        const SizedBox(height: Insets.md),
        Text(
          selectedPatch != null
              ? 'Editing Patch #${selectedIndex! + 1}'
              : 'Brush Settings (Tap canvas to heal)',
          style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: Insets.xs),

        // Radius Slider
        Row(
          children: [
            SizedBox(
              width: 70,
              child: Text('Size', style: theme.textTheme.bodyMedium),
            ),
            Expanded(
              child: Slider(
                value: currentRadius.clamp(0.01, 0.25),
                min: 0.01,
                max: 0.25,
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
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${(currentRadius * 100).round()}%',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),

        // Feather Slider
        Row(
          children: [
            SizedBox(
              width: 70,
              child: Text('Feather', style: theme.textTheme.bodyMedium),
            ),
            Expanded(
              child: Slider(
                value: currentFeather.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
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
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${(currentFeather * 100).round()}%',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),

        // Opacity Slider
        Row(
          children: [
            SizedBox(
              width: 70,
              child: Text('Opacity', style: theme.textTheme.bodyMedium),
            ),
            Expanded(
              child: Slider(
                value: currentOpacity.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
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
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${(currentOpacity * 100).round()}%',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),

        const SizedBox(height: Insets.sm),
        Row(
          children: [
            Text(
              '${patches.length} ${patches.length == 1 ? 'patch' : 'patches'} applied',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (selectedPatch != null && selectedIndex != null)
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete Patch'),
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
    );
  }
}
