import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/active_image.dart';
import '../../edit/crop_math.dart';
import '../../edit/recipe.dart' show fullCrop;
import '../../edit/recipe_controller.dart';
import '../../engine/engine.dart';
import 'precision_rotation_dial.dart';

enum GeometrySubTab {
  straighten,
  transform,
  perspective,
}

/// Geometry controls: aspect crop, rotate (90°), flip, straighten, perspective & skew.
/// Writes to the shared recipe; the transform is non-destructive.
class GeometryControls extends ConsumerWidget {
  const GeometryControls({super.key, this.subTab});

  final GeometrySubTab? subTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final notifier = ref.read(recipeControllerProvider.notifier);

    final autoStraightenBtn = FilledButton.tonalIcon(
      key: const Key('geometry-auto-straighten'),
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        backgroundColor: scheme.primary.withValues(alpha: 0.15),
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.4)),
      ),
      onPressed: () async {
        final bytes = ref.read(activeImageBytesProvider);
        if (bytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No photo loaded for auto-straighten')),
          );
          return;
        }
        try {
          final decoded = await AxEngine.decodeAnalysisProxy(bytes);
          final angle = await AxEngine.detectStraightenAngle(
            decoded.rgba,
            width: decoded.width,
            height: decoded.height,
          );
          if (angle.abs() >= 0.1) {
            HapticFeedback.selectionClick();
            notifier.setStraighten(angle.clamp(-45.0, 45.0));
            notifier.commit(label: 'Auto Straighten');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Straightened by ${angle > 0 ? '+' : ''}${angle.toStringAsFixed(1)}°',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Horizon is already straight'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Auto-straighten failed: $e')),
            );
          }
        }
      },
      icon: const Icon(Icons.auto_fix_high, size: 16),
      label: const Text('Auto', style: TextStyle(fontWeight: FontWeight.w600)),
    );

    // Aspect Ratio Presets
    void applyAspect(double? aspect) {
      HapticFeedback.selectionClick();
      if (aspect == null || aspect <= 0) {
        notifier.applyCrop(crop: fullCrop);
        return;
      }
      double l = 0, t = 0, r = 1, b = 1;
      if (aspect >= 1.0) {
        final h = (1.0 / aspect).clamp(0.1, 1.0);
        t = (1.0 - h) / 2.0;
        b = t + h;
      } else {
        final w = aspect.clamp(0.1, 1.0);
        l = (1.0 - w) / 2.0;
        r = l + w;
      }
      notifier.applyCrop(crop: [l, t, r, b]);
    }

    final isCurrentlyFullCrop = isFullCrop(recipe.crop);

    final aspectPresets = SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
        children: [
          _AspectChip(
            label: 'Free',
            isSelected: isCurrentlyFullCrop,
            onTap: () => applyAspect(null),
            scheme: scheme,
          ),
          _AspectChip(
            label: '1:1',
            isSelected: false,
            onTap: () => applyAspect(1.0),
            scheme: scheme,
          ),
          _AspectChip(
            label: '4:5',
            isSelected: false,
            onTap: () => applyAspect(4.0 / 5.0),
            scheme: scheme,
          ),
          _AspectChip(
            label: '16:9',
            isSelected: false,
            onTap: () => applyAspect(16.0 / 9.0),
            scheme: scheme,
          ),
          _AspectChip(
            label: '9:16',
            isSelected: false,
            onTap: () => applyAspect(9.0 / 16.0),
            scheme: scheme,
          ),
          _AspectChip(
            label: '3:2',
            isSelected: false,
            onTap: () => applyAspect(3.0 / 2.0),
            scheme: scheme,
          ),
          _AspectChip(
            label: '2:3',
            isSelected: false,
            onTap: () => applyAspect(2.0 / 3.0),
            scheme: scheme,
          ),
        ],
      ),
    );

    final transformButtons = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 8),
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            notifier.rotate(-1);
            notifier.commit(label: 'Rotate');
          },
          icon: const Icon(Icons.rotate_90_degrees_ccw, size: 16),
          label: const Text('Left'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 8),
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            notifier.rotate(1);
            notifier.commit(label: 'Rotate');
          },
          icon: const Icon(Icons.rotate_90_degrees_cw, size: 16),
          label: const Text('Right'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 8),
            backgroundColor: recipe.flipH ? scheme.primary.withValues(alpha: 0.15) : null,
            foregroundColor: recipe.flipH ? scheme.primary : null,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            notifier.toggleFlipH();
            notifier.commit(label: 'Flip H');
          },
          icon: const Icon(Icons.flip, size: 16),
          label: const Text('Flip H'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 8),
            backgroundColor: recipe.flipV ? scheme.primary.withValues(alpha: 0.15) : null,
            foregroundColor: recipe.flipV ? scheme.primary : null,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            notifier.toggleFlipV();
            notifier.commit(label: 'Flip V');
          },
          icon: const Icon(Icons.flip_camera_android, size: 16),
          label: const Text('Flip V'),
        ),
      ],
    );

    final straightenSection = Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              autoStraightenBtn,
              const SizedBox(width: 8),
              if (recipe.straighten.abs() >= 0.05)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    notifier.setStraighten(0.0);
                    notifier.commit(label: 'Reset Straighten');
                  },
                  icon: const Icon(Icons.refresh, size: 14),
                  label: Text('${recipe.straighten > 0 ? '+' : ''}${recipe.straighten.toStringAsFixed(1)}°'),
                ),
            ],
          ),
        ),
        const PrecisionRotationDial(),
      ],
    );

    Widget geoSliderRow({
      required String label,
      required double value,
      required ValueChanged<double> onChanged,
      required VoidCallback onChangeEnd,
      required VoidCallback onReset,
    }) {
      final isModified = value.abs() > 0.005;
      return Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isModified ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: isModified ? FontWeight.w600 : FontWeight.w500,
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
                value: value.clamp(-1.0, 1.0),
                min: -1,
                max: 1,
                onChanged: onChanged,
                onChangeEnd: (_) => onChangeEnd(),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: onReset,
            child: Container(
              width: 50,
              alignment: Alignment.centerRight,
              child: Text(
                '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isModified ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final perspectiveSection = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          geoSliderRow(
            label: 'Perspective X',
            value: recipe.perspectiveX,
            onChanged: (v) => notifier.setPerspectiveX(v),
            onChangeEnd: () => notifier.commit(label: 'Perspective X'),
            onReset: () {
              notifier.setPerspectiveX(0.0);
              notifier.commit(label: 'Reset Perspective X');
            },
          ),
          geoSliderRow(
            label: 'Perspective Y',
            value: recipe.perspectiveY,
            onChanged: (v) => notifier.setPerspectiveY(v),
            onChangeEnd: () => notifier.commit(label: 'Perspective Y'),
            onReset: () {
              notifier.setPerspectiveY(0.0);
              notifier.commit(label: 'Reset Perspective Y');
            },
          ),
          geoSliderRow(
            label: 'Skew X',
            value: recipe.skewX,
            onChanged: (v) => notifier.setSkewX(v),
            onChangeEnd: () => notifier.commit(label: 'Skew X'),
            onReset: () {
              notifier.setSkewX(0.0);
              notifier.commit(label: 'Reset Skew X');
            },
          ),
          geoSliderRow(
            label: 'Skew Y',
            value: recipe.skewY,
            onChanged: (v) => notifier.setSkewY(v),
            onChangeEnd: () => notifier.commit(label: 'Skew Y'),
            onReset: () {
              notifier.setSkewY(0.0);
              notifier.commit(label: 'Reset Skew Y');
            },
          ),
        ],
      ),
    );

    if (subTab == GeometrySubTab.straighten) {
      return straightenSection;
    } else if (subTab == GeometrySubTab.transform) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            aspectPresets,
            const SizedBox(height: 8),
            transformButtons,
          ],
        ),
      );
    } else if (subTab == GeometrySubTab.perspective) {
      return perspectiveSection;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Aspect Presets
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: aspectPresets,
        ),
        const SizedBox(height: 4),

        // Transform Buttons Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Container(
            padding: const EdgeInsets.all(Insets.sm),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: transformButtons,
          ),
        ),

        // Straighten & Dial
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              straightenSection,
              const SizedBox(height: 8),
              perspectiveSection,
            ],
          ),
        ),
      ],
    );
  }
}

class _AspectChip extends StatelessWidget {
  const _AspectChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.scheme,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? scheme.primary.withValues(alpha: 0.2)
                : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(
              color: isSelected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
