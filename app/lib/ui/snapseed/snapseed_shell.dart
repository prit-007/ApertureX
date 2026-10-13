import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/recipe_mapping.dart';
import '../../gesture/gesture_interpreter.dart';

/// Snapseed shell skeleton (P2 Slice C): the existing gesture FSM driving the
/// shared controller. Swipe up/down cycles tools, left/right scrubs, tap
/// resets — all writes go to the one [recipeControllerProvider].
class SnapseedShell extends ConsumerStatefulWidget {
  const SnapseedShell({super.key});

  @override
  ConsumerState<SnapseedShell> createState() => _SnapseedShellState();
}

class _SnapseedShellState extends ConsumerState<SnapseedShell> {
  late final GestureInterpreter _fsm;
  GradeTool _active = GradeTool.exposure;

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

  @override
  Widget build(BuildContext context) {
    final value = valueOf(
      ref.watch(recipeControllerProvider).recipe,
      _parameter,
    );

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _fsm.onPanStart(d.localPosition),
          onPanUpdate: (d) => _fsm.onPanUpdate(d.delta),
          onPanEnd: (_) => _fsm.onPanEnd(),
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
                    color: Theme.of(context).colorScheme.primary,
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
            'swipe up/down for tool · left/right to adjust · tap to reset',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
