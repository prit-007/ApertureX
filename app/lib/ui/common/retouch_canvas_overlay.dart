import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/recipe_controller.dart';
import '../../edit/retouch_patch.dart';
import '../../viewport/canvas_transform.dart';
import 'retouch_controls.dart';

enum _DragHandle { none, target, source, radius }

/// Interactive overlay rendered on the image canvas during Retouch mode.
///
/// Supports stylus input with pressure sensitivity, inverted stylus (eraser),
/// drag-to-move for target and source texture patches, and edge radius dragging.
class RetouchCanvasOverlay extends ConsumerStatefulWidget {
  const RetouchCanvasOverlay({super.key});

  @override
  ConsumerState<RetouchCanvasOverlay> createState() =>
      _RetouchCanvasOverlayState();
}

class _RetouchCanvasOverlayState extends ConsumerState<RetouchCanvasOverlay> {
  _DragHandle _dragHandle = _DragHandle.none;
  int? _dragIndex;

  Offset _toScreen(Offset norm, CanvasTransform? t, double w, double h) {
    if (t != null) return t.toScreen(norm);
    return Offset(norm.dx * w, norm.dy * h);
  }

  Offset? _toNormalized(Offset screen, CanvasTransform? t, double w, double h) {
    if (t != null) return t.toNormalized(screen);
    return Offset((screen.dx / w).clamp(0.0, 1.0), (screen.dy / h).clamp(0.0, 1.0));
  }

  double _radiusScreen(double normR, CanvasTransform? t, double minDim) {
    if (t != null) return t.radiusOf(normR);
    return normR * minDim;
  }

  @override
  Widget build(BuildContext context) {
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final selectedIndex = ref.watch(selectedRetouchPatchIndexProvider);
    final brush = ref.watch(retouchBrushProvider);
    final notifier = ref.read(recipeControllerProvider.notifier);
    final transform = ref.watch(canvasTransformProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final minDim = math.min(w, h);

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            final patches = ref.read(recipeControllerProvider).recipe.retouchPatches;
            final px = event.localPosition.dx;
            final py = event.localPosition.dy;
            final norm = _toNormalized(event.localPosition, transform, w, h);
            if (norm == null) return;
            final normX = norm.dx.clamp(0.0, 1.0);
            final normY = norm.dy.clamp(0.0, 1.0);

            // Eraser mode for inverted stylus: delete patch under stylus
            if (event.kind == PointerDeviceKind.invertedStylus) {
              for (int i = patches.length - 1; i >= 0; i--) {
                final p = patches[i];
                final tp = _toScreen(Offset(p.targetX, p.targetY), transform, w, h);
                final r = _radiusScreen(p.radius, transform, minDim);
                if ((px - tp.dx) * (px - tp.dx) + (py - tp.dy) * (py - tp.dy) <= r * r) {
                  notifier.removeRetouchPatchAt(i);
                  ref.read(selectedRetouchPatchIndexProvider.notifier).select(null);
                  HapticFeedback.lightImpact();
                  return;
                }
              }
              return;
            }

            // Check if user tapped on existing patch's handles
            for (int i = patches.length - 1; i >= 0; i--) {
              final p = patches[i];
              final tp = _toScreen(Offset(p.targetX, p.targetY), transform, w, h);
              final sp = _toScreen(Offset(p.sourceX, p.sourceY), transform, w, h);
              final r = _radiusScreen(p.radius, transform, minDim);
              final handleHitR = math.max(r, 22.0);

              // 1. Check radius resize handle (if this patch is currently selected)
              if (i == selectedIndex) {
                final handlePos = Offset(tp.dx + r, tp.dy);
                if ((px - handlePos.dx) * (px - handlePos.dx) +
                        (py - handlePos.dy) * (py - handlePos.dy) <=
                    12 * 12) {
                  _dragHandle = _DragHandle.radius;
                  _dragIndex = i;
                  HapticFeedback.selectionClick();
                  return;
                }
              }

              // 2. Check source handle
              if ((px - sp.dx) * (px - sp.dx) + (py - sp.dy) * (py - sp.dy) <= handleHitR * handleHitR) {
                _dragHandle = _DragHandle.source;
                _dragIndex = i;
                ref.read(selectedRetouchPatchIndexProvider.notifier).select(i);
                HapticFeedback.selectionClick();
                return;
              }

              // 3. Check target handle
              if ((px - tp.dx) * (px - tp.dx) + (py - tp.dy) * (py - tp.dy) <= handleHitR * handleHitR) {
                _dragHandle = _DragHandle.target;
                _dragIndex = i;
                ref.read(selectedRetouchPatchIndexProvider.notifier).select(i);
                HapticFeedback.selectionClick();
                return;
              }
            }

            // Otherwise, create a new patch at this position on the photo
            final pressure = event.pressure > 0.0 ? event.pressure : 1.0;
            final scaledRadius = (brush.radius * (0.5 + 0.5 * pressure)).clamp(0.01, 0.25);

            final srcX = (normX > 0.5 ? normX - 0.08 : normX + 0.08).clamp(0.02, 0.98);
            final srcY = (normY > 0.5 ? normY - 0.08 : normY + 0.08).clamp(0.02, 0.98);

            final newPatch = RetouchPatch(
              targetX: normX,
              targetY: normY,
              sourceX: srcX,
              sourceY: srcY,
              radius: scaledRadius,
              feather: brush.feather,
              opacity: brush.opacity,
              mode: brush.mode,
            );

            notifier.addRetouchPatch(newPatch);
            ref.read(selectedRetouchPatchIndexProvider.notifier).select(patches.length);
            _dragHandle = _DragHandle.target;
            _dragIndex = patches.length;
            HapticFeedback.selectionClick();
          },
          onPointerMove: (event) {
            if (_dragHandle == _DragHandle.none || _dragIndex == null) return;
            final patches = ref.read(recipeControllerProvider).recipe.retouchPatches;
            if (_dragIndex! >= patches.length) return;

            final norm = _toNormalized(event.localPosition, transform, w, h);
            if (norm == null) return;
            final normX = norm.dx.clamp(0.0, 1.0);
            final normY = norm.dy.clamp(0.0, 1.0);
            final current = patches[_dragIndex!];

            if (_dragHandle == _DragHandle.target) {
              final dx = normX - current.targetX;
              final dy = normY - current.targetY;
              notifier.updateRetouchPatchAt(
                _dragIndex!,
                current.copyWith(
                  targetX: normX,
                  targetY: normY,
                  sourceX: (current.sourceX + dx).clamp(0.0, 1.0),
                  sourceY: (current.sourceY + dy).clamp(0.0, 1.0),
                ),
              );
            } else if (_dragHandle == _DragHandle.source) {
              notifier.updateRetouchPatchAt(
                _dragIndex!,
                current.copyWith(sourceX: normX, sourceY: normY),
              );
            } else if (_dragHandle == _DragHandle.radius) {
              final tp = _toScreen(Offset(current.targetX, current.targetY), transform, w, h);
              final dist = (event.localPosition - tp).distance;
              final baseW = transform?.fitted.width ?? minDim;
              final newNormR = (dist / baseW).clamp(0.01, 0.25);
              notifier.updateRetouchPatchAt(
                _dragIndex!,
                current.copyWith(radius: newNormR),
              );
            }
          },
          onPointerUp: (_) {
            if (_dragHandle != _DragHandle.none) {
              notifier.commit(label: 'Move Patch');
              _dragHandle = _DragHandle.none;
              _dragIndex = null;
            }
          },
          child: CustomPaint(
            size: Size(w, h),
            painter: _RetouchPainter(
              patches: recipe.retouchPatches,
              selectedIndex: selectedIndex,
              themeScheme: Theme.of(context).colorScheme,
              transform: transform,
            ),
          ),
        );
      },
    );
  }
}

class _RetouchPainter extends CustomPainter {
  _RetouchPainter({
    required this.patches,
    required this.selectedIndex,
    required this.themeScheme,
    this.transform,
  });

  final List<RetouchPatch> patches;
  final int? selectedIndex;
  final ColorScheme themeScheme;
  final CanvasTransform? transform;

  @override
  void paint(Canvas canvas, Size size) {
    if (patches.isEmpty) return;

    final minDim = math.min(size.width, size.height);
    final t = transform;

    for (int i = 0; i < patches.length; i++) {
      final patch = patches[i];
      final isSelected = i == selectedIndex;
      final Offset tp = t != null
          ? t.toScreen(Offset(patch.targetX, patch.targetY))
          : Offset(patch.targetX * size.width, patch.targetY * size.height);
      final Offset sp = t != null
          ? t.toScreen(Offset(patch.sourceX, patch.sourceY))
          : Offset(patch.sourceX * size.width, patch.sourceY * size.height);
      final double r = t != null
          ? t.radiusOf(patch.radius)
          : patch.radius * minDim;

      // Color coding: Heal = Teal/Cyan (#00E5FF), Clone = Amber (#FFB300)
      final Color modeColor = patch.mode == RetouchMode.heal
          ? const Color(0xFF00E5FF)
          : const Color(0xFFFFB300);
      final Color targetColor = isSelected ? modeColor : Colors.white70;
      const Color sourceColor = Color(0xFF69F0AE); // Emerald green for source

      // 1. Connecting line from source to target with arrowhead pointing to target
      final linePaint = Paint()
        ..color = targetColor.withValues(alpha: isSelected ? 0.75 : 0.4)
        ..strokeWidth = isSelected ? 1.8 : 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(sp, tp, linePaint);

      // Draw arrowhead at target perimeter
      final angle = math.atan2(tp.dy - sp.dy, tp.dx - sp.dx);
      final arrowTip = Offset(
        tp.dx - math.cos(angle) * r,
        tp.dy - math.sin(angle) * r,
      );
      final arrowWing1 = Offset(
        arrowTip.dx - math.cos(angle - 0.45) * 8,
        arrowTip.dy - math.sin(angle - 0.45) * 8,
      );
      final arrowWing2 = Offset(
        arrowTip.dx - math.cos(angle + 0.45) * 8,
        arrowTip.dy - math.sin(angle + 0.45) * 8,
      );
      final arrowPath = Path()
        ..moveTo(arrowTip.dx, arrowTip.dy)
        ..lineTo(arrowWing1.dx, arrowWing1.dy)
        ..lineTo(arrowWing2.dx, arrowWing2.dy)
        ..close();
      canvas.drawPath(arrowPath, Paint()..color = targetColor);

      // 2. Source Circle & Center Dot
      final sourcePaint = Paint()
        ..color = sourceColor.withValues(alpha: isSelected ? 0.9 : 0.6)
        ..strokeWidth = isSelected ? 2.0 : 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(sp, r, sourcePaint);
      canvas.drawCircle(sp, 3.5, Paint()..color = sourceColor);

      // 3. Target Circle & Center Pin
      final targetPaint = Paint()
        ..color = targetColor
        ..strokeWidth = isSelected ? 2.5 : 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(tp, r, targetPaint);

      // Center crosshair / pin for target
      canvas.drawCircle(tp, isSelected ? 4.5 : 3.0, Paint()..color = targetColor);
      canvas.drawCircle(
        tp,
        isSelected ? 4.5 : 3.0,
        Paint()
          ..color = Colors.black87
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );

      // Inner feather circle for target
      if (patch.feather > 0.0) {
        final innerR = r * (1.0 - patch.feather);
        final featherPaint = Paint()
          ..color = targetColor.withValues(alpha: 0.35)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(tp, innerR, featherPaint);
      }

      // 4. Resize handle on target perimeter when selected
      if (isSelected) {
        final handlePos = Offset(tp.dx + r, tp.dy);
        canvas.drawCircle(handlePos, 6.0, Paint()..color = targetColor);
        canvas.drawCircle(
          handlePos,
          6.0,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RetouchPainter old) =>
      old.patches != patches ||
      old.selectedIndex != selectedIndex ||
      old.themeScheme != themeScheme ||
      old.transform != transform;
}

