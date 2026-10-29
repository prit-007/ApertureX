import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/recipe.dart';
import '../../edit/recipe_controller.dart';

/// 3-Way Color Grading editor with premium interactive color wheels for
/// Shadows, Midtones, and Highlights, plus per-zone luminance and global
/// blending/balance controls.
class ColorGradingEditor extends ConsumerStatefulWidget {
  const ColorGradingEditor({super.key});

  @override
  ConsumerState<ColorGradingEditor> createState() => _ColorGradingEditorState();
}

class _ColorGradingEditorState extends ConsumerState<ColorGradingEditor> {
  GradeWheelZone _zone = GradeWheelZone.shadows;

  (double hue, double sat, double lum) _zoneValues(EditRecipe recipe) =>
      switch (_zone) {
        GradeWheelZone.shadows => (
          recipe.gradeShadowHue,
          recipe.gradeShadowSat,
          recipe.gradeShadowLum,
        ),
        GradeWheelZone.midtones => (
          recipe.gradeMidHue,
          recipe.gradeMidSat,
          recipe.gradeMidLum,
        ),
        GradeWheelZone.highlights => (
          recipe.gradeHighlightHue,
          recipe.gradeHighlightSat,
          recipe.gradeHighlightLum,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final notifier = ref.read(recipeControllerProvider.notifier);
    final (rawHue, sat, lum) = _zoneValues(recipe);
    final hue = (rawHue <= 1.0 && rawHue > 0) ? rawHue * 360.0 : rawHue;

    Widget zoneChip(GradeWheelZone zone, String label, IconData icon) {
      final isSelected = _zone == zone;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _zone = zone),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? scheme.primary.withValues(alpha: 0.15)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? scheme.primary.withValues(alpha: 0.6)
                  : scheme.outlineVariant.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 12,
                color: isSelected
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget sliderRow({
      required String label,
      required double value,
      required double min,
      required double max,
      required ValueChanged<double> onChanged,
      required VoidCallback onChangeEnd,
      bool showPlus = true,
      int divisions = 100,
    }) {
      final formatted =
          '${showPlus && value > 0 ? '+' : ''}${value.toStringAsFixed(2)}';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Text(
                  formatted,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: (_) => onChangeEnd(),
              activeColor: scheme.primary,
              inactiveColor: scheme.onSurfaceVariant.withValues(alpha: 0.2),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zone selector with icons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  zoneChip(
                    GradeWheelZone.shadows,
                    'Shadows',
                    Icons.brightness_4,
                  ),
                  const SizedBox(width: 8),
                  zoneChip(
                    GradeWheelZone.midtones,
                    'Midtones',
                    Icons.brightness_6,
                  ),
                  const SizedBox(width: 8),
                  zoneChip(
                    GradeWheelZone.highlights,
                    'Highlights',
                    Icons.highlight,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Hue/Sat/Lum readout
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Hue: ${hue.toStringAsFixed(0)}°   Sat: ${(sat * 100).toStringAsFixed(0)}%   Lum: ${(lum * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Color wheel - adaptive sizing
          Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final available = math.min(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return ColorGradingWheel(
                    hue: hue,
                    saturation: sat,
                    size: (available - 16).clamp(120.0, 180.0),
                    onChanged: (newHue, newSat) {
                      notifier.setGradeWheel(_zone, hue: newHue, sat: newSat);
                    },
                    onChangeEnd: () =>
                        notifier.commit(label: 'Color Grading'),
                    onReset: () {
                      notifier.setGradeWheel(_zone, hue: 0.0, sat: 0.0);
                      notifier.commit(label: 'Reset Color Grade');
                    },
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Luminance slider
          sliderRow(
            label: 'Luminance',
            value: lum,
            min: -1.0,
            max: 1.0,
            onChanged: (v) => notifier.setGradeWheel(_zone, lum: v),
            onChangeEnd: () =>
                notifier.commit(label: 'Color Grading Luminance'),
          ),

          Divider(
            height: 20,
            indent: 16,
            endIndent: 16,
            color: scheme.outlineVariant,
          ),

          Text(
            'GLOBAL GRADE BLEND',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),

          sliderRow(
            label: 'Blending',
            value: recipe.gradeBlending,
            min: 0.0,
            max: 1.0,
            showPlus: false,
            onChanged: (v) => notifier.setGradeGlobal(blending: v),
            onChangeEnd: () =>
                notifier.commit(label: 'Color Grading Blending'),
          ),
          sliderRow(
            label: 'Balance',
            value: recipe.gradeBalance,
            min: -1.0,
            max: 1.0,
            onChanged: (v) => notifier.setGradeGlobal(balance: v),
            onChangeEnd: () =>
                notifier.commit(label: 'Color Grading Balance'),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

/// Interactive circular color wheel canvas with radial gradient,
/// hue sweep, and draggable puck.
class ColorGradingWheel extends StatelessWidget {
  const ColorGradingWheel({
    super.key,
    required this.hue,
    required this.saturation,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onReset,
    this.size = 180,
  });

  final double hue;
  final double saturation;
  final double size;
  final void Function(double hue, double saturation) onChanged;
  final VoidCallback onChangeEnd;
  final VoidCallback onReset;

  void _handlePan(Offset localPosition, double radius) {
    final dx = localPosition.dx - radius;
    final dy = localPosition.dy - radius;
    final distance = math.sqrt(dx * dx + dy * dy);
    final sat = (distance / radius).clamp(0.0, 1.0);
    final angle = math.atan2(dy, dx);
    final deg = (angle * 180 / math.pi + 360) % 360;
    onChanged(deg, sat);
  }

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: onReset,
      onPanStart: (details) => _handlePan(details.localPosition, radius),
      onPanUpdate: (details) => _handlePan(details.localPosition, radius),
      onPanEnd: (_) => onChangeEnd(),
      child: CustomPaint(
        size: Size(size, size),
        painter: _WheelPainter(
          hue: hue,
          saturation: saturation,
          surfaceColor: Theme.of(context).colorScheme.surface,
          outlineColor: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

/// Interactive circular color wheel painter.
class _WheelPainter extends CustomPainter {
  const _WheelPainter({
    required this.hue,
    required this.saturation,
    required this.surfaceColor,
    required this.outlineColor,
  });

  final double hue;
  final double saturation;
  final Color surfaceColor;
  final Color outlineColor;

  static const List<Color> _rainbowColors = [
    Color(0xFFFF0000), // 0 deg (Red)
    Color(0xFFFF8000), // 30 deg (Orange)
    Color(0xFFFFD500), // 60 deg (Yellow)
    Color(0xFF00FF00), // 120 deg (Green)
    Color(0xFF00FFFF), // 180 deg (Cyan)
    Color(0xFF0000FF), // 240 deg (Blue)
    Color(0xFFFF00FF), // 300 deg (Magenta)
    Color(0xFFFF0000), // 360 deg (Red)
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Hue sweep gradient circle
    final sweepPaint = Paint()
      ..shader = const SweepGradient(
        colors: _rainbowColors,
        startAngle: 0,
        endAngle: 6.3,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sweepPaint);

    // 2. Radial gradient from center (surface) to edge (transparent)
    final radialPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          surfaceColor.withValues(alpha: 0.85),
          surfaceColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, radialPaint);

    // 3. Outer circle border
    final borderPaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);

    // 4. Crosshair center mark
    final crossPaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(center.dx - 5, center.dy),
      Offset(center.dx + 5, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 5),
      Offset(center.dx, center.dy + 5),
      crossPaint,
    );

    // 5. Draw puck at (hue, saturation)
    final puckDist = saturation * radius;
    final rad = hue * math.pi / 180.0;
    final puckPos = Offset(
      center.dx + puckDist * math.cos(rad),
      center.dy + puckDist * math.sin(rad),
    );

    // Outer puck ring
    final puckBorder = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(puckPos, 12, puckBorder);

    // Dark drop shadow ring
    final puckShadow = Paint()
      ..color = const Color(0x88000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(puckPos, 13.5, puckShadow);

    // Inner dot with hue color
    final puckInner = Paint()
      ..color = HSVColor.fromAHSV(1.0, hue, saturation, 1.0).toColor()
      ..style = PaintingStyle.fill;
    canvas.drawCircle(puckPos, 10, puckInner);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.hue != hue ||
      oldDelegate.saturation != saturation ||
      oldDelegate.surfaceColor != surfaceColor ||
      oldDelegate.outlineColor != outlineColor;
}