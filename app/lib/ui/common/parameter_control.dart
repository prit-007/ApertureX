import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/theme/design_tokens.dart';
import '../../edit/muted_parameters.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
import '../../viewport/mask_peek.dart';
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
                      child: Opacity(
                        // Bypassed, not deleted: dim instead of striking
                        // through (pro audio/video mute semantics).
                        opacity: muted ? 0.3 : 1.0,
                        child: Text(
                          spec.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
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
                muted: muted,
                onType: (v) => notifier.update(parameter, v),
              ),
            ],
          ),
          _Track(
            key: Key('param-track-${parameter.name}'),
            parameter: parameter,
            math: math,
            value: value,
            scheme: scheme,
            muted: muted,
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
    required this.muted,
    required this.onType,
  });

  final double value;
  final bool isNeutral;
  final bool muted;
  final ValueChanged<double> onType;

  /// Bottom-sheet numeric entry (thumb zone, not a centred dialog). The
  /// existing number is **selected** so the first keystroke replaces it.
  Future<void> _prompt(BuildContext context) async {
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ValueSheet(initial: value.toStringAsFixed(2)),
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
      child: Opacity(
        opacity: muted ? 0.3 : 1.0,
        child: Text(
          _format(value),
          style: const TextStyle(
            fontFeatures: [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// The sheet body: owns its [TextEditingController] so it is disposed with
/// the route element (after the exit animation), never under the field.
class _ValueSheet extends StatefulWidget {
  const _ValueSheet({required this.initial});

  final String initial;

  @override
  State<_ValueSheet> createState() => _ValueSheetState();
}

class _ValueSheetState extends State<_ValueSheet> {
  late final TextEditingController _controller;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initial.length,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pop(double? value) {
    if (_popped || !mounted) return;
    _popped = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: Insets.sheet,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Set value', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              onSubmitted: (t) => _pop(double.tryParse(t)),
            ),
            const SizedBox(height: Insets.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _pop(null),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: Insets.sm),
                FilledButton(
                  onPressed: () => _pop(double.tryParse(_controller.text)),
                  child: const Text('Set'),
                ),
              ],
            ),
          ],
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
    required this.parameter,
    required this.math,
    required this.value,
    required this.scheme,
    required this.muted,
    required this.onChanged,
    required this.onReset,
    required this.onCommit,
  });

  final Parameter parameter;
  final SliderMath math;
  final double value;
  final ColorScheme scheme;
  final bool muted;
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
            // Detail sliders auto-peek their mask view while held (#27).
            if (maskPeekParameters.contains(widget.parameter)) {
              ref.read(maskPeekProvider.notifier).set(true);
            }
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
            ref.read(maskPeekProvider.notifier).set(false);
          },
          onHorizontalDragCancel: () {
            ref.read(editActivityProvider.notifier).end();
            ref.read(maskPeekProvider.notifier).set(false);
          },
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
                  muted: widget.muted,
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
  _TrackPainter({
    required this.math,
    required this.value,
    required this.scheme,
    required this.muted,
  });

  final SliderMath math;
  final double value;
  final ColorScheme scheme;

  /// A muted (bypassed) parameter paints its fill in the surface colour so
  /// the track reads as inactive without looking deleted.
  final bool muted;

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

    // Fill between neutral and the current value (dimmed while muted).
    final accent = muted ? scheme.surfaceContainerHighest : scheme.primary;
    final (start, end) = math.fillRange(value);
    canvas.drawLine(
      Offset(start * size.width, cy),
      Offset(end * size.width, cy),
      Paint()
        ..color = accent
        ..strokeWidth = trackH
        ..strokeCap = StrokeCap.round,
    );

    // Thumb.
    canvas.drawCircle(
      Offset(math.fractionOf(value) * size.width, cy),
      9,
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.value != value || old.scheme != scheme || old.muted != muted;
}
