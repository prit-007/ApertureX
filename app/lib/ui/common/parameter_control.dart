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
import '../precision_gear.dart';
import 'rotary_jog_dial.dart';
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
    final value = ref.watch(
      recipeControllerProvider.select((s) => valueOf(s.recipe, parameter)),
    );
    final notifier = ref.read(recipeControllerProvider.notifier);
    final math = SliderMath(spec);
    final isNeutral = value == spec.neutral;
    final muted = ref.watch(
      mutedParametersProvider.select((s) => s.contains(parameter)),
    );
    // Precision gear (#71): while two fingers are on screen every readout
    // gains a decimal and the track shows its fine-mode badge.
    final precise = ref.watch(precisionGearProvider.select(precisionEngaged));

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
                precise: precise,
                onType: (v) => notifier.update(parameter, v),
              ),
              IconButton(
                key: Key('param-jog-dial-${parameter.name}'),
                tooltip: 'Jog Dial (${spec.label})',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  showRotaryJogDial(context, parameter: parameter);
                },
                icon: Icon(
                  Icons.album_outlined,
                  size: 16,
                  color: isNeutral ? scheme.onSurfaceVariant : scheme.primary,
                ),
              ),
              if (precise)
                Padding(
                  padding: const EdgeInsets.only(left: Insets.xs),
                  child: Semantics(
                    label: 'Precision gear engaged',
                    excludeSemantics: true,
                    child: Icon(
                      Icons.zoom_in,
                      key: Key('param-precision-${parameter.name}'),
                      size: 18,
                      color: scheme.primary,
                    ),
                  ),
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
            precise: precise,
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

/// [decimals] rises to 3 while the precision gear (#71) is engaged so the
/// fine scrub shows its extra digit.
String _format(double v, {int decimals = 2}) =>
    '${v >= 0 ? '+' : ''}${v.toStringAsFixed(decimals)}';

/// Tappable numeric readout → type an exact value.
class _ValueField extends StatelessWidget {
  const _ValueField({
    super.key,
    required this.value,
    required this.isNeutral,
    required this.muted,
    required this.precise,
    required this.onType,
  });

  final double value;
  final bool isNeutral;
  final bool muted;
  final bool precise;
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
        backgroundColor: isNeutral
            ? null
            : scheme.primaryContainer.withValues(alpha: 0.28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        foregroundColor: isNeutral ? scheme.onSurfaceVariant : scheme.primary,
      ),
      child: Opacity(
        opacity: muted ? 0.3 : 1.0,
        child: Text(
          _format(value, decimals: precise ? 3 : 2),
          style: TextStyle(
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: isNeutral ? FontWeight.w600 : FontWeight.w700,
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
    required this.precise,
    required this.onChanged,
    required this.onReset,
    required this.onCommit,
  });

  final Parameter parameter;
  final SliderMath math;
  final double value;
  final ColorScheme scheme;
  final bool muted;
  final bool precise;
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

  /// True while this track holds the [activeTrackProvider] lease. A rejected
  /// drag start (another track is already scrubbing) sets [_rejected] instead
  /// so its updates/end can be ignored without unbalancing edit-activity.
  bool _dragging = false;
  bool _rejected = false;

  /// Whether the press currently resolving on this track was made under the
  /// precision gear (issue #71). Refreshed at pointer-down and raised by an
  /// engage transition, so it is correct no matter which finger lands first
  /// (order-independent); a resting second finger must never turn its lift
  /// into a 5% tap nudge.
  bool _pressSawPrecision = false;

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
    // Gear engage transition (#71): announce once — only the track that is
    // actually scrubbing ticks, so a second finger landing anywhere feels
    // like one click — and raise nudge suppression on every track so a
    // resting finger's lift never counts as a tap.
    ref.listen(precisionGearProvider, (previous, next) {
      if (!precisionEngaged(next) || precisionEngaged(previous ?? 0)) return;
      _pressSawPrecision = true;
      if (_dragging) HapticFeedback.selectionClick();
    });
    return Listener(
      // Refreshed at down (before the gear can see this pointer): the press
      // either starts under an already-engaged gear or never does.
      onPointerDown: (_) {
        _pressSawPrecision = precisionEngaged(
          ref.read(precisionGearProvider),
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: widget.onReset,
            onTapUp: (d) {
              // Precision mode: a tap beside the thumb must not jump the
              // value while the other hand is holding the screen (#71).
              if (_pressSawPrecision ||
                  precisionEngaged(ref.read(precisionGearProvider))) {
                return;
              }
              final thumb = widget.math.fractionOf(widget.value) * width;
              _nudge(d.localPosition.dx < thumb ? -1 : 1);
            },
            onHorizontalDragStart: (_) {
              // Single-scrub lease: only one track may be dragging at a
              // time, or a second finger doubles two values at once (#71).
              if (!ref
                  .read(activeTrackProvider.notifier)
                  .claim(widget.parameter)) {
                _rejected = true;
                return;
              }
              _rejected = false;
              setState(() => _dragging = true);
              _dragValue = widget.value;
              _gradient.reset();
              _sw
                ..reset()
                ..start();
              ref.read(editActivityProvider.notifier).begin();
              // Detail sliders auto-peek their mask view while held (#27),
              // but only when Ruby Peeks is enabled.
              if (maskPeekParameters.contains(widget.parameter) &&
                  ref.read(rubyPeeksEnabledProvider)) {
                ref.read(maskPeekProvider.notifier).set(true);
              }
            },
            onHorizontalDragUpdate: (d) {
              if (_rejected) return;
              // Precision gear (#71): engaged fingers divide the scrub so
              // long drags land on exact numbers instead of overshooting.
              final isPrecision =
                  precisionEngaged(ref.read(precisionGearProvider));
              final scale = isPrecision ? 1 / kPrecisionDivisor : 1.0;
              final nextRaw = (_dragValue +
                      d.delta.dx / width * widget.math.span * scale)
                  .clamp(spec.min, spec.max);
              _dragValue = nextRaw;

              // Pro tactile magnetic detent: snap cleanly to neutral if within micro threshold,
              // but never during precision gear mode where exact micro-adjustments are required.
              final span = widget.math.span;
              final snapThreshold = isPrecision ? 0.0 : span * 0.004;
              final effective = snapThreshold > 0 &&
                      (nextRaw - spec.neutral).abs() < snapThreshold
                  ? spec.neutral
                  : nextRaw;

              widget.onChanged(effective);
              _pulse();
            },
            onHorizontalDragEnd: (_) {
              if (_rejected) {
                _rejected = false;
                return;
              }
              setState(() => _dragging = false);
              widget.onCommit();
              ref.read(editActivityProvider.notifier).end();
              ref.read(maskPeekProvider.notifier).set(false);
              ref.read(activeTrackProvider.notifier).release(
                widget.parameter,
              );
            },
            onHorizontalDragCancel: () {
              if (_rejected) {
                _rejected = false;
                return;
              }
              setState(() => _dragging = false);
              ref.read(editActivityProvider.notifier).end();
              ref.read(maskPeekProvider.notifier).set(false);
              ref.read(activeTrackProvider.notifier).release(
                widget.parameter,
              );
            },
            child: Semantics(
              slider: true,
              label: '${spec.label} value',
              value: _format(widget.value, decimals: widget.precise ? 3 : 2),
              child: SizedBox(
                height: 36,
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(width, 36),
                    painter: _TrackPainter(
                      math: widget.math,
                      value: widget.value,
                      scheme: widget.scheme,
                      muted: widget.muted,
                      isDragging: _dragging,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.math,
    required this.value,
    required this.scheme,
    required this.muted,
    this.isDragging = false,
  });

  final SliderMath math;
  final double value;
  final ColorScheme scheme;

  /// A muted (bypassed) parameter paints its fill in the surface colour so
  /// the track reads as inactive without looking deleted.
  final bool muted;
  final bool isDragging;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const trackH = 4.0;

    // Background track rail
    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width, cy),
      Paint()
        ..color = scheme.onSurface.withValues(alpha: 0.16)
        ..strokeWidth = trackH
        ..strokeCap = StrokeCap.round,
    );

    // Neutral graduation notch
    final nx = math.neutralFraction * size.width;
    canvas.drawLine(
      Offset(nx, cy - 7),
      Offset(nx, cy + 7),
      Paint()
        ..color = scheme.onSurfaceVariant.withValues(alpha: 0.55)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );

    // Active fill between neutral and the current value (dimmed while muted)
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

    // Thumb position & dimensions
    final thumbX = math.fractionOf(value) * size.width;
    final thumbRadius = isDragging ? 10.0 : 8.5;

    // Touch feedback glow halo while scrubbing
    if (isDragging && !muted) {
      canvas.drawCircle(
        Offset(thumbX, cy),
        17.0,
        Paint()..color = accent.withValues(alpha: 0.22),
      );
    }

    // Drop shadow under thumb for pop
    canvas.drawCircle(
      Offset(thumbX, cy + 1.2),
      thumbRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // Outer thumb body
    canvas.drawCircle(
      Offset(thumbX, cy),
      thumbRadius,
      Paint()..color = accent,
    );

    // Crisp highlight ring
    canvas.drawCircle(
      Offset(thumbX, cy),
      thumbRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Inner indicator dot if modified
    if (value != math.spec.neutral && !muted) {
      canvas.drawCircle(
        Offset(thumbX, cy),
        2.5,
        Paint()..color = scheme.onPrimary,
      );
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.value != value ||
      old.scheme != scheme ||
      old.muted != muted ||
      old.isDragging != isDragging;
}
