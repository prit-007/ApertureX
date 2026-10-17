import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/active_image.dart';
import '../../edit/recipe_controller.dart';
import '../../engine/engine.dart';
import 'precision_rotation_dial.dart';

enum GeometrySubTab {
  straighten,
  transform,
  perspective,
}

/// Geometry controls: rotate (90°), flip, and straighten. Writes to the shared
/// recipe; the transform is non-destructive.
class GeometryControls extends ConsumerWidget {
  const GeometryControls({super.key, this.subTab});

  final GeometrySubTab? subTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final notifier = ref.read(recipeControllerProvider.notifier);

    final autoStraightenBtn = FilledButton.tonalIcon(
      key: const Key('geometry-auto-straighten'),
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
      icon: const Icon(Icons.auto_fix_high),
      label: const Text('Auto'),
    );

    final transformButtons = Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () {
            notifier.rotate(-1);
            notifier.commit(label: 'Rotate');
          },
          icon: const Icon(Icons.rotate_90_degrees_ccw),
          label: const Text('Left'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            notifier.rotate(1);
            notifier.commit(label: 'Rotate');
          },
          icon: const Icon(Icons.rotate_90_degrees_cw),
          label: const Text('Right'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            notifier.toggleFlipH();
            notifier.commit(label: 'Flip H');
          },
          icon: const Icon(Icons.flip),
          label: const Text('Flip H'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            notifier.toggleFlipV();
            notifier.commit(label: 'Flip V');
          },
          icon: const Icon(Icons.flip_camera_android),
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
            children: [autoStraightenBtn],
          ),
        ),
        const PrecisionRotationDial(),
      ],
    );

    final perspectiveSection = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 84,
                child: Text('Perspective X'),
              ),
              Expanded(
                child: Slider(
                  value: recipe.perspectiveX.clamp(-1.0, 1.0),
                  min: -1,
                  max: 1,
                  onChanged: (v) => notifier.setPerspectiveX(v),
                  onChangeEnd: (_) => notifier.commit(label: 'Perspective X'),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  recipe.perspectiveX.toStringAsFixed(2),
                  textAlign: TextAlign.end,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(
                width: 84,
                child: Text('Perspective Y'),
              ),
              Expanded(
                child: Slider(
                  value: recipe.perspectiveY.clamp(-1.0, 1.0),
                  min: -1,
                  max: 1,
                  onChanged: (v) => notifier.setPerspectiveY(v),
                  onChangeEnd: (_) => notifier.commit(label: 'Perspective Y'),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  recipe.perspectiveY.toStringAsFixed(2),
                  textAlign: TextAlign.end,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(
                width: 84,
                child: Text('Skew X'),
              ),
              Expanded(
                child: Slider(
                  value: recipe.skewX.clamp(-1.0, 1.0),
                  min: -1,
                  max: 1,
                  onChanged: (v) => notifier.setSkewX(v),
                  onChangeEnd: (_) => notifier.commit(label: 'Skew X'),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  recipe.skewX.toStringAsFixed(2),
                  textAlign: TextAlign.end,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(
                width: 84,
                child: Text('Skew Y'),
              ),
              Expanded(
                child: Slider(
                  value: recipe.skewY.clamp(-1.0, 1.0),
                  min: -1,
                  max: 1,
                  onChanged: (v) => notifier.setSkewY(v),
                  onChangeEnd: (_) => notifier.commit(label: 'Skew Y'),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  recipe.skewY.toStringAsFixed(2),
                  textAlign: TextAlign.end,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (subTab == GeometrySubTab.straighten) {
      return straightenSection;
    } else if (subTab == GeometrySubTab.transform) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: transformButtons,
      );
    } else if (subTab == GeometrySubTab.perspective) {
      return perspectiveSection;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              autoStraightenBtn,
              OutlinedButton.icon(
                onPressed: () {
                  notifier.rotate(-1);
                  notifier.commit(label: 'Rotate');
                },
                icon: const Icon(Icons.rotate_90_degrees_ccw),
                label: const Text('Left'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  notifier.rotate(1);
                  notifier.commit(label: 'Rotate');
                },
                icon: const Icon(Icons.rotate_90_degrees_cw),
                label: const Text('Right'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  notifier.toggleFlipH();
                  notifier.commit(label: 'Flip H');
                },
                icon: const Icon(Icons.flip),
                label: const Text('Flip H'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  notifier.toggleFlipV();
                  notifier.commit(label: 'Flip V');
                },
                icon: const Icon(Icons.flip_camera_android),
                label: const Text('Flip V'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              const PrecisionRotationDial(),
              const SizedBox(height: 8),
              perspectiveSection,
            ],
          ),
        ),
      ],
    );
   }
 }
