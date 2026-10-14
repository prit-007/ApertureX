import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/theme/design_tokens.dart';
import '../../edit/muted_parameters.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
import '../edit_activity.dart';
import 'slider_math.dart';

/// The single parameter control shared by **both** shells (P2 Slice B) — the
/// shells must never fork it. Reads/writes the one [recipeControllerProvider].
///
/// Lightroom mechanics: bidirectional vs unidirectional center-fill track,
/// double-tap to reset, tap the value to type an exact number.
class ParameterControl extends ConsumerWidget {
  const ParameterControl({
    super.key,
    required this.parameter,
    this.showLabel = true,
  });

  final Parameter parameter;
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spec = specOf(parameter);
    final value = valueOf(ref.watch(recipeControllerProvider).recipe, parameter);
    final notifier = ref.read(recipeControllerProvider.notifier);
    final math = SliderMath(spec);
    final isNeutral = value == spec.neutral;
    final muted = ref.watch(
      mutedParametersProvider.select((s) => s.contains(parameter)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (showLabel)
                Expanded(
                  child: GestureDetector(
                    key: Key('param-label-${parameter.name}'),
                    behavior: HitTestBehavior.opaque,
                    onLongPress: () => ref
                        .read(mutedParametersProvider.notifier)
                        .toggle(parameter),
                    onDoubleTap: () => ref
                        .read(mutedParametersProvider.notifier)
                        .toggle(parameter),
                    child: Semantics(
                      button: true,
                      excludeSemantics: true,
                      label: muted
                          ? '${spec.label}, muted. Double-tap to unmute'
                          : '${spec.label}. Long-press or double-tap to mute',
                      child: Text(
                        spec.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted
                              ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          decoration: muted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              _ValueField(
                key: Key('param-value-${parameter.name}'),
                value: value,
                isNeutral: isNeutral,
                onType: (v) => notifier.update(parameter, v),
              ),
            ],
          ),
          _Track(
            key: Key('param-track-${parameter.name}'),
            math: math,
            value: value,
            scheme: scheme,
            onChanged: (v) {
              final previous = valueOf(
                ref.read(recipeControllerProvider).recipe,
                parameter,
              );
              notifier.update(parameter, v);
              fireHaptic(
                hapticFor(
                  previous,
                  clampParameter(parameter, v),
                  spec.min,
                  spec.max,
                ),
              );
            },
            onReset: () => notifier.reset(parameter),
            onCommit: () => notifier.commit(label: spec.label),
          ),
        ],
      ),
    );
  }
}

String _format(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}';

/// Tappable numeric readout → type an exact value.
class _ValueField extends StatelessWidget {
  const _ValueField({
    super.key,
    required this.value,
    required this.isNeutral,
    required this.onType,
  });

  final double value;
  final bool isNeutral;
  final ValueChanged<double> onType;

  Future<void> _prompt(BuildContext context) async {
    final controller = TextEditingController(text: value.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set value'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            signed: true,
            decimal: true,
          ),
          onSubmitted: (t) => Navigator.of(context).pop(double.tryParse(t)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(double.tryParse(controller.text)),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (result != null) onType(result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: () => _prompt(context),
      style: TextButton.styleFrom(
        minimumSize: const Size(56, 32),
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
        foregroundColor: isNeutral ? scheme.onSurfaceVariant : scheme.primary,
      ),
      child: Text(
        _format(value),
        style: const TextStyle(
          fontFeatures: [FontFeature.tabularFigures()],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Custom center-fill track with pro micro-interactions: relative drag for
/// precision, tap beside the thumb to nudge by 5% of the range, double-tap to
/// reset, and a commit to history when the drag ends.
class _Track extends ConsumerStatefulWidget {
  const _Track({
    super.key,
    required this.math,
    required this.value,
    required this.scheme,
    required this.onChanged,
    required this.onReset,
    required this.onCommit,
  });

  final SliderMath math;
  final double value;
  final ColorScheme scheme;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;
  final VoidCallback onCommit;

  @override
  ConsumerState<_Track> createState() => _TrackState();
}

class _TrackState extends ConsumerState<_Track> {
  double _dragValue = 0;
  final Stopwatch _sw = Stopwatch()..start();
  final HapticGradientPacer _gradient = HapticGradientPacer();

  void _nudge(double direction) {
    final step = widget.math.span * 0.05;
    widget.onChanged(widget.value + direction * step);
    widget.onCommit();
  }

  void _pulse() {
    final spec = widget.math.spec;
    final elapsed = _sw.elapsed;
    _sw.reset();
    if (_gradient.tick(elapsed, value: _dragValue, min: spec.min, max: spec.max)) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.math.spec;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: widget.onReset,
          onTapUp: (d) {
            final thumb = widget.math.fractionOf(widget.value) * width;
            _nudge(d.localPosition.dx < thumb ? -1 : 1);
          },
          onHorizontalDragStart: (_) {
            _dragValue = widget.value;
            _gradient.reset();
            _sw
              ..reset()
              ..start();
            ref.read(editActivityProvider.notifier).begin();
          },
          onHorizontalDragUpdate: (d) {
            _dragValue = (_dragValue + d.delta.dx / width * widget.math.span)
                .clamp(spec.min, spec.max);
            widget.onChanged(_dragValue);
            _pulse();
          },
          onHorizontalDragEnd: (_) {
            widget.onCommit();
            ref.read(editActivityProvider.notifier).end();
          },
          onHorizontalDragCancel: () =>
              ref.read(editActivityProvider.notifier).end(),
          child: Semantics(
            slider: true,
            label: '${spec.label} value',
            value: _format(widget.value),
            child: SizedBox(
              height: 36,
              child: CustomPaint(
                size: Size(width, 36),
                painter: _TrackPainter(
                  math: widget.math,
                  value: widget.value,
                  scheme: widget.scheme,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({required this.math, required this.value, required this.scheme});

  final SliderMath math;
  final double value;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const trackH = 4.0;

    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width, cy),
      Paint()
        ..color = scheme.onSurface.withValues(alpha: 0.20)
        ..strokeWidth = trackH
        ..strokeCap = StrokeCap.round,
    );

    // Neutral marker.
    final nx = math.neutralFraction * size.width;
    canvas.drawLine(
      Offset(nx, cy - 8),
      Offset(nx, cy + 8),
      Paint()
        ..color = scheme.onSurfaceVariant.withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );

    // Fill between neutral and the current value.
    final (start, end) = math.fillRange(value);
    canvas.drawLine(
      Offset(start * size.width, cy),
      Offset(end * size.width, cy),
      Paint()
        ..color = scheme.primary
        ..strokeWidth = trackH
        ..strokeCap = StrokeCap.round,
    );

    // Thumb.
    canvas.drawCircle(
      Offset(math.fractionOf(value) * size.width, cy),
      9,
      Paint()..color = scheme.primary,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.value != value || old.scheme != scheme;
}
