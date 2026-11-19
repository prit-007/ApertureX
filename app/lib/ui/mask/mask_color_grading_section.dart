import 'package:material_ui/material_ui.dart';

import '../../edit/recipe_controller.dart';
import '../../l10n/app_strings.dart';
import '../common/color_grading_editor.dart';
import '../common/parameter_slider_row.dart';

class MaskSlider extends StatelessWidget {
  const MaskSlider({
    super.key,
    required this.label,
    required this.sliderKey,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.displayValue,
  });

  final String label;
  final Key sliderKey;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String? displayValue;

  @override
  Widget build(BuildContext context) {
    return ParameterSliderRow(
      label: label,
      sliderKey: sliderKey,
      value: value,
      defaultValue: 0.0,
      min: min,
      max: max,
      onChanged: onChanged,
      displayValue: displayValue,
    );
  }
}

class MaskColorGradingSection extends StatefulWidget {
  const MaskColorGradingSection({
    super.key,
    required this.segmentedKey,
    required this.hueKey,
    required this.satKey,
    required this.lumKey,
    required this.blendingKey,
    required this.balanceKey,
    required this.shadowHue,
    required this.shadowSat,
    required this.shadowLum,
    required this.midHue,
    required this.midSat,
    required this.midLum,
    required this.highlightHue,
    required this.highlightSat,
    required this.highlightLum,
    required this.blending,
    required this.balance,
    required this.onZoneChanged,
    required this.onGlobalChanged,
  });

  final Key segmentedKey;
  final Key hueKey;
  final Key satKey;
  final Key lumKey;
  final Key blendingKey;
  final Key balanceKey;
  final double shadowHue;
  final double shadowSat;
  final double shadowLum;
  final double midHue;
  final double midSat;
  final double midLum;
  final double highlightHue;
  final double highlightSat;
  final double highlightLum;
  final double blending;
  final double balance;
  final void Function(GradeWheelZone zone, {double? hue, double? sat, double? lum}) onZoneChanged;
  final void Function({double? blending, double? balance}) onGlobalChanged;

  @override
  State<MaskColorGradingSection> createState() => _MaskColorGradingSectionState();
}

class _MaskColorGradingSectionState extends State<MaskColorGradingSection> {
  GradeWheelZone _zone = GradeWheelZone.shadows;

  (double hue, double sat, double lum) get _currentZoneValues => switch (_zone) {
        GradeWheelZone.shadows => (widget.shadowHue, widget.shadowSat, widget.shadowLum),
        GradeWheelZone.midtones => (widget.midHue, widget.midSat, widget.midLum),
        GradeWheelZone.highlights => (widget.highlightHue, widget.highlightSat, widget.highlightLum),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (rawHue, sat, lum) = _currentZoneValues;
    final hue = (rawHue <= 1.0 && rawHue > 0) ? rawHue * 360.0 : rawHue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          'COLOR GRADING',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w700,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        SegmentedButton<GradeWheelZone>(
          key: widget.segmentedKey,
          segments: [
            ButtonSegment(
              value: GradeWheelZone.shadows,
              label: Text(AppStrings.of(context).maskShadows),
            ),
            ButtonSegment(
              value: GradeWheelZone.midtones,
              label: Text(AppStrings.of(context).maskMidtones),
            ),
            ButtonSegment(
              value: GradeWheelZone.highlights,
              label: Text(AppStrings.of(context).maskHighlights),
            ),
          ],
          selected: {_zone},
          onSelectionChanged: (selected) {
            setState(() => _zone = selected.first);
          },
        ),
        const SizedBox(height: 6),
        Center(
          child: ColorGradingWheel(
            hue: hue,
            saturation: sat,
            size: 140,
            onChanged: (newHue, newSat) {
              widget.onZoneChanged(_zone, hue: newHue, sat: newSat);
            },
            onChangeEnd: () {},
            onReset: () {
              widget.onZoneChanged(_zone, hue: 0.0, sat: 0.0);
            },
          ),
        ),
        MaskSlider(
          label: 'Hue',
          sliderKey: widget.hueKey,
          value: hue,
          min: 0.0,
          max: 360.0,
          displayValue: '${hue.round()}°',
          onChanged: (val) => widget.onZoneChanged(_zone, hue: val),
        ),
        MaskSlider(
          label: 'Sat',
          sliderKey: widget.satKey,
          value: sat,
          min: 0.0,
          max: 1.0,
          displayValue: '${(sat * 100).round()}%',
          onChanged: (val) => widget.onZoneChanged(_zone, sat: val),
        ),
        MaskSlider(
          label: 'Luminance',
          sliderKey: widget.lumKey,
          value: lum,
          min: -1.0,
          max: 1.0,
          onChanged: (val) => widget.onZoneChanged(_zone, lum: val),
        ),
        MaskSlider(
          label: 'Blending',
          sliderKey: widget.blendingKey,
          value: widget.blending,
          min: 0.0,
          max: 1.0,
          displayValue: '${(widget.blending * 100).round()}%',
          onChanged: (val) => widget.onGlobalChanged(blending: val),
        ),
        MaskSlider(
          label: 'Balance',
          sliderKey: widget.balanceKey,
          value: widget.balance,
          min: -1.0,
          max: 1.0,
          onChanged: (val) => widget.onGlobalChanged(balance: val),
        ),
      ],
    );
  }
}
