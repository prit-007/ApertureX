import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/recipe.dart';
import '../../edit/recipe_controller.dart';

/// 3-Way Color Grading editor (Shadows, Midtones, Highlights) with interactive
/// color wheels, luminance per zone, and global blending/balance controls.
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
    final (hue, sat, lum) = _zoneValues(recipe);

    Widget sliderRow({
      required String label,
      required double value,
      required double min,
      required double max,
      required ValueChanged<double> onChanged,
      required VoidCallback onChangeEnd,
      bool showPlus = true,
    }) {
      final formatted =
          '${showPlus && value > 0 ? '+' : ''}${value.toStringAsFixed(2)}';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
                onChangeEnd: (_) => onChangeEnd(),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                formatted,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<GradeWheelZone>(
            segments: const [
              ButtonSegment(
                value: GradeWheelZone.shadows,
                label: Text('Shadows'),
              ),
              ButtonSegment(
                value: GradeWheelZone.midtones,
                label: Text('Midtones'),
              ),
              ButtonSegment(
                value: GradeWheelZone.highlights,
                label: Text('Highlights'),
              ),
            ],
            selected: {_zone},
            onSelectionChanged: (selected) {
              setState(() => _zone = selected.first);
            },
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Hue: ${hue.toStringAsFixed(0)}°   Sat: ${(sat * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ColorGradingWheel(
              hue: hue,
              saturation: sat,
              size: 180,
              onChanged: (newHue, newSat) {
                notifier.setGradeWheel(_zone, hue: newHue, sat: newSat);
              },
              onChangeEnd: () => notifier.commit(label: 'Color Grading'),
              onReset: () {
                notifier.setGradeWheel(_zone, hue: 0.0, sat: 0.0);
                notifier.commit(label: 'Reset Color Grade');
              },
            ),
          ),
        ),
        sliderRow(
          label: 'Luminance',
          value: lum,
          min: -1.0,
          max: 1.0,
          onChanged: (v) => notifier.setGradeWheel(_zone, lum: v),
          onChangeEnd: () => notifier.commit(label: 'Color Grading Luminance'),
        ),
        Divider(height: 16, indent: 16, endIndent: 16, color: scheme.outlineVariant),
        sliderRow(
          label: 'Blending',
          value: recipe.gradeBlending,
          min: 0.0,
          max: 1.0,
          showPlus: false,
          onChanged: (v) => notifier.setGradeGlobal(blending: v),
          onChangeEnd: () => notifier.commit(label: 'Color Grading Blending'),
        ),
        sliderRow(
          label: 'Balance',
          value: recipe.gradeBalance,
          min: -1.0,
          max: 1.0,
          onChanged: (v) => notifier.setGradeGlobal(balance: v),
          onChangeEnd: () => notifier.commit(label: 'Color Grading Balance'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Interactive circular color wheel canvas.
class ColorGradingWheel extends StatelessWidget {
  const ColorGradingWheel({
    required this.hue,
    required this.saturation,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onReset,
    this.size = 180,
    super.key,
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

class _WheelPainter extends CustomPainter {
  _WheelPainter({
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
    Color(0xFFFFFF00), // 60 deg (Yellow)
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

    // 1. Paint Hue sweep gradient
    final sweepPaint = Paint()
      ..shader = const SweepGradient(
        colors: _rainbowColors,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sweepPaint);

    // 2. Overlay radial gradient from surface center to transparent edge
    final radialPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          surfaceColor,
          surfaceColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, radialPaint);

    // 3. Draw outer circle border
    final borderPaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);

    // 4. Draw crosshair center mark
    final crossPaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(center.dx - 4, center.dy),
      Offset(center.dx + 4, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 4),
      Offset(center.dx, center.dy + 4),
      crossPaint,
    );

    // 5. Draw Puck at (hue, saturation)
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
      ..strokeWidth = 2.5;
    canvas.drawCircle(puckPos, 7, puckBorder);

    // Dark drop shadow ring for visibility against light backgrounds
    final puckShadow = Paint()
      ..color = const Color(0x88000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(puckPos, 8.5, puckShadow);

    // Inner dot
    final puckInner = Paint()
      ..color = HSVColor.fromAHSV(1.0, hue, saturation, 1.0).toColor()
      ..style = PaintingStyle.fill;
    canvas.drawCircle(puckPos, 5, puckInner);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.hue != hue ||
      oldDelegate.saturation != saturation ||
      oldDelegate.surfaceColor != surfaceColor ||
      oldDelegate.outlineColor != outlineColor;
}
