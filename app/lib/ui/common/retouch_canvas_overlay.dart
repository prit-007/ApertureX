import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/recipe_controller.dart';
import '../../edit/retouch_patch.dart';
import 'retouch_controls.dart';

enum _DragHandle { none, target, source }

/// Interactive overlay rendered on the image canvas during Retouch mode.
///
/// Supports stylus input with pressure sensitivity, inverted stylus (eraser),
/// and drag-to-move for target and source texture patches.
class RetouchCanvasOverlay extends ConsumerStatefulWidget {
  const RetouchCanvasOverlay({super.key});

  @override
  ConsumerState<RetouchCanvasOverlay> createState() =>
      _RetouchCanvasOverlayState();
}

class _RetouchCanvasOverlayState extends ConsumerState<RetouchCanvasOverlay> {
  _DragHandle _dragHandle = _DragHandle.none;
  int? _dragIndex;

  @override
  Widget build(BuildContext context) {
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final selectedIndex = ref.watch(selectedRetouchPatchIndexProvider);
    final brush = ref.watch(retouchBrushProvider);
    final notifier = ref.read(recipeControllerProvider.notifier);

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
            final normX = (px / w).clamp(0.0, 1.0);
            final normY = (py / h).clamp(0.0, 1.0);

            // Eraser mode for inverted stylus: delete patch under stylus
            if (event.kind == PointerDeviceKind.invertedStylus) {
              for (int i = patches.length - 1; i >= 0; i--) {
                final p = patches[i];
                final tx = p.targetX * w;
                final ty = p.targetY * h;
                final r = p.radius * minDim;
                if ((px - tx) * (px - tx) + (py - ty) * (py - ty) <= r * r) {
                  notifier.removeRetouchPatchAt(i);
                  ref.read(selectedRetouchPatchIndexProvider.notifier).select(null);
                  return;
                }
              }
              return;
            }

            // Check if user tapped on existing patch's source or target handle
            for (int i = patches.length - 1; i >= 0; i--) {
              final p = patches[i];
              final tx = p.targetX * w;
              final ty = p.targetY * h;
              final sx = p.sourceX * w;
              final sy = p.sourceY * h;
              final r = p.radius * minDim;
              final handleHitR = math.max(r, 20.0);

              // Check source handle
              if ((px - sx) * (px - sx) + (py - sy) * (py - sy) <= handleHitR * handleHitR) {
                _dragHandle = _DragHandle.source;
                _dragIndex = i;
                ref.read(selectedRetouchPatchIndexProvider.notifier).select(i);
                return;
              }

              // Check target handle
              if ((px - tx) * (px - tx) + (py - ty) * (py - ty) <= handleHitR * handleHitR) {
                _dragHandle = _DragHandle.target;
                _dragIndex = i;
                ref.read(selectedRetouchPatchIndexProvider.notifier).select(i);
                return;
              }
            }

            // Otherwise, create a new patch at this position
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
          },
          onPointerMove: (event) {
            if (_dragHandle == _DragHandle.none || _dragIndex == null) return;
            final patches = ref.read(recipeControllerProvider).recipe.retouchPatches;
            if (_dragIndex! >= patches.length) return;

            final normX = (event.localPosition.dx / w).clamp(0.0, 1.0);
            final normY = (event.localPosition.dy / h).clamp(0.0, 1.0);
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
  });

  final List<RetouchPatch> patches;
  final int? selectedIndex;
  final ColorScheme themeScheme;

  @override
  void paint(Canvas canvas, Size size) {
    if (patches.isEmpty) return;

    final minDim = math.min(size.width, size.height);

    for (int i = 0; i < patches.length; i++) {
      final patch = patches[i];
      final isSelected = i == selectedIndex;
      final tx = patch.targetX * size.width;
      final ty = patch.targetY * size.height;
      final sx = patch.sourceX * size.width;
      final sy = patch.sourceY * size.height;
      final r = patch.radius * minDim;

      final accentColor = isSelected ? themeScheme.primary : Colors.white70;

      // Connecting line from target to source
      final linePaint = Paint()
        ..color = accentColor.withValues(alpha: 0.6)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(tx, ty), Offset(sx, sy), linePaint);

      // Target Circle
      final targetPaint = Paint()
        ..color = accentColor
        ..strokeWidth = isSelected ? 2.5 : 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(tx, ty), r, targetPaint);

      // Inner feather circle
      if (patch.feather > 0.0) {
        final innerR = r * (1.0 - patch.feather);
        final featherPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.35)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset(tx, ty), innerR, featherPaint);
      }

      // Source Circle (green / teal to distinguish as texture source)
      final sourcePaint = Paint()
        ..color = isSelected
            ? Colors.greenAccent
            : Colors.lightGreen.withValues(alpha: 0.7)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(sx, sy), r, sourcePaint);

      // Source center dot
      canvas.drawCircle(
        Offset(sx, sy),
        4.0,
        Paint()..color = isSelected ? Colors.greenAccent : Colors.lightGreen,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RetouchPainter old) =>
      old.patches != patches ||
      old.selectedIndex != selectedIndex ||
      old.themeScheme != themeScheme;
}
