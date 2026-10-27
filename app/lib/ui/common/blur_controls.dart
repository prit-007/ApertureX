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
import 'mask_controls.dart';
import 'parameter_control.dart';

/// Function signature for subject detection used to place the focus plane.
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
///
/// Organized into collapsible ExpansionTile groups with compact chips so the
/// sheet stays uncluttered even when all blur options are engaged.
class BlurControls extends ConsumerWidget {
  const BlurControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final notifier = ref.read(recipeControllerProvider.notifier);

    final currentShapeIndex = recipe.blurBokehShape.clamp(0, BokehShape.values.length - 1);
    final currentShape = BokehShape.values[currentShapeIndex];

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        expansionTileTheme: const ExpansionTileThemeData(
          shape: RoundedRectangleBorder(),
          collapsedShape: RoundedRectangleBorder(),
          tilePadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        ),
      ),
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          ExpansionTile(
            initiallyExpanded: true,
            title: _PanelTitle('Lens Blur'),
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: const Text('Depth-Aware Lens Blur'),
                subtitle: const Text('Optical depth-of-field + subject-aware bokeh'),
                visualDensity: VisualDensity.compact,
                value: recipe.blurEnabled,
                onChanged: (val) async {
                  notifier.setBlurEnabled(val);
                  if (val) {
                    await _applySubjectFocus(context, ref);
                  }
                },
              ),
              if (recipe.blurEnabled)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      key: const Key('blur-subject-focus'),
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.psychology, size: 14),
                      label: const Text('Re-run Subject Focus', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                    await _applySubjectFocus(context, ref);
                      },
                    ),
                  ),
                ),
              if (recipe.blurEnabled) ...[
                const _ParamPad(Parameter.blurAmount),
                const _ParamPad(Parameter.blurFocalPoint),
                const _ParamPad(Parameter.blurFocalRange),
              ],
            ],
          ),
          if (recipe.blurEnabled) ...[
            ExpansionTile(
              initiallyExpanded: false, // Collapsed by default to save space!
              title: _PanelTitle('Bokeh Shape & Specular'),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final shape in BokehShape.values)
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(shape.label, style: const TextStyle(fontSize: 11)),
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
                const _ParamPad(Parameter.blurBokehBoost),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Uppercase section title used inside BlurControls ExpansionTiles.
class _PanelTitle extends StatelessWidget {
  final String title;
  const _PanelTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
}

/// Shared subject-detection flow used both when blur is first enabled and
/// when the user taps "Re-run Subject Focus". Avoids duplicating the
/// consent → detect → apply focal plane → report UX.
Future<void> _applySubjectFocus(BuildContext context, WidgetRef ref) async {
  final bytes = ref.read(activeImageBytesProvider);
  if (bytes == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No photo loaded to place focus')),
      );
    }
    return;
  }

  final consent = await ref.read(aiConsentProvider.notifier).requestConsentDialog(context);
  if (!consent) {
    final notifier = ref.read(recipeControllerProvider.notifier);
    notifier.update(Parameter.blurAmount, 0.45);
    notifier.update(Parameter.blurFocalPoint, 0.40);
    notifier.update(Parameter.blurFocalRange, 0.25);
    notifier.commit(label: 'Lens Blur (center focus)');
    return;
  }

  ref.read(aiMaskInferringProvider.notifier).setInferring(true);
  ref.read(aiMaskStatusMessageProvider.notifier).setMessage(
      'Finding subject… Please wait a moment');

  try {
    final detector = ref.read(subjectDetectorProvider);
    final subject = await detector(bytes);
    final focalPoint = subject != null
        ? (0.25 + 0.40 * subject.cy).clamp(0.20, 0.80)
        : 0.40;
    final focalRange = subject != null
        ? (subject.ry * 0.90).clamp(0.15, 0.40)
        : 0.25;

    final notifier = ref.read(recipeControllerProvider.notifier);
    final recipe = ref.read(recipeControllerProvider).recipe;

    HapticFeedback.selectionClick();
    if (recipe.blurAmount < 0.20) {
      notifier.update(Parameter.blurAmount, 0.45);
    }
    notifier.update(Parameter.blurFocalPoint, focalPoint);
    notifier.update(Parameter.blurFocalRange, focalRange);
    notifier.commit(label: 'Subject-focused lens blur');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Subject focus placed: focal point ${(focalPoint * 100).round()}%, range ${(focalRange * 100).round()}%',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subject not detected — center focus applied'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  } finally {
    ref.read(aiMaskInferringProvider.notifier).setInferring(false);
    ref.read(aiMaskStatusMessageProvider.notifier).setMessage(null);
  }
}

/// Pads a ParameterControl with tight 12px horizontal, 2px vertical spacing.
class _ParamPad extends StatelessWidget {
  final Parameter param;
  const _ParamPad(this.param);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ParameterControl(parameter: param),
      );
}
