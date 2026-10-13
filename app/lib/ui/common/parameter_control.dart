import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/theme/design_tokens.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
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
                  child: Text(
                    spec.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
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

/// Custom center-fill track: drag to scrub, double-tap to reset.
class _Track extends StatelessWidget {
  const _Track({
    super.key,
    required this.math,
    required this.value,
    required this.scheme,
    required this.onChanged,
    required this.onReset,
  });

  final SliderMath math;
  final double value;
  final ColorScheme scheme;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void jumpTo(double dx) =>
            onChanged(math.valueAt((dx / width).clamp(0.0, 1.0)));

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => jumpTo(d.localPosition.dx),
          onDoubleTap: onReset,
          onHorizontalDragUpdate: (d) => jumpTo(d.localPosition.dx),
          child: Semantics(
            slider: true,
            label: '${math.spec.label} value',
            value: _format(value),
            child: SizedBox(
              height: 36,
              child: CustomPaint(
                size: Size(width, 36),
                painter: _TrackPainter(math: math, value: value, scheme: scheme),
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
        ..color = scheme.surfaceContainerHighest
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
