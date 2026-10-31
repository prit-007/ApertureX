import 'package:flutter/services.dart' show HapticFeedback;
import 'package:material_ui/material_ui.dart';

/// Standardized, responsive slider row shared by editor tools (Retouch, Masks, Optics, etc.).
/// Guarantees a fixed 75dp aligned label column, double-tap to reset to neutral/default,
/// tabular numerical readout, and zero overflow at 320dp viewport / 1.3 text scale.
class ParameterSliderRow extends StatelessWidget {
  const ParameterSliderRow({
    super.key,
    required this.label,
    required this.value,
    this.defaultValue = 0.0,
    required this.min,
    required this.max,
    required this.onChanged,
    this.displayValue,
    this.sliderKey,
    this.onReset,
    this.onTapValue,
    this.height = 38.0,
  });

  final String label;
  final double value;
  final double defaultValue;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String? displayValue;
  final Key? sliderKey;
  final VoidCallback? onReset;
  final VoidCallback? onTapValue;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final formattedText = displayValue ??
        (min >= 0 && max <= 1.0
            ? '${(value * 100).round()}%'
            : '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}');

    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            // 1. Fixed 75dp Label Column (fits 320x640 / 1.3 text scale cleanly)
            SizedBox(
              width: 75,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () {
                  HapticFeedback.selectionClick();
                  if (onReset != null) {
                    onReset!();
                  } else {
                    onChanged(defaultValue);
                  }
                },
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),

            // 2. Pro slider track
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  key: sliderKey,
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: (val) {
                    onChanged(val);
                  },
                ),
              ),
            ),

            // 3. Tabular numeric readout
            SizedBox(
              width: 44,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTapValue,
                onDoubleTap: () {
                  HapticFeedback.selectionClick();
                  if (onReset != null) {
                    onReset!();
                  } else {
                    onChanged(defaultValue);
                  }
                },
                child: Text(
                  formattedText,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
