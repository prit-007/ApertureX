import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../color/histogram_view.dart';
import '../../edit/recipe.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/tone_curve.dart';
import '../../engine/engine.dart' show Histogram;

/// A Lightroom-style tone-curve editor (P2): pick a channel, tap to add a
/// control point, drag to shape it, double-tap an interior point to remove it.
/// The curve writes straight to the shared recipe; the live histogram sits
/// behind it.
class ToneCurveEditor extends ConsumerStatefulWidget {
  const ToneCurveEditor({super.key});

  @override
  ConsumerState<ToneCurveEditor> createState() => _ToneCurveEditorState();
}

class _ToneCurveEditorState extends ConsumerState<ToneCurveEditor> {
  ToneCurveChannel _channel = ToneCurveChannel.master;
  int? _active;

  ToneCurve _curveOf(EditRecipe recipe) => switch (_channel) {
    ToneCurveChannel.master => recipe.masterCurve,
    ToneCurveChannel.red => recipe.redCurve,
    ToneCurveChannel.green => recipe.greenCurve,
    ToneCurveChannel.blue => recipe.blueCurve,
  };

  static List<Offset> _toPoints(ToneCurve curve) => [
    for (var i = 0; i + 1 < curve.points.length; i += 2)
      Offset(curve.points[i], curve.points[i + 1]),
  ];

  static ToneCurve _fromPoints(List<Offset> pts) {
    final flat = <double>[];
    for (final p in pts) {
      flat
        ..add(p.dx)
        ..add(p.dy);
    }
    return ToneCurve(flat);
  }

  Offset _toValue(Offset local, double side) => Offset(
    (local.dx / side).clamp(0.0, 1.0),
    (1.0 - local.dy / side).clamp(0.0, 1.0),
  );

  void _selectOrAdd(Offset value, List<Offset> pts) {
    var best = -1;
    var bestD = 0.09;
    for (var i = 0; i < pts.length; i++) {
      final d = (pts[i] - value).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    if (best >= 0) {
      _active = best;
      return;
    }
    pts
      ..add(value)
      ..sort((a, b) => a.dx.compareTo(b.dx));
    _active = pts.indexOf(value);
  }

  void _move(Offset value, List<Offset> pts) {
    final i = _active;
    if (i == null || i < 0 || i >= pts.length) return;
    final lo = i == 0 ? 0.0 : pts[i - 1].dx + 0.01;
    final hi = i == pts.length - 1 ? 1.0 : pts[i + 1].dx - 0.01;
    pts[i] = Offset(value.dx.clamp(lo, hi), value.dy);
  }

  void _removeNearest(Offset value, List<Offset> pts) {
    if (pts.length <= 2) return;
    var best = -1;
    var bestD = 0.09;
    for (var i = 1; i < pts.length - 1; i++) {
      final d = (pts[i] - value).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    if (best > 0) pts.removeAt(best);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final curve = _curveOf(recipe);
    final histogram = ref.watch(histogramProvider);
    final notifier = ref.read(recipeControllerProvider.notifier);

    void apply(void Function(List<Offset>) change) {
      final pts = _toPoints(_curveOf(ref.read(recipeControllerProvider).recipe));
      change(pts);
      notifier.setCurve(_channel, _fromPoints(pts));
    }

    return Column(
      children: [
        Row(
          children: [
            for (final channel in ToneCurveChannel.values)
              TextButton(
                onPressed: () => setState(() {
                  _channel = channel;
                  _active = null;
                }),
                child: Text(
                  channel.name.toUpperCase(),
                  style: TextStyle(
                    color: channel == _channel
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                    fontSize: 12,
                    letterSpacing: 1.0,
                    fontWeight: channel == _channel
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = constraints.biggest.shortestSide;
                return Center(
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => apply(
                        (pts) =>
                            _selectOrAdd(_toValue(d.localPosition, side), pts),
                      ),
                      onPanStart: (d) => apply(
                        (pts) =>
                            _selectOrAdd(_toValue(d.localPosition, side), pts),
                      ),
                      onPanUpdate: (d) => apply(
                        (pts) => _move(_toValue(d.localPosition, side), pts),
                      ),
                      onPanEnd: (_) {
                        notifier.commit();
                        setState(() => _active = null);
                      },
                      onDoubleTapDown: (d) => apply(
                        (pts) => _removeNearest(
                          _toValue(d.localPosition, side),
                          pts,
                        ),
                      ),
                      child: CustomPaint(
                        painter: _CurvePainter(
                          points: _toPoints(curve),
                          histogram: histogram,
                          scheme: scheme,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.points,
    required this.histogram,
    required this.scheme,
  });

  final List<Offset> points;
  final Histogram? histogram;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = scheme.surfaceContainerLowest,
    );

    // Histogram luma backdrop.
    final hist = histogram;
    if (hist != null) {
      final n = hist.luma.length;
      var maxBin = 1;
      for (var i = 1; i < n - 1; i++) {
        if (hist.luma[i] > maxBin) maxBin = hist.luma[i];
      }
      final path = Path()..moveTo(0, side);
      for (var i = 0; i < n; i++) {
        final x = i / (n - 1) * side;
        final h = (hist.luma[i] / maxBin).clamp(0.0, 1.0) * side;
        path.lineTo(x, side - h);
      }
      path
        ..lineTo(side, side)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = scheme.onSurface.withValues(alpha: 0.13),
      );
    }

    // Diagonal reference.
    canvas.drawLine(
      Offset(0, side),
      Offset(side, 0),
      Paint()
        ..color = scheme.onSurface.withValues(alpha: 0.13)
        ..strokeWidth = 1,
    );

    // Curve (straight segments between control points; Rust bakes the smooth
    // monotone-cubic curve on the GPU/LUT).
    final curve = Path();
    for (var i = 0; i < points.length; i++) {
      final s = Offset(points[i].dx * side, (1 - points[i].dy) * side);
      if (i == 0) {
        curve.moveTo(s.dx, s.dy);
      } else {
        curve.lineTo(s.dx, s.dy);
      }
    }
    canvas.drawPath(
      curve,
      Paint()
        ..color = scheme.primary
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // Control points.
    for (final p in points) {
      canvas.drawCircle(
        Offset(p.dx * side, (1 - p.dy) * side),
        5,
        Paint()..color = scheme.onSurface,
      );
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.histogram != histogram ||
      old.scheme != scheme ||
      !_samePoints(old.points, points);

  static bool _samePoints(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
