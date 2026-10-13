import 'dart:math' as math;

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/recipe_mapping.dart';
import '../../gesture/gesture_interpreter.dart';

/// Index of the radial-menu item nearest [pointer], for a menu centred at
/// [center] with [count] items at [radius]. Item 0 sits at the top (−90°),
/// going clockwise. Pure — used by the shell and unit-tested.
int nearestRadialItem(Offset center, Offset pointer, int count, double radius) {
  var best = 0;
  var bestD = double.infinity;
  for (var i = 0; i < count; i++) {
    final angle = -math.pi / 2 + i * 2 * math.pi / count;
    final c = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    final d = (c - pointer).distanceSquared;
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return best;
}

/// Snapseed shell: the gesture FSM (swipe up/down = tool, left/right = scrub,
/// tap = reset) plus a **thumb-zone radial menu** — long-press anywhere blooms
/// an M3 radial tool menu under the thumb; drag to an icon to pick a tool
/// (ADR 0011). All writes go to the one [recipeControllerProvider].
class SnapseedShell extends ConsumerStatefulWidget {
  const SnapseedShell({super.key});

  @override
  ConsumerState<SnapseedShell> createState() => _SnapseedShellState();
}

class _SnapseedShellState extends ConsumerState<SnapseedShell> {
  static const double _radius = 84;

  late final GestureInterpreter _fsm;
  GradeTool _active = GradeTool.exposure;
  Offset? _radialCenter;
  int _radialHover = 0;

  Parameter get _parameter => snapseedToolParameters[_active]!.first;

  @override
  void initState() {
    super.initState();
    _fsm = GestureInterpreter(
      onToolChanged: (tool) => setState(() => _active = tool),
      onValueChanged: (tool, delta) {
        final parameter = snapseedToolParameters[tool]!.first;
        final spec = specOf(parameter);
        final previous = valueOf(
          ref.read(recipeControllerProvider).recipe,
          parameter,
        );
        ref.read(recipeControllerProvider.notifier).applyDelta(parameter, delta);
        final next = clampParameter(parameter, previous + delta * spec.scale);
        fireHaptic(hapticFor(previous, next, spec.min, spec.max));
      },
      onReset: (tool) => ref
          .read(recipeControllerProvider.notifier)
          .reset(snapseedToolParameters[tool]!.first),
    );
  }

  static IconData _icon(GradeTool tool) => switch (tool) {
    GradeTool.exposure => Icons.exposure,
    GradeTool.contrast => Icons.contrast,
    GradeTool.saturation => Icons.water_drop,
  };

  List<Offset> get _itemCenters {
    final center = _radialCenter ?? Offset.zero;
    final n = GradeTool.values.length;
    return [
      for (var i = 0; i < n; i++)
        center +
            Offset(
              math.cos(-math.pi / 2 + i * 2 * math.pi / n) * _radius,
              math.sin(-math.pi / 2 + i * 2 * math.pi / n) * _radius,
            ),
    ];
  }

  int _nearest(Offset p) =>
      nearestRadialItem(_radialCenter ?? Offset.zero, p, GradeTool.values.length, _radius);

  @override
  Widget build(BuildContext context) {
    final value = valueOf(
      ref.watch(recipeControllerProvider).recipe,
      _parameter,
    );
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => _fsm.onPanStart(d.localPosition),
              onPanUpdate: (d) => _fsm.onPanUpdate(d.delta),
              onPanEnd: (_) => _fsm.onPanEnd(),
              onLongPressStart: (d) => setState(() {
                _radialCenter = d.localPosition;
                _radialHover = 0;
                HapticFeedback.selectionClick();
              }),
              onLongPressMoveUpdate: (d) {
                final i = _nearest(d.localPosition);
                if (i != _radialHover) {
                  setState(() => _radialHover = i);
                  HapticFeedback.selectionClick();
                }
              },
              onLongPressEnd: (_) => setState(() {
                _active = GradeTool.values[_radialHover];
                _radialCenter = null;
              }),
              child: Container(
                height: 120,
                color: const Color(0xFF141414),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      specOf(_parameter).label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: scheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'swipe to scrub · long-press for the radial tool menu',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
        if (_radialCenter != null)
          for (var i = 0; i < GradeTool.values.length; i++)
            Positioned(
              left: _itemCenters[i].dx - 28,
              top: _itemCenters[i].dy - 28,
              child: Container(
                key: Key('radial-${GradeTool.values[i].name}'),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _radialHover
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                ),
                child: Icon(
                  _icon(GradeTool.values[i]),
                  color: i == _radialHover ? scheme.onPrimary : Colors.white70,
                ),
              ),
            ),
      ],
    );
  }
}
