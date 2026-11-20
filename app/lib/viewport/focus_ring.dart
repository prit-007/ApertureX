import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interactive gold-amber focus target ring with draggable outer range boundary (Item 4.3).
/// Dragging the outer perimeter dynamically calibrates blurFocalRange.
class FocusRingWidget extends StatefulWidget {
  const FocusRingWidget({
    super.key,
    required this.focalRange,
    this.blurAmount = 0.5,
    required this.onFocalRangeChanged,
    required this.onFocalRangeCommit,
    this.onFocusPointDelta,
    this.onResetFocusPoint,
  });

  final double focalRange;
  final double blurAmount;
  final ValueChanged<double> onFocalRangeChanged;
  final VoidCallback onFocalRangeCommit;
  final ValueChanged<Offset>? onFocusPointDelta;
  final VoidCallback? onResetFocusPoint;

  @override
  State<FocusRingWidget> createState() => _FocusRingWidgetState();
}

class _FocusRingWidgetState extends State<FocusRingWidget> {
  double? _dragRadius;
  bool _isDraggingCenter = false;

  @override
  Widget build(BuildContext context) {
    final outerRadius =
        _dragRadius ?? (26.0 + widget.focalRange.clamp(0.01, 1.0) * 44.0);
    final size = (outerRadius + 20.0) * 2;
    final center = Offset(size / 2, size / 2);

    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: () {
          HapticFeedback.mediumImpact();
          widget.onResetFocusPoint?.call();
        },
        onPanStart: (details) {
          final dist = (details.localPosition - center).distance;
          if (dist < 26.0) {
            _isDraggingCenter = true;
            setState(() {});
          } else if ((dist - outerRadius).abs() < 24.0) {
            _dragRadius = dist;
            setState(() {});
          }
        },
        onPanUpdate: (details) {
          if (_isDraggingCenter) {
            widget.onFocusPointDelta?.call(details.delta);
            return;
          }
          final dist = (details.localPosition - center).distance;
          if (_dragRadius != null || (dist - outerRadius).abs() < 24.0) {
            final newRadius = dist.clamp(26.0, 70.0);
            _dragRadius = newRadius;
            final range = ((newRadius - 26.0) / 44.0).clamp(0.01, 1.0);
            widget.onFocalRangeChanged(range);
            HapticFeedback.selectionClick();
            setState(() {});
          }
        },
        onPanEnd: (_) {
          if (_isDraggingCenter) {
            _isDraggingCenter = false;
            setState(() {});
          }
          if (_dragRadius != null) {
            _dragRadius = null;
            widget.onFocalRangeCommit();
            setState(() {});
          }
        },
        child: CustomPaint(
          size: Size(size, size),
          painter: _FocusRingPainter(
            outerRadius: outerRadius,
            blurAmount: widget.blurAmount,
            isDraggingOuter: _dragRadius != null,
            isDraggingCenter: _isDraggingCenter,
          ),
        ),
      ),
    );
  }
}

/// Renders a gold-amber focus target ring with crosshairs, falloff glow, and depth-of-field boundary ring.
class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({
    this.outerRadius = 36.0,
    this.blurAmount = 0.5,
    this.isDraggingOuter = false,
    this.isDraggingCenter = false,
  });

  final double outerRadius;
  final double blurAmount;
  final bool isDraggingOuter;
  final bool isDraggingCenter;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringColor = isDraggingCenter
        ? const Color(0xFFFFE082)
        : const Color(0xFFFFB300);
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDraggingCenter ? 2.5 : 2.0;
    final dotPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.fill;

    // Center bullseye
    canvas.drawCircle(center, 13.0, ringPaint);
    canvas.drawCircle(center, 2.5, dotPaint);

    canvas.drawLine(
      center - const Offset(18, 0),
      center - const Offset(13, 0),
      ringPaint,
    );
    canvas.drawLine(
      center + const Offset(13, 0),
      center + const Offset(18, 0),
      ringPaint,
    );
    canvas.drawLine(
      center - const Offset(0, 18),
      center - const Offset(0, 13),
      ringPaint,
    );
    canvas.drawLine(
      center + const Offset(0, 13),
      center + const Offset(0, 18),
      ringPaint,
    );

    // Soft blur falloff aura visual representation
    final falloffAura = Paint()
      ..color = const Color(
        0xFFFFB300,
      ).withValues(alpha: 0.12 * blurAmount.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, outerRadius + 6.0, falloffAura);

    // Outer depth-of-field range ring
    final outerPaint = Paint()
      ..color = isDraggingOuter
          ? const Color(0xFFFFD54F)
          : const Color(0xFFFFB300).withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDraggingOuter ? 2.5 : 1.5;
    canvas.drawCircle(center, outerRadius, outerPaint);

    // 4 cardinal drag handles
    final pipPaint = Paint()
      ..color = isDraggingOuter
          ? const Color(0xFFFFD54F)
          : const Color(0xFFFFB300)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center + Offset(outerRadius, 0), 3.0, pipPaint);
    canvas.drawCircle(center - Offset(outerRadius, 0), 3.0, pipPaint);
    canvas.drawCircle(center + Offset(0, outerRadius), 3.0, pipPaint);
    canvas.drawCircle(center - Offset(0, outerRadius), 3.0, pipPaint);
  }

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) =>
      oldDelegate.outerRadius != outerRadius ||
      oldDelegate.blurAmount != blurAmount ||
      oldDelegate.isDraggingOuter != isDraggingOuter ||
      oldDelegate.isDraggingCenter != isDraggingCenter;
}
