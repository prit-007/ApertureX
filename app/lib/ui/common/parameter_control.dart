import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
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
    final spec = specOf(parameter);
    final value = valueOf(ref.watch(recipeControllerProvider).recipe, parameter);
    final notifier = ref.read(recipeControllerProvider.notifier);
    final math = SliderMath(spec);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (showLabel)
                Expanded(
                  child: Text(
                    spec.label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                const Spacer(),
              _ValueField(
                key: Key('param-value-${parameter.name}'),
                value: value,
                onType: (v) => notifier.update(parameter, v),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _Track(
            key: Key('param-track-${parameter.name}'),
            math: math,
            value: value,
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
  const _ValueField({super.key, required this.value, required this.onType});

  final double value;
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
    return TextButton(
      onPressed: () => _prompt(context),
      style: TextButton.styleFrom(
        minimumSize: const Size(56, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(
        _format(value),
        style: const TextStyle(
          color: Colors.white,
          fontFeatures: [FontFeature.tabularFigures()],
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
    required this.onChanged,
    required this.onReset,
  });

  final SliderMath math;
  final double value;
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
          child: SizedBox(
            height: 36,
            child: CustomPaint(
              size: Size(width, 36),
              painter: _TrackPainter(math: math, value: value),
            ),
          ),
        );
      },
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({required this.math, required this.value});

  final SliderMath math;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const trackH = 4.0;

    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width, cy),
      Paint()
        ..color = const Color(0xFF3A3A3A)
        ..strokeWidth = trackH
        ..strokeCap = StrokeCap.round,
    );

    // Neutral marker.
    final nx = math.neutralFraction * size.width;
    canvas.drawLine(
      Offset(nx, cy - 8),
      Offset(nx, cy + 8),
      Paint()
        ..color = const Color(0x33FFFFFF)
        ..strokeWidth = 1,
    );

    // Fill between neutral and the current value.
    final (start, end) = math.fillRange(value);
    canvas.drawLine(
      Offset(start * size.width, cy),
      Offset(end * size.width, cy),
      Paint()
        ..color = const Color(0xFFB0A0FF)
        ..strokeWidth = trackH
        ..strokeCap = StrokeCap.round,
    );

    // Thumb.
    canvas.drawCircle(
      Offset(math.fractionOf(value) * size.width, cy),
      9,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.value != value;
}
