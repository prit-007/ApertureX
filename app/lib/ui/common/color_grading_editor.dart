import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/recipe_controller.dart';

/// 3-Way Color Grading editor with premium interactive color wheels for
/// Shadows, Midtones, and Highlights, plus per-zone luminance and global
/// blending/balance controls.
class ColorGradingEditor extends ConsumerStatefulWidget {
  const ColorGradingEditor({super.key});

  @override
  ConsumerState<ColorGradingEditor> createState() => _ColorGradingEditorState();
}

class _GradingParams {
  const _GradingParams({
    required this.shadowHue,
    required this.shadowSat,
    required this.shadowLum,
    required this.midHue,
    required this.midSat,
    required this.midLum,
    required this.highlightHue,
    required this.highlightSat,
    required this.highlightLum,
    required this.blending,
    required this.balance,
  });

  final double shadowHue;
  final double shadowSat;
  final double shadowLum;
  final double midHue;
  final double midSat;
  final double midLum;
  final double highlightHue;
  final double highlightSat;
  final double highlightLum;
  final double blending;
  final double balance;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _GradingParams &&
          runtimeType == other.runtimeType &&
          shadowHue == other.shadowHue &&
          shadowSat == other.shadowSat &&
          shadowLum == other.shadowLum &&
          midHue == other.midHue &&
          midSat == other.midSat &&
          midLum == other.midLum &&
          highlightHue == other.highlightHue &&
          highlightSat == other.highlightSat &&
          highlightLum == other.highlightLum &&
          blending == other.blending &&
          balance == other.balance;

  @override
  int get hashCode => Object.hash(
        shadowHue,
        shadowSat,
        shadowLum,
        midHue,
        midSat,
        midLum,
        highlightHue,
        highlightSat,
        highlightLum,
        blending,
        balance,
      );
}

class _ColorGradingEditorState extends ConsumerState<ColorGradingEditor> {
  bool _threeWayMode = false;
  GradeWheelZone _zone = GradeWheelZone.shadows;

  (double hue, double sat, double lum) _extractZoneValues(
    _GradingParams grade,
    GradeWheelZone zone,
  ) =>
      switch (zone) {
        GradeWheelZone.shadows => (
          grade.shadowHue,
          grade.shadowSat,
          grade.shadowLum,
        ),
        GradeWheelZone.midtones => (
          grade.midHue,
          grade.midSat,
          grade.midLum,
        ),
        GradeWheelZone.highlights => (
          grade.highlightHue,
          grade.highlightSat,
          grade.highlightLum,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final grade = ref.watch(
      recipeControllerProvider.select(
        (s) => _GradingParams(
          shadowHue: s.recipe.gradeShadowHue,
          shadowSat: s.recipe.gradeShadowSat,
          shadowLum: s.recipe.gradeShadowLum,
          midHue: s.recipe.gradeMidHue,
          midSat: s.recipe.gradeMidSat,
          midLum: s.recipe.gradeMidLum,
          highlightHue: s.recipe.gradeHighlightHue,
          highlightSat: s.recipe.gradeHighlightSat,
          highlightLum: s.recipe.gradeHighlightLum,
          blending: s.recipe.gradeBlending,
          balance: s.recipe.gradeBalance,
        ),
      ),
    );
    final notifier = ref.read(recipeControllerProvider.notifier);
    final (rawHue, sat, lum) = _extractZoneValues(grade, _zone);
    final hue = (rawHue <= 1.0 && rawHue > 0) ? rawHue * 360.0 : rawHue;

    Widget zoneChip({
      required String label,
      required IconData icon,
      required bool isSelected,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
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
      bool compact = false,
    }) {
      final formatted =
          '${showPlus && value > 0 ? '+' : ''}${value.toStringAsFixed(2)}';
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 16, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Text(
                  formatted,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: compact ? 2 : 4,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: compact ? 5 : 7),
                overlayShape: RoundSliderOverlayShape(overlayRadius: compact ? 10 : 14),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
                onChangeEnd: (_) => onChangeEnd(),
                activeColor: scheme.primary,
                inactiveColor: scheme.onSurfaceVariant.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildWheelZoneCard(
      GradeWheelZone targetZone, {
      required double wheelSize,
      bool showHeader = true,
    }) {
      final (rawH, zSat, zLum) = _extractZoneValues(grade, targetZone);
      final zHue = (rawH <= 1.0 && rawH > 0) ? rawH * 360.0 : rawH;
      final zoneName = switch (targetZone) {
        GradeWheelZone.shadows => 'Shadows',
        GradeWheelZone.midtones => 'Midtones',
        GradeWheelZone.highlights => 'Highlights',
      };
      final zoneIcon = switch (targetZone) {
        GradeWheelZone.shadows => Icons.brightness_4,
        GradeWheelZone.midtones => Icons.brightness_6,
        GradeWheelZone.highlights => Icons.highlight,
      };

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHeader) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Icon(zoneIcon, size: 12, color: scheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        zoneName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${zHue.toStringAsFixed(0)}° · ${(zSat * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12.0,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
            Center(
              child: ColorGradingWheel(
                hue: zHue,
                saturation: zSat,
                size: wheelSize,
                onChanged: (newHue, newSat) {
                  notifier.setGradeWheel(targetZone, hue: newHue, sat: newSat);
                },
                onChangeEnd: () =>
                    notifier.commit(label: '$zoneName Color Grading'),
                onReset: () {
                  notifier.setGradeWheel(targetZone, hue: 0.0, sat: 0.0);
                  notifier.commit(label: 'Reset $zoneName');
                },
              ),
            ),
            const SizedBox(height: 2),
            sliderRow(
              label: 'Luminance',
              value: zLum,
              min: -1.0,
              max: 1.0,
              compact: true,
              onChanged: (v) => notifier.setGradeWheel(targetZone, lum: v),
              onChangeEnd: () =>
                  notifier.commit(label: '$zoneName Luminance'),
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
          // View Mode / Zone selector with icons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  zoneChip(
                    label: '3-Way',
                    icon: Icons.view_column_rounded,
                    isSelected: _threeWayMode,
                    onTap: () => setState(() => _threeWayMode = true),
                  ),
                  const SizedBox(width: 8),
                  zoneChip(
                    label: 'Shadows',
                    icon: Icons.brightness_4,
                    isSelected: !_threeWayMode && _zone == GradeWheelZone.shadows,
                    onTap: () => setState(() {
                      _threeWayMode = false;
                      _zone = GradeWheelZone.shadows;
                    }),
                  ),
                  const SizedBox(width: 8),
                  zoneChip(
                    label: 'Midtones',
                    icon: Icons.brightness_6,
                    isSelected: !_threeWayMode && _zone == GradeWheelZone.midtones,
                    onTap: () => setState(() {
                      _threeWayMode = false;
                      _zone = GradeWheelZone.midtones;
                    }),
                  ),
                  const SizedBox(width: 8),
                  zoneChip(
                    label: 'Highlights',
                    icon: Icons.highlight,
                    isSelected: !_threeWayMode && _zone == GradeWheelZone.highlights,
                    onTap: () => setState(() {
                      _threeWayMode = false;
                      _zone = GradeWheelZone.highlights;
                    }),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      if (_threeWayMode) {
                        notifier.setGradeWheel(GradeWheelZone.shadows, hue: 0.0, sat: 0.0, lum: 0.0);
                        notifier.setGradeWheel(GradeWheelZone.midtones, hue: 0.0, sat: 0.0, lum: 0.0);
                        notifier.setGradeWheel(GradeWheelZone.highlights, hue: 0.0, sat: 0.0, lum: 0.0);
                        notifier.setGradeGlobal(blending: 0.5, balance: 0.0);
                        notifier.commit(label: 'Reset All Color Grades');
                      } else {
                        notifier.setGradeWheel(_zone, hue: 0.0, sat: 0.0, lum: 0.0);
                        notifier.commit(label: 'Reset ${_zone.name}');
                      }
                    },
                    icon: const Icon(Icons.refresh, size: 14),
                    label: Text(
                      _threeWayMode ? 'Reset All' : 'Reset',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 4),

          if (_threeWayMode) ...[
            // 3-Way simultaneous wheels view (Lightroom Desktop & DaVinci Resolve parity)
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 540) {
                  final colWidth = (constraints.maxWidth - 32) / 3;
                  final wheelSize = (colWidth - 32).clamp(80.0, 140.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: buildWheelZoneCard(
                            GradeWheelZone.shadows,
                            wheelSize: wheelSize,
                          ),
                        ),
                        Expanded(
                          child: buildWheelZoneCard(
                            GradeWheelZone.midtones,
                            wheelSize: wheelSize,
                          ),
                        ),
                        Expanded(
                          child: buildWheelZoneCard(
                            GradeWheelZone.highlights,
                            wheelSize: wheelSize,
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  final cardWidth = math.min(constraints.maxWidth * 0.80, 240.0);
                  final wheelSize = (cardWidth - 48).clamp(90.0, 130.0);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: buildWheelZoneCard(
                            GradeWheelZone.shadows,
                            wheelSize: wheelSize,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: cardWidth,
                          child: buildWheelZoneCard(
                            GradeWheelZone.midtones,
                            wheelSize: wheelSize,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: cardWidth,
                          child: buildWheelZoneCard(
                            GradeWheelZone.highlights,
                            wheelSize: wheelSize,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ] else ...[
            // Single focus wheel mode
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Hue: ${hue.toStringAsFixed(0)}°   Sat: ${(sat * 100).toStringAsFixed(0)}%   Lum: ${(lum * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12.0,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

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

            sliderRow(
              label: 'Luminance',
              value: lum,
              min: -1.0,
              max: 1.0,
              onChanged: (v) => notifier.setGradeWheel(_zone, lum: v),
              onChangeEnd: () =>
                  notifier.commit(label: 'Color Grading Luminance'),
            ),
          ],

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
            value: grade.blending,
            min: 0.0,
            max: 1.0,
            showPlus: false,
            onChanged: (v) => notifier.setGradeGlobal(blending: v),
            onChangeEnd: () =>
                notifier.commit(label: 'Color Grading Blending'),
          ),
          sliderRow(
            label: 'Balance',
            value: grade.balance,
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

    // 3. Outer circle border & concentric saturation guides
    final guidePaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.33, guidePaint);
    canvas.drawCircle(center, radius * 0.66, guidePaint);

    final borderPaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);

    // 4. Subtle angle ticks (every 60 degrees)
    final tickPaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    for (var deg = 0; deg < 360; deg += 60) {
      final rad = deg * math.pi / 180.0;
      final outerX = center.dx + radius * math.cos(rad);
      final outerY = center.dy + radius * math.sin(rad);
      final innerX = center.dx + (radius - 6) * math.cos(rad);
      final innerY = center.dy + (radius - 6) * math.sin(rad);
      canvas.drawLine(Offset(innerX, innerY), Offset(outerX, outerY), tickPaint);
    }

    // 5. Crosshair center mark
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

    // 6. Draw puck at (hue, saturation)
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
    canvas.drawCircle(puckPos, 8, puckBorder);

    // Dark drop shadow ring
    final puckShadow = Paint()
      ..color = const Color(0x88000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(puckPos, 9.5, puckShadow);

    // Inner dot with hue color
    final puckInner = Paint()
      ..color = HSVColor.fromAHSV(1.0, hue, saturation, 1.0).toColor()
      ..style = PaintingStyle.fill;
    canvas.drawCircle(puckPos, 6, puckInner);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.hue != hue ||
      oldDelegate.saturation != saturation ||
      oldDelegate.surfaceColor != surfaceColor ||
      oldDelegate.outlineColor != outlineColor;
}