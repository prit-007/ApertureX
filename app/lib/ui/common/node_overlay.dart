import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/adjustment_layer.dart';
import '../../edit/node_editor.dart';
import '../../edit/recipe_controller.dart';
import '../../viewport/canvas_transform.dart';
import '../../viewport/mask_peek.dart';

/// How an active pointer is interacting with a node.
enum _NodeDrag { idle, move, resize, place }

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
  bool _moved = false;
  int? _dragIndex;
  _NodeDrag _mode = _NodeDrag.idle;

  void _reset() {
    _down = null;
    _moved = false;
    _dragIndex = null;
    _mode = _NodeDrag.idle;
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
      onPointerDown: (e) => _onDown(e, transform, layers),
      onPointerMove: (e) => _onMove(e, transform, layers),
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
    _moved = false;
    final hit = _hitNode(t, layers, e.localPosition);
    if (hit == null) {
      _mode = _NodeDrag.place;
      _dragIndex = null;
    } else {
      _dragIndex = hit.$1;
      _mode = hit.$2;
      ref.read(nodeEditorProvider.notifier).select(hit.$1);
    }
  }

  void _onMove(PointerMoveEvent e, CanvasTransform t, List<AdjustmentLayer> layers) {
    if (_down == null || _dragIndex == null) return;
    if (_mode != _NodeDrag.move && _mode != _NodeDrag.resize) return;
    if ((e.localPosition - _down!).distance > _slop) _moved = true;
    if (!_moved) return;

    final index = _dragIndex!;
    if (index >= layers.length) {
      _reset();
      return;
    }
    final layer = layers[index];
    if (layer.maskKind != MaskKind.radial || layer.maskParams.length < 5) {
      _reset();
      return;
    }
    final p = layer.maskParams;
    final List<double> params;
    switch (_mode) {
      case _NodeDrag.move:
        final n = t.toNormalized(e.localPosition);
        if (n == null) return;
        params = [
          n.dx.clamp(0.0, 1.0),
          n.dy.clamp(0.0, 1.0),
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
        // Scale the ellipse so its ring passes through the pointer, keeping
        // the aspect (the shape) and clamping to sane bounds.
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

  /// Topmost node under [p]: returns its recipe index and how a drag from
  /// there should behave (centre/body → move, ring → resize).
  (int, _NodeDrag)? _hitNode(
    CanvasTransform t,
    List<AdjustmentLayer> layers,
    Offset p,
  ) {
    for (var i = layers.length - 1; i >= 0; i--) {
      final l = layers[i];
      if (l.maskKind != MaskKind.radial || l.maskParams.length < 5) continue;
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
    }
    return null;
  }
}

/// Paints the control points: a contrast ring (+ feather-soft body and drag
/// handles for the selected node), matching the mask's `d = 1` boundary.
class _NodesPainter extends CustomPainter {
  const _NodesPainter({
    required this.layers,
    required this.selectedIndex,
    required this.transform,
    required this.primary,
  });

  final List<AdjustmentLayer> layers;
  final int? selectedIndex;
  final CanvasTransform? transform;
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    final t = transform;
    if (t == null) return;
    for (var i = 0; i < layers.length; i++) {
      final l = layers[i];
      if (l.maskKind != MaskKind.radial || l.maskParams.length < 5) continue;
      final p = l.maskParams;
      final rxScreen = p[2] * t.fitted.width * t.scale;
      final ryScreen = p[3] * t.fitted.height * t.scale;
      if (rxScreen <= 0 || ryScreen <= 0) continue;
      final c = t.toScreen(Offset(p[0], p[1]));
      final rect = Rect.fromCenter(center: c, width: rxScreen * 2, height: ryScreen * 2);
      final selected = i == selectedIndex;

      if (selected) {
        canvas.drawOval(
          rect,
          Paint()..color = primary.withValues(alpha: 0.10),
        );
      }
      // Contrast: a dark halo under a light (or primary) ring so the node
      // stays visible over any part of the photo.
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
        // Centre drag handle.
        canvas.drawCircle(c, 7, Paint()..color = primary);
        canvas.drawCircle(
          c,
          7,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        // Resize handle at the ring's right edge (3 o'clock).
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
    }
  }

  @override
  bool shouldRepaint(_NodesPainter old) =>
      old.layers != layers ||
      old.selectedIndex != selectedIndex ||
      old.transform != transform ||
      old.primary != primary;
}
