import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../color/blur_spec.dart';
import '../../edit/active_image.dart';
import '../../edit/lens_blur_controller.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
import '../../engine/engine.dart';
import '../../l10n/app_strings.dart';
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
    final blurEnabled = ref.watch(
      recipeControllerProvider.select((s) => s.recipe.blurEnabled),
    );
    final blurBokehShape = ref.watch(
      recipeControllerProvider.select((s) => s.recipe.blurBokehShape),
    );
    final notifier = ref.read(recipeControllerProvider.notifier);

    final currentShapeIndex = blurBokehShape.clamp(0, BokehShape.values.length - 1);
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
            title: _PanelTitle(AppStrings.of(context).blurSectionLensBlur),
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text(AppStrings.of(context).blurDepthAware),
                subtitle: Text(AppStrings.of(context).blurDepthAwareSubtitle),
                visualDensity: VisualDensity.compact,
                value: blurEnabled,
                onChanged: (val) async {
                  notifier.setBlurEnabled(val);
                  if (val) {
                    await _applySubjectFocus(context, ref);
                  }
                },
              ),
              if (blurEnabled) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      ActionChip(
                        key: const Key('blur-subject-focus'),
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.psychology, size: 14),
                        label: Text(AppStrings.of(context).blurReRunSubjectFocus, style: const TextStyle(fontSize: 12)),
                        onPressed: () async {
                          await _applySubjectFocus(context, ref);
                        },
                      ),
                      const SizedBox(width: 8),
                      Consumer(
                        builder: (context, ref, _) {
                          final confidence = ref.watch(
                            lensBlurControllerProvider.select((s) => s.depthConfidence),
                          );
                          if (confidence <= 0.0) return const SizedBox.shrink();
                          final isLow = confidence < 0.35;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isLow ? Icons.warning_amber_rounded : Icons.auto_awesome,
                                size: 13,
                                color: isLow
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isLow
                                    ? AppStrings.of(context).blurConfidenceLow
                                    : AppStrings.of(context).blurConfidenceReliable((confidence * 100).round()),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final confidence = ref.watch(
                      lensBlurControllerProvider.select((s) => s.depthConfidence),
                    );
                    // Low-confidence banner with gradient mode switch: confidence < 0.35
                    if (confidence > 0.0 && confidence < 0.35) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Container(
                          key: const Key('low-confidence-banner'), // low confidence banner
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  AppStrings.of(context).blurLowConfidence,
                                  style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  notifier.update(Parameter.blurEnabled, 0.0);
                                  notifier.commit(label: 'Switch to Gradient');
                                },
                                child: Text(AppStrings.of(context).blurSwitchToGradient),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final visualizer = ref.watch(
                      lensBlurControllerProvider.select((s) => s.showDepthVisualizer),
                    );
                    return SwitchListTile(
                      key: const Key('blur-depth-visualizer-toggle'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      title: Text(AppStrings.of(context).blurDepthVisualizer),
                      subtitle: Text(AppStrings.of(context).blurDepthVisualizerSubtitle),
                      visualDensity: VisualDensity.compact,
                      value: visualizer,
                      onChanged: (val) {
                        ref.read(lensBlurControllerProvider.notifier).toggleDepthVisualizer(val);
                      },
                    );
                  },
                ),
                const _ParamPad(Parameter.blurAmount),
                const _ParamPad(Parameter.blurFocalPoint),
                const _ParamPad(Parameter.blurFocalRange),
              ],
            ],
          ),
          if (blurEnabled) ...[
            ExpansionTile(
              initiallyExpanded: false, // Collapsed by default to save space!
              title: _PanelTitle(AppStrings.of(context).blurSectionBokehShape),
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
                          avatar: Icon(_bokehIcon(shape), size: 14),
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

IconData _bokehIcon(BokehShape shape) => switch (shape) {
      BokehShape.circle => Icons.circle_outlined,
      BokehShape.pentagon => Icons.pentagon_outlined,
      BokehShape.hexagon => Icons.hexagon_outlined,
      BokehShape.septagon => Icons.filter_tilt_shift,
      BokehShape.catsEye => Icons.remove_red_eye_outlined,
      BokehShape.soapBubble => Icons.bubble_chart_outlined,
      BokehShape.swirl => Icons.cyclone,
    };

/// Uppercase section title used inside BlurControls ExpansionTiles.
class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.title);
  final String title;

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
  final strings = AppStrings.of(context);
  final bytes = ref.read(activeImageBytesProvider);
  if (bytes == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.blurNoPhotoFocus)),
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
      strings.blurFindingSubject);

    try {
    final detector = ref.read(subjectDetectorProvider);
    final subject = await detector(bytes);
    await ref.read(lensBlurControllerProvider.notifier).analyzeDepth(bytes);
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
            strings.blurSubjectFocusPlaced(
              (focalPoint * 100).round(),
              (focalRange * 100).round(),
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (error, stackTrace) {
    debugPrint('Subject focus detection error: $error\n$stackTrace');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.blurSubjectNotDetected),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } finally {
    if (context.mounted) {
      ref.read(aiMaskInferringProvider.notifier).setInferring(false);
      ref.read(aiMaskStatusMessageProvider.notifier).setMessage(null);
    }
  }
}

/// Pads a ParameterControl with tight 12px horizontal, 2px vertical spacing.
class _ParamPad extends StatelessWidget {
  const _ParamPad(this.param);
  final Parameter param;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ParameterControl(parameter: param),
      );
}

/// Custom painter for interactive focus ring showing focal point and depth-of-field range.
class FocusRingPainter extends CustomPainter {
  const FocusRingPainter({
    required this.focalPoint,
    required this.focalRange,
    this.center = const Offset(100, 100),
  });

  final double focalPoint;
  final double focalRange;
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = (size.shortestSide / 2) * 0.9;
    final innerR = (maxR * focalPoint).clamp(8.0, maxR);
    final outerR = (innerR + maxR * focalRange).clamp(innerR + 6.0, maxR);

    final innerPaint = Paint()
      ..color = const Color(0xFF26C6DA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final outerPaint = Paint()
      ..color = const Color(0xFFFFB300)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(c, innerR, innerPaint);
    canvas.drawCircle(c, outerR, outerPaint);
  }

  @override
  bool shouldRepaint(covariant FocusRingPainter oldDelegate) =>
      oldDelegate.focalPoint != focalPoint || oldDelegate.focalRange != focalRange;
}

/// Interactive focus ring widget: dragging the outer ring perimeter changes focal range.
class FocusRingWidget extends ConsumerWidget {
  const FocusRingWidget({super.key, this.size = 200.0});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focalPoint = ref.watch(recipeControllerProvider.select((s) => s.recipe.blurFocalPoint));
    final focalRange = ref.watch(recipeControllerProvider.select((s) => s.recipe.blurFocalRange));
    final notifier = ref.read(recipeControllerProvider.notifier);
    final center = Offset(size / 2, size / 2);
    final maxRadius = size / 2;

    return Semantics(
      label: 'Focus Ring Controller',
      slider: true,
      child: GestureDetector(
        onPanUpdate: (details) {
          final offset = details.localPosition - center;
          final r = offset.distance;
          final newRange = (r / maxRadius).clamp(0.05, 0.75);
          // Angle around the ring determines the focal depth plane (near↔far).
          final angle = offset.direction; // [-pi, pi]
          final newPoint = (angle / (2 * math.pi) + 0.5) % 1.0;
          notifier.update(Parameter.blurFocalPoint, newPoint);
          notifier.update(Parameter.blurFocalRange, newRange);
          notifier.commit(label: 'Focus Ring');
        },
        child: CustomPaint(
          size: Size(size, size),
          painter: FocusRingPainter(
            focalPoint: focalPoint,
            focalRange: focalRange,
            center: center,
          ),
        ),
      ),
    );
  }
}
