import 'dart:math' as math;

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';

/// Screen-edge docking options for [RotaryJogDial].
enum JogDialDockEdge {
  left,
  right,
}

/// A precision 120 FPS haptic Rotary Jog Dial for pro photo editing.
///
/// Features:
/// - Dynamic left/right screen-edge docking for ergonomic thumb reach.
/// - Angular drag scrubbing with fine (0.1 / 0.01) micro-increments.
/// - Micro-haptic clicks on graduation notches (`HapticFeedback.selectionClick`).
/// - Magnetic bump haptic on crossing 0.0 neutral (`HapticFeedback.mediumImpact`).
/// - Camera lens barrel fade gradient along the circular rotary arc.
/// - Outside barrier tap to dismiss.
class RotaryJogDial extends ConsumerStatefulWidget {
  const RotaryJogDial({
    super.key,
    required this.parameter,
    this.initialDockEdge = JogDialDockEdge.right,
    this.onClose,
  });

  final Parameter parameter;
  final JogDialDockEdge initialDockEdge;
  final VoidCallback? onClose;

  @override
  ConsumerState<RotaryJogDial> createState() => _RotaryJogDialState();
}

class _RotaryJogDialState extends ConsumerState<RotaryJogDial> {
  late JogDialDockEdge _dockEdge;
  bool _fineGear = false;
  double _accumulatedDelta = 0.0;
  double _lastTickValue = 0.0;

  @override
  void initState() {
    super.initState();
    _dockEdge = widget.initialDockEdge;
    final current = valueOf(
      ref.read(recipeControllerProvider).recipe,
      widget.parameter,
    );
    _lastTickValue = current;
  }

  void _handleClose() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _toggleDock() {
    HapticFeedback.selectionClick();
    setState(() {
      _dockEdge = _dockEdge == JogDialDockEdge.right
          ? JogDialDockEdge.left
          : JogDialDockEdge.right;
    });
  }

  void _toggleGear() {
    HapticFeedback.selectionClick();
    setState(() {
      _fineGear = !_fineGear;
    });
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    final spec = specOf(widget.parameter);
    final notifier = ref.read(recipeControllerProvider.notifier);
    notifier.update(widget.parameter, spec.neutral);
    notifier.commit(label: 'Reset ${spec.label}');
    _lastTickValue = spec.neutral;
  }

  void _onWheelPanUpdate(DragUpdateDetails details) {
    final spec = specOf(widget.parameter);
    final current = valueOf(
      ref.read(recipeControllerProvider).recipe,
      widget.parameter,
    );
    final notifier = ref.read(recipeControllerProvider.notifier);

    // Vertical drag: dragging UP increases value, DOWN decreases value.
    // If left-docked, the same intuitive vertical thumb motion applies.
    final stepSize = _fineGear ? 0.01 : 0.1;
    final sensitivity = _fineGear ? 0.002 : 0.01;
    final delta = -details.delta.dy * sensitivity;
    _accumulatedDelta += delta;

    if (_accumulatedDelta.abs() >= stepSize) {
      final steps = (_accumulatedDelta / stepSize).truncate();
      _accumulatedDelta -= steps * stepSize;

      var next = (current + steps * stepSize).clamp(spec.min, spec.max);
      // Precision rounding to avoid floating point drift
      next = double.parse(next.toStringAsFixed(_fineGear ? 3 : 2));

      // 0.0 / neutral crossing magnetic haptic
      if ((current > spec.neutral && next <= spec.neutral) ||
          (current < spec.neutral && next >= spec.neutral) ||
          (current.abs() >= 0.05 && next == 0.0)) {
        HapticFeedback.mediumImpact();
      } else if ((next / stepSize).round() != (_lastTickValue / stepSize).round()) {
        HapticFeedback.selectionClick();
      }

      _lastTickValue = next;
      notifier.update(widget.parameter, next);
    }
  }

  void _onWheelPanEnd(DragEndDetails details) {
    final spec = specOf(widget.parameter);
    ref.read(recipeControllerProvider.notifier).commit(label: spec.label);
    _accumulatedDelta = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spec = specOf(widget.parameter);
    final value = valueOf(
      ref.watch(recipeControllerProvider).recipe,
      widget.parameter,
    );

    final isRight = _dockEdge == JogDialDockEdge.right;
    final formattedValue = '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}';

    return Stack(
      children: [
        // Outside barrier: dismisses on tap
        Positioned.fill(
          child: GestureDetector(
            key: const Key('jog-dial-barrier'),
            behavior: HitTestBehavior.opaque,
            onTap: _handleClose,
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),
        ),

        // Positioned Jog Dial HUD & Rotary Arc on docked edge
        Positioned(
          left: isRight ? null : 0,
          right: isRight ? 0 : null,
          top: 0,
          bottom: 0,
          width: 260,
          child: SafeArea(
            child: Row(
              textDirection: isRight ? TextDirection.rtl : TextDirection.ltr,
              children: [
                // The Rotary Wheel Arc
                GestureDetector(
                  key: const Key('jog-dial-rotary-wheel'),
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: _onWheelPanUpdate,
                  onPanEnd: _onWheelPanEnd,
                  child: SizedBox(
                    width: 90,
                    height: double.infinity,
                    child: ShaderMask(
                      // Camera lens barrel edge-fade gradient
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.18, 0.82, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _RotaryArcPainter(
                          value: value,
                          min: spec.min,
                          max: spec.max,
                          neutral: spec.neutral,
                          scheme: scheme,
                          isRightDock: isRight,
                        ),
                      ),
                    ),
                  ),
                ),

                // HUD Panel (Readout + Controls)
                Expanded(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: Insets.xs),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.sm,
                        vertical: Insets.md,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Parameter Name
                          Text(
                            spec.label,
                            key: const Key('jog-dial-label'),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Insets.xs),

                          // Large Tabular Value
                          Text(
                            formattedValue,
                            key: const Key('jog-dial-value'),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: value == spec.neutral
                                  ? scheme.onSurface
                                  : scheme.primary,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: Insets.sm),

                          // Action Buttons Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Reset Button
                              IconButton.filledTonal(
                                key: const Key('jog-dial-reset'),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Reset',
                                onPressed: _reset,
                                icon: const Icon(Icons.refresh, size: 18),
                              ),
                              // Gear Toggle (0.1x vs 0.01x)
                              OutlinedButton(
                                key: const Key('jog-dial-gear-toggle'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  minimumSize: const Size(40, 28),
                                ),
                                onPressed: _toggleGear,
                                child: Text(
                                  _fineGear ? '0.01x' : '0.1x',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Insets.xs),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Dock Edge Toggle
                              IconButton(
                                key: const Key('jog-dial-dock-toggle'),
                                visualDensity: VisualDensity.compact,
                                tooltip: isRight ? 'Dock Left' : 'Dock Right',
                                onPressed: _toggleDock,
                                icon: Icon(
                                  isRight ? Icons.dock : Icons.dock_outlined,
                                  size: 18,
                                ),
                              ),
                              // Close Button
                              IconButton(
                                key: const Key('jog-dial-close'),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Done',
                                onPressed: _handleClose,
                                icon: const Icon(Icons.check, size: 18),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

/// Helper function to open [RotaryJogDial] as a translucent fullscreen overlay.
Future<void> showRotaryJogDial(
  BuildContext context, {
  required Parameter parameter,
  JogDialDockEdge initialDockEdge = JogDialDockEdge.right,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Jog Dial',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, anim1, anim2) {
      return RotaryJogDial(
        parameter: parameter,
        initialDockEdge: initialDockEdge,
        onClose: () => Navigator.of(context).pop(),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return FadeTransition(opacity: anim1, child: child);
    },
  );
}

/// Custom painter for the camera-lens barrel curved rotary rim and graduations.
class _RotaryArcPainter extends CustomPainter {
  const _RotaryArcPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.neutral,
    required this.scheme,
    required this.isRightDock,
  });

  final double value;
  final double min;
  final double max;
  final double neutral;
  final ColorScheme scheme;
  final bool isRightDock;

  @override
  void paint(Canvas canvas, Size size) {
    final arcRadius = size.height * 0.45;
    final center = Offset(
      isRightDock ? size.width + arcRadius * 0.6 : -arcRadius * 0.6,
      size.height / 2,
    );

    // Rim arc
    final rimPaint = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.3)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final baseAngle = isRightDock ? math.pi : 0.0;
    const sweep = math.pi / 2.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: arcRadius),
      baseAngle - sweep / 2,
      sweep,
      false,
      rimPaint,
    );

    // Radial graduation ticks
    final majorTickPaint = Paint()
      ..color = scheme.onSurfaceVariant.withValues(alpha: 0.8)
      ..strokeWidth = 2.0;

    final minorTickPaint = Paint()
      ..color = scheme.onSurfaceVariant.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    const totalTicks = 41; // symmetric ticks
    final angleStep = sweep / (totalTicks - 1);
    final startAngle = baseAngle - sweep / 2;

    // Shift ticks according to value offset
    final valueNormalized = (value - neutral) / (max - min);
    final angleOffset = valueNormalized * sweep * 0.8;

    for (var i = 0; i < totalTicks; i++) {
      final tickAngle = startAngle + i * angleStep + (isRightDock ? -angleOffset : angleOffset);
      if (tickAngle < baseAngle - sweep / 2 || tickAngle > baseAngle + sweep / 2) {
        continue;
      }

      final isMajor = i % 5 == 0;
      final tickLen = isMajor ? 14.0 : 7.0;

      final cosA = math.cos(tickAngle);
      final sinA = math.sin(tickAngle);

      final p1 = Offset(
        center.dx + (arcRadius - (isRightDock ? tickLen : 0)) * cosA,
        center.dy + (arcRadius - (isRightDock ? tickLen : 0)) * sinA,
      );
      final p2 = Offset(
        center.dx + (arcRadius + (isRightDock ? 0 : tickLen)) * cosA,
        center.dy + (arcRadius + (isRightDock ? 0 : tickLen)) * sinA,
      );

      canvas.drawLine(p1, p2, isMajor ? majorTickPaint : minorTickPaint);
    }

    // Active center indicator needle
    final needlePaint = Paint()
      ..color = scheme.primary
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final needleCos = math.cos(baseAngle);
    final needleSin = math.sin(baseAngle);
    final n1 = Offset(
      center.dx + (arcRadius - 16) * needleCos,
      center.dy + (arcRadius - 16) * needleSin,
    );
    final n2 = Offset(
      center.dx + (arcRadius + 16) * needleCos,
      center.dy + (arcRadius + 16) * needleSin,
    );
    canvas.drawLine(n1, n2, needlePaint);
  }

  @override
  bool shouldRepaint(covariant _RotaryArcPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.isRightDock != isRightDock ||
        oldDelegate.scheme != scheme;
  }
}
