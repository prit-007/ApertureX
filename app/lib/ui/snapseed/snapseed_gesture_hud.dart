import 'dart:ui' show FontFeature, ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../edit/parameter.dart';
import '../../edit/recipe_mapping.dart';
import '../../gesture/gesture_interpreter.dart';

/// Standard Material 3 icons for Snapseed grade tools.
IconData gradeToolIcon(GradeTool tool) => switch (tool) {
  GradeTool.exposure => Icons.exposure,
  GradeTool.contrast => Icons.contrast,
  GradeTool.highlights => Icons.brightness_high,
  GradeTool.shadows => Icons.brightness_low,
  GradeTool.whites => Icons.brightness_7,
  GradeTool.blacks => Icons.brightness_4,
  GradeTool.temperature => Icons.thermostat,
  GradeTool.tint => Icons.color_lens,
  GradeTool.vibrance => Icons.auto_awesome,
  GradeTool.saturation => Icons.water_drop,
  GradeTool.clarity => Icons.blur_on,
  GradeTool.dehaze => Icons.filter_drama,
  GradeTool.vignette => Icons.vignette,
  GradeTool.grain => Icons.grain,
  GradeTool.sharpen => Icons.details,
  GradeTool.shadowsGrade => Icons.tonality,
  GradeTool.midtonesGrade => Icons.brightness_medium,
  GradeTool.highlightsGrade => Icons.wb_sunny,
};

/// Human-friendly Snapseed-style tool labels.
String gradeToolLabel(GradeTool tool) => switch (tool) {
  GradeTool.exposure => 'Brightness',
  GradeTool.contrast => 'Contrast',
  GradeTool.highlights => 'Highlights',
  GradeTool.shadows => 'Shadows',
  GradeTool.whites => 'Whites',
  GradeTool.blacks => 'Blacks',
  GradeTool.temperature => 'Warmth',
  GradeTool.tint => 'Tint',
  GradeTool.vibrance => 'Vibrance',
  GradeTool.saturation => 'Saturation',
  GradeTool.clarity => 'Clarity',
  GradeTool.dehaze => 'Dehaze',
  GradeTool.vignette => 'Vignette',
  GradeTool.grain => 'Grain',
  GradeTool.sharpen => 'Sharpen',
  GradeTool.shadowsGrade => 'Shadows Grade',
  GradeTool.midtonesGrade => 'Midtones Grade',
  GradeTool.highlightsGrade => 'Highlights Grade',
};

/// High-performance custom painter for Snapseed zero-centered dual progress bars.
///
/// For bipolar parameters (-1..1 or -4..4), paints from center (0) outwards.
/// For unipolar parameters (0..1), paints from left (0) to right.
class _DualProgressBarPainter extends CustomPainter {
  const _DualProgressBarPainter({
    required this.progress,
    required this.isBipolar,
    required this.trackColor,
    required this.activeColor,
    required this.tickColor,
  });

  /// -1.0 .. 1.0 if bipolar; 0.0 .. 1.0 if unipolar
  final double progress;
  final bool isBipolar;
  final Color trackColor;
  final Color activeColor;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final trackRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      radius,
    );
    final trackPaint = Paint()..color = trackColor;
    canvas.drawRRect(trackRRect, trackPaint);

    if (isBipolar) {
      final centerX = size.width / 2;
      // Draw center tick
      final tickPaint = Paint()
        ..color = tickColor
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(centerX, 0),
        Offset(centerX, size.height),
        tickPaint,
      );

      final p = progress.clamp(-1.0, 1.0);
      if (p.abs() > 0.001) {
        final activePaint = Paint()..color = activeColor;
        final barWidth = p.abs() * (centerX);
        final left = p > 0 ? centerX : centerX - barWidth;
        final activeRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 0, barWidth, size.height),
          radius,
        );
        canvas.drawRRect(activeRRect, activePaint);
      }
    } else {
      final p = progress.clamp(0.0, 1.0);
      if (p > 0.001) {
        final activePaint = Paint()..color = activeColor;
        final barWidth = p * size.width;
        final activeRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, barWidth, size.height),
          radius,
        );
        canvas.drawRRect(activeRRect, activePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DualProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isBipolar != isBipolar ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.tickColor != tickColor;
  }
}

/// Floating Snapseed-style top scrubbing HUD pill.
///
/// Features:
/// - Tool icon and friendly label
/// - Zero-centered dual progress indicator (Impeller GPU rendered via CustomPainter)
/// - Tabular numerical readout (zero text jitter)
/// - Material 3 glassmorphic backdrop filter
class SnapseedScrubHud extends StatelessWidget {
  const SnapseedScrubHud({
    super.key,
    required this.tool,
    required this.value,
    this.hue,
    this.sat,
    this.visible = true,
  });

  final GradeTool tool;
  final double value;
  final double? hue;
  final double? sat;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final is2D = tool.is2D;
    final param = snapseedToolParameters[tool]?.first;
    final spec = param != null ? specOf(param) : null;

    final isBipolar = spec != null && spec.min < spec.neutral && spec.neutral < spec.max;

    double progress = 0.0;
    if (spec != null) {
      if (isBipolar) {
        if (value >= spec.neutral) {
          final range = spec.max - spec.neutral;
          progress = range > 0 ? ((value - spec.neutral) / range).clamp(0.0, 1.0) : 0.0;
        } else {
          final range = spec.neutral - spec.min;
          progress = range > 0 ? -((spec.neutral - value) / range).clamp(0.0, 1.0) : 0.0;
        }
      } else {
        final range = spec.max - spec.min;
        progress = range > 0 ? ((value - spec.min) / range).clamp(0.0, 1.0) : 0.0;
      }
    }

    String readout;
    if (is2D) {
      readout = 'H:${hue?.round() ?? 0}° S:${((sat ?? 0) * 100).round()}%';
    } else if (param == Parameter.exposure) {
      readout = '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}';
    } else {
      readout = '${value >= 0 ? '+' : ''}${(value * 100).round()}';
    }

    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              key: const Key('snapseed-scrub-hud'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    gradeToolIcon(tool),
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    gradeToolLabel(tool),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!is2D) ...[
                    CustomPaint(
                      size: const Size(110, 6),
                      painter: _DualProgressBarPainter(
                        progress: progress,
                        isBipolar: isBipolar,
                        trackColor: scheme.surfaceContainerHigh.withValues(alpha: 0.8),
                        activeColor: scheme.primary,
                        tickColor: scheme.outline.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    readout,
                    style: TextStyle(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Snapseed vertical parameter selection carousel.
///
/// Appears when dragging vertically across the screen (`GesturePhase.cycling`).
/// Shows the full parameter list for the active tool category, highlighting
/// the currently selected tool as the finger travels up or down.
class SnapseedParameterCarousel extends StatelessWidget {
  const SnapseedParameterCarousel({
    super.key,
    required this.category,
    required this.tools,
    required this.activeTool,
    required this.values,
    this.visible = true,
  });

  final ToolCategory category;
  final List<GradeTool> tools;
  final GradeTool activeTool;
  final Map<GradeTool, double> values;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final catName = switch (category) {
      ToolCategory.light => 'LIGHT',
      ToolCategory.color => 'COLOR',
      ToolCategory.effects => 'EFFECTS',
      ToolCategory.detail => 'DETAIL',
    };

    return Center(
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              key: const Key('snapseed-parameter-carousel'),
              width: 250,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(
                      catName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final t in tools) ...[
                    Builder(
                      builder: (context) {
                        final isSelected = t == activeTool;
                        final val = values[t] ?? 0.0;
                        final readout = t.is2D
                            ? ''
                            : (t == GradeTool.exposure
                                ? '${val >= 0 ? '+' : ''}${val.toStringAsFixed(2)}'
                                : '${val >= 0 ? '+' : ''}${(val * 100).round()}');

                        return Container(
                          key: Key('carousel-tool-${t.name}'),
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? scheme.primaryContainer.withValues(alpha: 0.75)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(
                                    color: scheme.primary.withValues(alpha: 0.5),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                gradeToolIcon(t),
                                size: isSelected ? 20 : 18,
                                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  gradeToolLabel(t),
                                  style: TextStyle(
                                    fontSize: isSelected ? 14 : 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? scheme.onPrimaryContainer : scheme.onSurface,
                                  ),
                                ),
                              ),
                              if (readout.isNotEmpty)
                                Text(
                                  readout,
                                  style: TextStyle(
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
