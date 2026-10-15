import 'dart:math' as math;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/recipe_controller.dart';

/// A Lightroom-style precision horizontal thumb rotation ruler dial.
///
/// Features:
/// - Sub-degree (`0.1°`) precision over `[-45.0°, +45.0°]`.
/// - Ruler tick marks with numbers every 5° / 10°.
/// - Haptic tick crossing whole degrees and magnetic snap at 0.0°.
/// - Tap angle badge to instantly reset to 0.0°.
/// - Fine-tuning `[-0.1°]` and `[+0.1°]` nudge buttons.
class PrecisionRotationDial extends ConsumerStatefulWidget {
  const PrecisionRotationDial({super.key});

  @override
  ConsumerState<PrecisionRotationDial> createState() =>
      _PrecisionRotationDialState();
}

class _PrecisionRotationDialState extends ConsumerState<PrecisionRotationDial> {
  double _lastTickDegree = 0.0;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final notifier = ref.read(recipeControllerProvider.notifier);
    final current = ref.read(recipeControllerProvider).recipe.straighten;

    // 1 pixel drag = 0.15 degrees
    final delta = -details.primaryDelta! * 0.15;
    var next = (current + delta).clamp(-45.0, 45.0);

    // Magnetic snap within 0.25° of zero
    if (next.abs() < 0.25 && current.abs() >= 0.25) {
      next = 0.0;
      HapticFeedback.mediumImpact();
    } else if (next.truncate() != _lastTickDegree.truncate()) {
      HapticFeedback.selectionClick();
    }
    _lastTickDegree = next;

    notifier.setStraighten(double.parse(next.toStringAsFixed(1)));
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    ref.read(recipeControllerProvider.notifier).commit(label: 'Straighten');
  }

  void _nudge(double delta) {
    final notifier = ref.read(recipeControllerProvider.notifier);
    final current = ref.read(recipeControllerProvider).recipe.straighten;
    final next = (current + delta).clamp(-45.0, 45.0);
    HapticFeedback.selectionClick();
    notifier.setStraighten(double.parse(next.toStringAsFixed(1)));
    notifier.commit(label: 'Straighten');
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(recipeControllerProvider.notifier);
    notifier.setStraighten(0.0);
    notifier.commit(label: 'Reset Straighten');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final angle = ref.watch(
      recipeControllerProvider.select((s) => s.recipe.straighten),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top row: fine nudge minus, angle badge / reset button, fine nudge plus
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const Key('rotation-dial-nudge-minus'),
              tooltip: '-0.1°',
              icon: const Icon(Icons.remove, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              visualDensity: VisualDensity.compact,
              onPressed: () => _nudge(-0.1),
            ),
            const SizedBox(width: Insets.xs),
            InkWell(
              key: const Key('rotation-dial-reset'),
              borderRadius: Radii.smAll,
              onTap: _reset,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.sm,
                  vertical: 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${angle.toStringAsFixed(1)}°',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: angle.abs() > 0.05
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    if (angle.abs() > 0.05) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.replay,
                        size: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: Insets.xs),
            IconButton(
              key: const Key('rotation-dial-nudge-plus'),
              tooltip: '+0.1°',
              icon: const Icon(Icons.add, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              visualDensity: VisualDensity.compact,
              onPressed: () => _nudge(0.1),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // Ruler track
        GestureDetector(
          key: const Key('rotation-dial-ruler'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: SizedBox(
            height: 32,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(double.infinity, 32),
                  painter: _RulerPainter(
                    angle: angle,
                    primary: scheme.primary,
                    outline: scheme.outlineVariant,
                    onSurface: scheme.onSurfaceVariant,
                  ),
                ),
                // Center pointer indicator
                Container(
                  width: 2.0,
                  height: 20,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(1.0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RulerPainter extends CustomPainter {
  const _RulerPainter({
    required this.angle,
    required this.primary,
    required this.outline,
    required this.onSurface,
  });

  final double angle;
  final Color primary;
  final Color outline;
  final Color onSurface;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    // 8 pixels per degree
    const pixelsPerDegree = 8.0;

    final tickPaint = Paint()
      ..color = outline
      ..strokeWidth = 1.0;

    final majorTickPaint = Paint()
      ..color = onSurface
      ..strokeWidth = 1.5;

    final zeroTickPaint = Paint()
      ..color = primary
      ..strokeWidth = 2.0;

    final textStyle = TextStyle(
      fontSize: 9,
      color: onSurface.withValues(alpha: 0.75),
      fontFamily: 'monospace',
    );

    // Visible range
    final visibleDegrees = (size.width / pixelsPerDegree / 2).ceil() + 2;
    final minDeg = math.max(-45, (angle - visibleDegrees).floor());
    final maxDeg = math.min(45, (angle + visibleDegrees).ceil());

    for (int deg = minDeg; deg <= maxDeg; deg++) {
      final x = centerX + (deg - angle) * pixelsPerDegree;
      if (x < 0 || x > size.width) continue;

      if (deg == 0) {
        canvas.drawLine(
          Offset(x, 4),
          Offset(x, size.height - 4),
          zeroTickPaint,
        );
      } else if (deg % 5 == 0) {
        // Major tick
        canvas.drawLine(
          Offset(x, 8),
          Offset(x, size.height - 8),
          majorTickPaint,
        );

        if (deg % 10 == 0) {
          final tp = TextPainter(
            text: TextSpan(text: '$deg', style: textStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(x - tp.width / 2, size.height - tp.height));
        }
      } else {
        // Minor tick
        canvas.drawLine(
          Offset(x, 14),
          Offset(x, size.height - 14),
          tickPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.angle != angle ||
      old.primary != primary ||
      old.outline != outline ||
      old.onSurface != onSurface;
}
