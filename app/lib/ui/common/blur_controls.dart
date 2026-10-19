import 'dart:typed_data';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../color/blur_spec.dart';
import '../../edit/active_image.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
import '../../engine/engine.dart';
import '../../settings/ai_consent.dart';
import '../../src/rust/api/mask.dart' as rust_mask;
import 'app_primitives.dart';
import 'mask_controls.dart';
import 'parameter_control.dart';

/// Function signature for subject detection for AI depth calibration.
typedef SubjectDetectorFn = Future<rust_mask.DetectedSubject?> Function(Uint8List imageBytes);

/// Riverpod provider for subject detection for depth calibration, overridable in tests.
final subjectDetectorProvider = Provider<SubjectDetectorFn>((ref) {
  return (Uint8List bytes) async {
    final decoded = await AxEngine.decodeAnalysisProxy(bytes);
    return AxEngine.detectSubject(
      decoded.rgba,
      width: decoded.width,
      height: decoded.height,
    );
  };
});

/// Blur controls: depth-aware synthetic aperture, focal point/range, bokeh blade shapes, and specular highlight boost.
class BlurControls extends ConsumerWidget {
  const BlurControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final notifier = ref.read(recipeControllerProvider.notifier);

    final currentShapeIndex = recipe.blurBokehShape.clamp(0, BokehShape.values.length - 1);
    final currentShape = BokehShape.values[currentShapeIndex];

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        const SectionHeader('Lens Blur'),
        SwitchListTile(
          title: const Text('Depth-Aware Lens Blur'),
          subtitle: const Text('Simulate optical depth-of-field and aperture bokeh'),
          value: recipe.blurEnabled,
          onChanged: (val) {
            notifier.setBlurEnabled(val);
          },
        ),
        if (recipe.blurEnabled) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  key: const Key('blur-ai-depth'),
                  avatar: const Icon(Icons.psychology, size: 16),
                  label: const Text('AI Depth Estimation'),
                  onPressed: () async {
                    final bytes = ref.read(activeImageBytesProvider);
                    if (bytes == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No photo loaded to analyze depth')),
                      );
                      return;
                    }
                    final consent = await ref
                        .read(aiConsentProvider.notifier)
                        .requestConsentDialog(context);
                    if (!consent) return;

                    ref.read(aiMaskInferringProvider.notifier).setInferring(true);
                    ref.read(aiMaskStatusMessageProvider.notifier).setMessage(
                      'AI Depth: Analyzing depth & subject focus… Please wait a moment',
                    );
                    try {
                      final detector = ref.read(subjectDetectorProvider);
                      final subject = await detector(bytes);
                      final focalPoint = subject != null
                          ? (0.25 + 0.40 * subject.cy).clamp(0.20, 0.80)
                          : 0.40;
                      final focalRange = subject != null
                          ? (subject.ry * 0.90).clamp(0.15, 0.40)
                          : 0.25;

                      HapticFeedback.selectionClick();
                      if (recipe.blurAmount < 0.20) {
                        notifier.update(Parameter.blurAmount, 0.45);
                      }
                      notifier.update(Parameter.blurFocalPoint, focalPoint);
                      notifier.update(Parameter.blurFocalRange, focalRange);
                      notifier.commit(label: 'AI Depth Calibration');

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'AI Depth calibrated: focal point ${(focalPoint * 100).round()}%, range ${(focalRange * 100).round()}%',
                            ),
                          ),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('AI Depth analysis failed; keeping current plane'),
                          ),
                        );
                      }
                    } finally {
                      ref.read(aiMaskInferringProvider.notifier).setInferring(false);
                      ref.read(aiMaskStatusMessageProvider.notifier).setMessage(null);
                    }
                  },
                ),
              ],
            ),
          ),
          const SectionHeader('Focus & Depth'),
          const ParameterControl(parameter: Parameter.blurAmount),
          const ParameterControl(parameter: Parameter.blurFocalPoint),
          const ParameterControl(parameter: Parameter.blurFocalRange),
          const SectionHeader('Bokeh Shape'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final shape in BokehShape.values)
                  ChoiceChip(
                    label: Text(shape.label),
                    selected: shape == currentShape,
                    onSelected: (selected) {
                      if (selected) {
                        notifier.setBlurBokehShape(shape.index);
                      }
                    },
                  ),
              ],
            ),
          ),
          const SectionHeader('Specular Highlights'),
          const ParameterControl(parameter: Parameter.blurBokehBoost),
        ],
      ],
    );
  }
}
