import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../edit/adjustment_layer.dart';
import '../../edit/node_editor.dart';
import '../../edit/recipe_controller.dart';
import '../../viewport/canvas_transform.dart';
import '../../viewport/mask_peek.dart';

/// How an active pointer is interacting with a node.
enum _NodeDrag { idle, move, resize, place, startHandle, endHandle }

/// The interactive layer for node-based selective editing (issue #25).
///
/// Rendered **over** the shared [ImageCanvas] (outside its transform) while
/// node mode is enabled. It absorbs every pointer event — the canvas below
/// gets none, so pan/zoom/TAT are suspended until the mode is left — and maps
/// screen gestures onto normalised mask parameters:
///
///  * **tap empty photo** → drop a new radial control point there;
///  * **drag the node** → move it;
///  * **drag the ring (or its right-hand handle)** → resize the radius;
///  * nodes render exactly where the Rust mask (`mask.rs`) puts them.
class NodeOverlay extends ConsumerStatefulWidget {
  const NodeOverlay({super.key});

  /// Scale a logical-pixel tolerance by DPR with a sane floor/ceiling
  /// (issue #50). The base value is calibrated at DPR 1.0; clamping keeps
  /// extreme densities (e.g. 3.5× tablets) from ballooning the hit area.
  static double scaleTolerance(double base, double dpr) =>
      (base * dpr.clamp(1.0, 2.0)).clamp(base * 0.75, base * 2.0);

  @override
  ConsumerState<NodeOverlay> createState() => NodeOverlayState();
}

class NodeOverlayState extends ConsumerState<NodeOverlay> {
  /// Screen-pixel tolerances for the centre handle and the ring, scaled by
  /// device pixel ratio with a sane floor/ceiling (issue #50).
  late double _centerHit;
  late double _ringHit;

  /// Movement before a down becomes a drag (Flutter's kTouchSlop-ish), scaled
  /// by device pixel ratio with a floor/ceiling (issue #50).
  late double _slop;

  /// Radius (fraction of width) of a freshly placed node.
  static const double _defaultRadius = 0.18;

  Offset? _down;
  Offset? _downNorm;
  List<double>? _initialParams;
  bool _moved = false;
  int? _dragIndex;
  _NodeDrag _mode = _NodeDrag.idle;
  List<double>? _liveBrushPoints;
  bool _isErasing = false;
  Offset? _pointerPos;

  void _reset() {
    _down = null;
    _downNorm = null;
    _initialParams = null;
    _moved = false;
    _dragIndex = null;
    _mode = _NodeDrag.idle;
    _liveBrushPoints = null;
    _isErasing = false;
  }

  /// Exposed for tests (issue #50).
  double get centerHit => _centerHit;

  /// Exposed for tests (issue #50).
  double get ringHit => _ringHit;

  /// Exposed for tests (issue #50).
  double get slop => _slop;

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(nodeEditorProvider.select((s) => s.enabled));
    final transform = ref.watch(canvasTransformProvider);
    final layers = ref.watch(
      recipeControllerProvider.select((s) => s.recipe.layers),
    );
    final selected = ref.watch(nodeEditorProvider.select((s) => s.selected));
    final eraserMode = ref.watch(nodeEditorProvider.select((s) => s.eraserMode));
    final dpr = MediaQuery.devicePixelRatioOf(context);
    _centerHit = NodeOverlay.scaleTolerance(18, dpr);
    _ringHit = NodeOverlay.scaleTolerance(18, dpr);
    _slop = NodeOverlay.scaleTolerance(8, dpr);
    if (!enabled || transform == null) {
      // Zero-impact (and, importantly, no Listener): the photo below keeps
      // every gesture until the transform exists.
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerHover: (e) => setState(() => _pointerPos = e.localPosition),
      onPointerDown: (e) {
        _pointerPos = e.localPosition;
        _onDown(e, transform, layers);
      },
      onPointerMove: (e) {
        _pointerPos = e.localPosition;
        _onMove(e, transform, layers);
      },
      onPointerUp: (_) => _onUp(),
      onPointerCancel: (_) => _reset(),
      child: IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: _NodesPainter(
            layers: layers,
            selectedIndex: selected,
            transform: transform,
            primary: scheme.primary,
            liveBrushPoints: _liveBrushPoints,
            pointerPos: _pointerPos,
            isEraser: eraserMode,
          ),
        ),
      ),
    );
  }

  void _onDown(PointerDownEvent e, CanvasTransform t, List<AdjustmentLayer> layers) {
    // Palm rejection (issue #35): stylus-only mode drops every non-stylus
    // pointer before it can place or drag a node.
    final stylusOnly = ref.read(stylusOnlyModeProvider);
    final isStylus = e.kind == PointerDeviceKind.stylus ||
        e.kind == PointerDeviceKind.invertedStylus;
    if (stylusOnly && !isStylus) return;
    if (_down != null) {
      // A second finger lands: abandon the node gesture (no accidental edits
      // while the user reaches to re-enter two-finger zoom via the HUD).
      _reset();
      return;
    }
    _down = e.localPosition;
    _downNorm = t.toNormalized(e.localPosition);
    _moved = false;
    final selectedIdx = ref.read(nodeEditorProvider.select((s) => s.selected));
    final isEraser = ref.read(nodeEditorProvider.select((s) => s.eraserMode)) ||
        e.kind == PointerDeviceKind.invertedStylus;

    if (selectedIdx != null &&
        selectedIdx >= 0 &&
        selectedIdx < layers.length &&
        layers[selectedIdx].maskKind == MaskKind.brush &&
        isEraser) {
      final n = _downNorm;
      if (n != null) {
        _isErasing = true;
        _dragIndex = selectedIdx;
        final layer = layers[selectedIdx];
        final eraseR = layer.brushRadius;
        ref.read(recipeControllerProvider.notifier).updateLayerAt(
          selectedIdx,
          layer.withErasedNear(n.dx, n.dy, eraseR),
        );
        setState(() {});
        return;
      }
    }

    final hit = _hitNode(t, layers, e.localPosition);
    if (hit != null) {
      _dragIndex = hit.$1;
      _mode = hit.$2;
      if (hit.$1 < layers.length) {
        _initialParams = List<double>.from(layers[hit.$1].maskParams);
      }
      ref.read(nodeEditorProvider.notifier).select(hit.$1);
      HapticFeedback.selectionClick();
      return;
    }

    if (selectedIdx != null &&
        selectedIdx >= 0 &&
        selectedIdx < layers.length &&
        layers[selectedIdx].maskKind == MaskKind.brush) {
      final n = _downNorm;
      if (n != null) {
        final pr = (e.kind == PointerDeviceKind.stylus)
            ? e.pressure.clamp(0.05, 1.0)
            : 1.0;
        _liveBrushPoints = [n.dx, n.dy, pr];
        _dragIndex = selectedIdx;
        setState(() {});
        return;
      }
    }

    _mode = _NodeDrag.place;
    _dragIndex = null;
  }

  void _onMove(PointerMoveEvent e, CanvasTransform t, List<AdjustmentLayer> layers) {
    if (_down == null) return;

    if (_isErasing) {
      final selectedIdx = _dragIndex ?? ref.read(nodeEditorProvider.select((s) => s.selected));
      if (selectedIdx != null &&
          selectedIdx >= 0 &&
          selectedIdx < layers.length &&
          layers[selectedIdx].maskKind == MaskKind.brush) {
        final n = t.toNormalized(e.localPosition);
        if (n != null) {
          final layer = layers[selectedIdx];
          final eraseR = layer.brushRadius;
          ref.read(recipeControllerProvider.notifier).updateLayerAt(
            selectedIdx,
            layer.withErasedNear(n.dx, n.dy, eraseR),
          );
        }
      }
      return;
    }

    if (_liveBrushPoints != null) {
      final n = t.toNormalized(e.localPosition);
      if (n != null) {
        final pr = (e.kind == PointerDeviceKind.stylus)
            ? e.pressure.clamp(0.05, 1.0)
            : 1.0;
        _liveBrushPoints!.addAll([n.dx, n.dy, pr]);
        setState(() {});
      }
      return;
    }

    if (_dragIndex == null) return;
    if (_mode != _NodeDrag.move &&
        _mode != _NodeDrag.resize &&
        _mode != _NodeDrag.startHandle &&
        _mode != _NodeDrag.endHandle) {
      return;
    }
    if ((e.localPosition - _down!).distance > _slop) _moved = true;
    if (!_moved) return;

    final index = _dragIndex!;
    if (index >= layers.length) {
      _reset();
      return;
    }
    final layer = layers[index];
    final n = t.toNormalized(e.localPosition);
    if (n == null) return;
    final delta = _downNorm != null
        ? Offset(n.dx - _downNorm!.dx, n.dy - _downNorm!.dy)
        : Offset.zero;
    final p = _initialParams ?? layer.maskParams;

    if (layer.maskKind == MaskKind.linear && p.length >= 4) {
      List<double> newParams;
      if (_mode == _NodeDrag.startHandle) {
        newParams = [
          (p[0] + delta.dx).clamp(0.0, 1.0),
          (p[1] + delta.dy).clamp(0.0, 1.0),
          p[2],
          p[3],
        ];
      } else if (_mode == _NodeDrag.endHandle) {
        newParams = [
          p[0],
          p[1],
          (p[2] + delta.dx).clamp(0.0, 1.0),
          (p[3] + delta.dy).clamp(0.0, 1.0),
        ];
      } else {
        newParams = [
          (p[0] + delta.dx).clamp(0.0, 1.0),
          (p[1] + delta.dy).clamp(0.0, 1.0),
          (p[2] + delta.dx).clamp(0.0, 1.0),
          (p[3] + delta.dy).clamp(0.0, 1.0),
        ];
      }
      ref.read(recipeControllerProvider.notifier).updateLayerAt(
        index,
        layer.copyWith(maskParams: newParams),
      );
      return;
    }

    if (layer.maskKind == MaskKind.sky && p.isNotEmpty) {
      ref.read(recipeControllerProvider.notifier).updateLayerAt(
        index,
        layer.copyWith(
          maskParams: [
            (p[0] + delta.dy).clamp(0.05, 0.95),
            p.length > 1 ? p[1] : 0.15,
            p.length > 2 ? p[2] : 0.5,
          ],
        ),
      );
      return;
    }

    if (layer.maskKind == MaskKind.brush && p.length >= 5) {
      if (_mode == _NodeDrag.move) {
        final newPts = List<double>.from(p);
        for (var j = 3; j < newPts.length; j += 3) {
          if (newPts[j] >= 0 && newPts[j + 1] >= 0) {
            newPts[j] = (p[j] + delta.dx).clamp(0.0, 1.0);
            newPts[j + 1] = (p[j + 1] + delta.dy).clamp(0.0, 1.0);
          }
        }
        ref.read(recipeControllerProvider.notifier).updateLayerAt(
          index,
          layer.copyWith(maskParams: newPts),
        );
        return;
      }
    }

    if (layer.maskKind == MaskKind.subject && p.length >= 4) {
      final feather = p.length >= 5 ? p[4] : 0.25;
      final List<double> params;
      switch (_mode) {
        case _NodeDrag.move:
          params = [
            (p[0] + delta.dx).clamp(0.0, 1.0),
            (p[1] + delta.dy).clamp(0.0, 1.0),
            p[2],
            p[3],
            feather,
          ];
        case _NodeDrag.resize:
          final c = t.toScreen(Offset(p[0], p[1]));
          final rxScreen = p[2] * t.fitted.width * t.scale;
          final ryScreen = p[3] * t.fitted.height * t.scale;
          if (rxScreen <= 0 || ryScreen <= 0) return;
          final dx = (e.localPosition.dx - c.dx) / rxScreen;
          final dy = (e.localPosition.dy - c.dy) / ryScreen;
          final d = math.sqrt(dx * dx + dy * dy);
          if (d <= 0) return;
          final rx = (p[2] * d).clamp(0.03, 1.0);
          final ratio = p[2] > 0 ? rx / p[2] : 1.0;
          params = [p[0], p[1], rx, p[3] * ratio, feather];
        default:
          return;
      }
      ref.read(recipeControllerProvider.notifier).updateLayerAt(
        index,
        layer.copyWith(maskParams: params),
      );
      return;
    }

    if (layer.maskKind != MaskKind.radial || p.length < 5) {
      _reset();
      return;
    }
    final List<double> params;
    switch (_mode) {
      case _NodeDrag.move:
        params = [
          (p[0] + delta.dx).clamp(0.0, 1.0),
          (p[1] + delta.dy).clamp(0.0, 1.0),
          p[2],
          p[3],
          p[4],
        ];
      case _NodeDrag.resize:
        final c = t.toScreen(Offset(p[0], p[1]));
        final rxScreen = p[2] * t.fitted.width * t.scale;
        final ryScreen = p[3] * t.fitted.height * t.scale;
        if (rxScreen <= 0 || ryScreen <= 0) return;
        final dx = (e.localPosition.dx - c.dx) / rxScreen;
        final dy = (e.localPosition.dy - c.dy) / ryScreen;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d <= 0) return;
        final rx = (p[2] * d).clamp(0.03, 1.0);
        final ratio = p[2] > 0 ? rx / p[2] : 1.0;
        params = [p[0], p[1], rx, p[3] * ratio, p[4]];
      default:
        return;
    }
    ref
        .read(recipeControllerProvider.notifier)
        .updateLayerAt(index, layer.copyWith(maskParams: params));
  }

  void _onUp() {
    if (_down == null) return;

    if (_liveBrushPoints != null && _dragIndex != null) {
      final layers = ref.read(recipeControllerProvider).recipe.layers;
      if (_dragIndex! < layers.length) {
        final layer = layers[_dragIndex!];
        final oldParams = layer.maskParams;
        final baseR = oldParams.isNotEmpty ? oldParams[0] : 0.06;
        final feather = oldParams.length > 1 ? oldParams[1] : 0.25;
        final oldCount = (oldParams.length > 2) ? oldParams[2].toInt() : 0;
        final addedCount = _liveBrushPoints!.length ~/ 3;
        final newCount = oldCount > 0 ? (oldCount + 1 + addedCount) : addedCount;
        final newParams = <double>[
          baseR,
          feather,
          newCount.toDouble(),
          if (oldCount > 0 && oldParams.length >= 3 + oldCount * 3) ...[
            ...oldParams.sublist(3, 3 + oldCount * 3),
            -1.0, -1.0, -1.0, // Stroke break sentinel
          ],
          ..._liveBrushPoints!,
        ];
        ref.read(recipeControllerProvider.notifier).updateLayerAt(
          _dragIndex!,
          layer.copyWith(maskParams: newParams),
        );
      }
      _liveBrushPoints = null;
      _reset();
      return;
    }

    if (_mode == _NodeDrag.place && !_moved) _place();
    _reset();
  }

  void _place() {
    final t = ref.read(canvasTransformProvider);
    final down = _down;
    if (t == null || down == null) return;
    final n = t.toNormalized(down);
    if (n == null) return;
    final controller = ref.read(recipeControllerProvider.notifier);
    final index = ref.read(recipeControllerProvider).recipe.layers.length;
    controller.addLayer(
      AdjustmentLayer(
        maskKind: MaskKind.radial,
        maskParams: [
          n.dx.clamp(0.0, 1.0),
          n.dy.clamp(0.0, 1.0),
          _defaultRadius,
          _defaultRadius * t.aspect,
          0.3,
        ],
        exposure: 0.5,
      ),
    );
    ref.read(nodeEditorProvider.notifier).select(index);
    HapticFeedback.selectionClick();
  }

  (int, _NodeDrag)? _hitNode(
    CanvasTransform t,
    List<AdjustmentLayer> layers,
    Offset p,
  ) {
    for (var i = layers.length - 1; i >= 0; i--) {
      final l = layers[i];
      if (l.maskKind == MaskKind.radial && l.maskParams.length >= 5) {
        final pm = l.maskParams;
        final c = t.toScreen(Offset(pm[0], pm[1]));
        final rxScreen = pm[2] * t.fitted.width * t.scale;
        final ryScreen = pm[3] * t.fitted.height * t.scale;
        if (rxScreen <= 0 || ryScreen <= 0) continue;
        if ((p - c).distance <= _centerHit) return (i, _NodeDrag.move);
        final dx = (p.dx - c.dx) / rxScreen;
        final dy = (p.dy - c.dy) / ryScreen;
        final d = math.sqrt(dx * dx + dy * dy);
        final rAvg = (rxScreen + ryScreen) / 2;
        if ((d - 1).abs() * rAvg <= _ringHit) return (i, _NodeDrag.resize);
        if (d <= 1) return (i, _NodeDrag.move);
      } else if (l.maskKind == MaskKind.subject && l.maskParams.length >= 4) {
        final pm = l.maskParams;
        final c = t.toScreen(Offset(pm[0], pm[1]));
        final rxScreen = pm[2] * t.fitted.width * t.scale;
        final ryScreen = pm[3] * t.fitted.height * t.scale;
        if (rxScreen <= 0 || ryScreen <= 0) continue;
        if ((p - c).distance <= _centerHit) return (i, _NodeDrag.move);
        final dx = (p.dx - c.dx) / rxScreen;
        final dy = (p.dy - c.dy) / ryScreen;
        final d = math.sqrt(dx * dx + dy * dy);
        final rAvg = (rxScreen + ryScreen) / 2;
        if ((d - 1).abs() * rAvg <= _ringHit) return (i, _NodeDrag.resize);
        if (d <= 1) return (i, _NodeDrag.move);
      } else if (l.maskKind == MaskKind.linear && l.maskParams.length >= 4) {
        final pm = l.maskParams;
        final p0 = t.toScreen(Offset(pm[0], pm[1]));
        final p1 = t.toScreen(Offset(pm[2], pm[3]));
        final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
        if ((p - p0).distance <= _centerHit * 1.5) return (i, _NodeDrag.startHandle);
        if ((p - p1).distance <= _centerHit * 1.5) return (i, _NodeDrag.endHandle);
        if ((p - mid).distance <= _centerHit * 2.2) return (i, _NodeDrag.move);
        final l2 = (p1 - p0).distanceSquared;
        if (l2 > 0) {
          final param = (((p.dx - p0.dx) * (p1.dx - p0.dx) + (p.dy - p0.dy) * (p1.dy - p0.dy)) / l2).clamp(0.0, 1.0);
          final proj = Offset(p0.dx + param * (p1.dx - p0.dx), p0.dy + param * (p1.dy - p0.dy));
          if ((p - proj).distance <= _centerHit * 1.5) return (i, _NodeDrag.move);
        }
      } else if (l.maskKind == MaskKind.sky && l.maskParams.isNotEmpty) {
        final pm = l.maskParams;
        final horizonY = t.toScreen(Offset(0.5, pm[0])).dy;
        if ((p.dy - horizonY).abs() <= _centerHit * 1.8) return (i, _NodeDrag.move);
      } else if (l.maskKind == MaskKind.brush && l.maskParams.length >= 5) {
        final pts = l.maskParams;
        final count = pts.length > 2 ? pts[2].toInt() : 0;
        if (count > 0 && pts.length >= 5 && pts[3] >= 0 && pts[4] >= 0) {
          final origin = t.toScreen(Offset(pts[3], pts[4]));
          if ((p - origin).distance <= _centerHit * 1.8) return (i, _NodeDrag.move);
        }
      }
    }

    return null;
  }
}

/// Paints the control points and ruby mask visualization for all mask kinds.
class _NodesPainter extends CustomPainter {
  const _NodesPainter({
    required this.layers,
    required this.selectedIndex,
    required this.transform,
    required this.primary,
    this.liveBrushPoints,
    this.pointerPos,
    this.isEraser = false,
  });

  final List<AdjustmentLayer> layers;
  final int? selectedIndex;
  final CanvasTransform? transform;
  final Color primary;
  final List<double>? liveBrushPoints;
  final Offset? pointerPos;
  final bool isEraser;

  @override
  void paint(Canvas canvas, Size size) {
    final t = transform;
    if (t == null) return;
    const rubyColor = Color(0xFFE53935);

    // Draw brush / eraser cursor ring at pointerPos
    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < layers.length &&
        layers[selectedIndex!].maskKind == MaskKind.brush &&
        pointerPos != null) {
      final layer = layers[selectedIndex!];
      final radius = layer.brushRadius * t.fitted.width * t.scale;
      final feather = layer.brushFeather;
      final ringPaint = Paint()
        ..color = (isEraser ? Colors.white : primary).withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      // Inner solid circle
      canvas.drawCircle(pointerPos!, radius, ringPaint);

      // Outer circle for feather boundary
      if (feather > 0) {
        final outerPaint = Paint()
          ..color = (isEraser ? Colors.white : primary).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(pointerPos!, radius * (1.0 + feather), outerPaint);
      }
    }

    for (var i = 0; i < layers.length; i++) {
      final l = layers[i];
      final selected = i == selectedIndex;

      switch (l.maskKind) {
        case MaskKind.radial:
          if (l.maskParams.length < 5) continue;
          final p = l.maskParams;
          final rxScreen = p[2] * t.fitted.width * t.scale;
          final ryScreen = p[3] * t.fitted.height * t.scale;
          if (rxScreen <= 0 || ryScreen <= 0) continue;
          final c = t.toScreen(Offset(p[0], p[1]));
          final rect = Rect.fromCenter(center: c, width: rxScreen * 2, height: ryScreen * 2);

          if (selected) {
            canvas.drawOval(
              rect,
              Paint()..color = rubyColor.withValues(alpha: 0.18),
            );
          }
          canvas.drawOval(
            rect,
            Paint()
              ..color = Colors.black.withValues(alpha: 0.55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5,
          );
          canvas.drawOval(
            rect,
            Paint()
              ..color = selected ? primary : Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
          if (selected) {
            canvas.drawCircle(c, 7, Paint()..color = primary);
            canvas.drawCircle(
              c,
              7,
              Paint()
                ..color = Colors.white
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
            final handle = Offset(c.dx + rxScreen, c.dy);
            canvas.drawCircle(handle, 6, Paint()..color = primary);
            canvas.drawCircle(
              handle,
              6,
              Paint()
                ..color = Colors.white
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
          } else {
            canvas.drawCircle(c, 3.5, Paint()..color = Colors.white);
            canvas.drawCircle(
              c,
              3.5,
              Paint()
                ..color = Colors.black.withValues(alpha: 0.7)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1,
            );
          }

        case MaskKind.linear:
          if (l.maskParams.length < 4) continue;
          final p = l.maskParams;
          final s = t.toScreen(Offset(p[0], p[1]));
          final e = t.toScreen(Offset(p[2], p[3]));
          final mid = Offset((s.dx + e.dx) / 2, (s.dy + e.dy) / 2);

          // Vector line
          canvas.drawLine(
            s,
            e,
            Paint()
              ..color = selected ? primary : Colors.white
              ..strokeWidth = 2.0,
          );

          // Midpoint crossbar
          final angle = math.atan2(e.dy - s.dy, e.dx - s.dx);
          final perpAngle = angle + math.pi / 2;
          const barLen = 40.0;
          final p1 = Offset(
            mid.dx + math.cos(perpAngle) * barLen,
            mid.dy + math.sin(perpAngle) * barLen,
          );
          final p2 = Offset(
            mid.dx - math.cos(perpAngle) * barLen,
            mid.dy - math.sin(perpAngle) * barLen,
          );
          canvas.drawLine(
            p1,
            p2,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.8)
              ..strokeWidth = 1.5,
          );

          // Start & End handle pins
          canvas.drawCircle(s, selected ? 7 : 5, Paint()..color = primary);
          canvas.drawCircle(
            s,
            selected ? 7 : 5,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
          canvas.drawCircle(e, selected ? 7 : 5, Paint()..color = primary);
          canvas.drawCircle(
            e,
            selected ? 7 : 5,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
          // Midpoint grip: prominent drag pin
          canvas.drawCircle(mid, selected ? 7.0 : 5.0, Paint()..color = Colors.white);
          canvas.drawCircle(
            mid,
            selected ? 7.0 : 5.0,
            Paint()
              ..color = primary
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0,
          );
          if (selected) {
            canvas.drawCircle(mid, 3.0, Paint()..color = primary);
          }

        case MaskKind.brush:
          final p = l.maskParams;
          if (p.length >= 3) {
            final baseR = p[0] * t.fitted.width * t.scale;
            final count = p[2].toInt();
            if (count > 0 && p.length >= 3 + count * 3) {
              final pts = p.sublist(3, 3 + count * 3);
              final ruby = rubyColor.withValues(alpha: selected ? 0.35 : 0.20);
              final strokePaint = Paint()
                ..color = ruby
                ..style = PaintingStyle.stroke
                ..strokeCap = StrokeCap.round
                ..strokeJoin = StrokeJoin.round;

              for (var j = 0; j < pts.length; j += 3) {
                final x0 = pts[j];
                final y0 = pts[j + 1];
                final pr0 = pts[j + 2];
                if (x0 < 0 || y0 < 0) continue;
                final p0 = t.toScreen(Offset(x0, y0));

                if (j + 3 < pts.length && pts[j + 3] >= 0 && pts[j + 4] >= 0) {
                  final p1 = t.toScreen(Offset(pts[j + 3], pts[j + 4]));
                  final pr1 = pts[j + 5];
                  final pr = (pr0 + pr1) / 2;
                  strokePaint.strokeWidth = math.max(4.0, baseR * 2 * pr.clamp(0.2, 1.0));
                  canvas.drawLine(p0, p1, strokePaint);
                } else {
                  final effR = math.max(2.0, baseR * pr0.clamp(0.2, 1.0));
                  canvas.drawCircle(p0, effR, Paint()..color = ruby);
                }
              }

              // Draw prominent anchor pin at stroke start
              if (pts.length >= 2 && pts[0] >= 0 && pts[1] >= 0) {
                final origin = t.toScreen(Offset(pts[0], pts[1]));
                canvas.drawCircle(
                  origin,
                  selected ? 7 : 5,
                  Paint()..color = selected ? primary : Colors.white,
                );
                canvas.drawCircle(
                  origin,
                  selected ? 7 : 5,
                  Paint()
                    ..color = Colors.black.withValues(alpha: 0.7)
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.5,
                );
                if (selected) {
                  canvas.drawCircle(origin, 3, Paint()..color = Colors.white);
                }
              }
            }
          }

        case MaskKind.subject:
          if (l.maskParams.length >= 4) {
            final p = l.maskParams;
            final c = t.toScreen(Offset(p[0], p[1]));
            final rx = p[2] * t.fitted.width * t.scale;
            final ry = p[3] * t.fitted.height * t.scale;
            final rect = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
            canvas.drawOval(
              rect,
              Paint()..color = rubyColor.withValues(alpha: selected ? 0.25 : 0.15),
            );
            canvas.drawOval(
              rect,
              Paint()
                ..color = (selected ? primary : Colors.white).withValues(alpha: 0.8)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
            if (selected) {
              canvas.drawCircle(c, 7, Paint()..color = primary);
              canvas.drawCircle(
                c,
                7,
                Paint()
                  ..color = Colors.white
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.5,
              );
              final handle = Offset(c.dx + rx, c.dy);
              canvas.drawCircle(handle, 6, Paint()..color = primary);
              canvas.drawCircle(
                handle,
                6,
                Paint()
                  ..color = Colors.white
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.5,
              );
            }
          }

        case MaskKind.sky:
          if (l.maskParams.isNotEmpty) {
            final horizon = t.toScreen(Offset(0.5, l.maskParams[0])).dy;
            canvas.drawRect(
              Rect.fromLTRB(0, 0, size.width, horizon),
              Paint()..color = rubyColor.withValues(alpha: selected ? 0.25 : 0.15),
            );
            canvas.drawLine(
              Offset(0, horizon),
              Offset(size.width, horizon),
              Paint()
                ..color = (selected ? primary : Colors.white).withValues(alpha: 0.85)
                ..strokeWidth = 2.0,
            );
            if (selected) {
              final centerGrip = Offset(size.width / 2, horizon);
              canvas.drawRRect(
                RRect.fromRectAndRadius(
                  Rect.fromCenter(center: centerGrip, width: 36, height: 12),
                  const Radius.circular(6),
                ),
                Paint()..color = primary,
              );
              canvas.drawCircle(centerGrip, 3, Paint()..color = Colors.white);
            }
          }

        case MaskKind.luminance:
          break;

        case MaskKind.bitmap:
          final blob = l.maskBlob;
          if (selected && blob != null && l.maskParams.length >= 2) {
            final bw = l.maskParams[0].toInt();
            final bh = l.maskParams[1].toInt();
            if (bw > 0 && bh > 0 && blob.length >= bw * bh) {
              final stepX = (bw / 32).ceil().clamp(1, bw);
              final stepY = (bh / 32).ceil().clamp(1, bh);
              final cellW = (t.fitted.width * t.scale) / (bw / stepX);
              final cellH = (t.fitted.height * t.scale) / (bh / stepY);
              final tl = t.toScreen(Offset.zero);

              var yi = 0;
              for (var y = 0; y < bh; y += stepY, yi++) {
                var xi = 0;
                for (var x = 0; x < bw; x += stepX, xi++) {
                  var alpha = blob[y * bw + x] / 255.0;
                  if (l.inverted) alpha = 1.0 - alpha;
                  if (alpha > 0.05) {
                    final cellRect = Rect.fromLTWH(
                      tl.dx + xi * cellW,
                      tl.dy + yi * cellH,
                      cellW + 0.5,
                      cellH + 0.5,
                    );
                    canvas.drawRect(
                      cellRect,
                      Paint()
                        ..color = rubyColor.withValues(
                          alpha: (alpha * 0.30).clamp(0.0, 0.45),
                        ),
                    );
                  }
                }
              }
            }
          }
          break;
      }
    }

    // Paint live brush stroke in progress
    if (liveBrushPoints != null && liveBrushPoints!.length >= 3) {
      final baseR = (selectedIndex != null && selectedIndex! < layers.length)
          ? layers[selectedIndex!].brushRadius * t.fitted.width * t.scale
          : 20.0;
      final ruby = rubyColor.withValues(alpha: 0.45);
      final livePaint = Paint()
        ..color = ruby
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (liveBrushPoints!.length == 3) {
        final p0 = t.toScreen(Offset(liveBrushPoints![0], liveBrushPoints![1]));
        final pr = liveBrushPoints![2].clamp(0.2, 1.0);
        canvas.drawCircle(p0, math.max(2.0, baseR * pr), Paint()..color = ruby);
      } else {
        for (var j = 0; j < liveBrushPoints!.length - 3; j += 3) {
          final p0 = t.toScreen(Offset(liveBrushPoints![j], liveBrushPoints![j + 1]));
          final p1 = t.toScreen(Offset(liveBrushPoints![j + 3], liveBrushPoints![j + 4]));
          final pr = (liveBrushPoints![j + 2] + liveBrushPoints![j + 5]) / 2;
          livePaint.strokeWidth = math.max(4.0, baseR * 2 * pr.clamp(0.2, 1.0));
          canvas.drawLine(p0, p1, livePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_NodesPainter old) =>
      old.layers != layers ||
      old.selectedIndex != selectedIndex ||
      old.transform != transform ||
      old.primary != primary ||
      old.liveBrushPoints != liveBrushPoints ||
      old.pointerPos != pointerPos ||
      old.isEraser != isEraser;
}
