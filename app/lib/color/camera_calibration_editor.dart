import 'package:flutter/material.dart';

/// Camera Calibration panel allowing primary hue/sat and shadow tint adjustments.
class CameraCalibrationEditor extends StatelessWidget {
  const CameraCalibrationEditor({
    super.key,
    required this.shadowTint,
    required this.redHue,
    required this.redSat,
    required this.greenHue,
    required this.greenSat,
    required this.blueHue,
    required this.blueSat,
    required this.onChanged,
  });

  final double shadowTint;
  final double redHue;
  final double redSat;
  final double greenHue;
  final double greenSat;
  final double blueHue;
  final double blueSat;

  final void Function({
    double? shadowTint,
    double? redHue,
    double? redSat,
    double? greenHue,
    double? greenSat,
    double? blueHue,
    double? blueSat,
  }) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Camera Calibration', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton(
                key: const Key('reset-calibration-btn'),
                onPressed: () {
                  onChanged(
                    shadowTint: 0,
                    redHue: 0,
                    redSat: 0,
                    greenHue: 0,
                    greenSat: 0,
                    blueHue: 0,
                    blueSat: 0,
                  );
                },
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSectionHeader('Shadows', theme.colorScheme.onSurfaceVariant),
          _buildSlider(
            label: 'Tint',
            value: shadowTint,
            onChanged: (v) => onChanged(shadowTint: v),
          ),
          const Divider(height: 16),
          _buildSectionHeader('Red Primary', Colors.redAccent),
          _buildSlider(
            label: 'Hue',
            value: redHue,
            onChanged: (v) => onChanged(redHue: v),
          ),
          _buildSlider(
            label: 'Saturation',
            value: redSat,
            onChanged: (v) => onChanged(redSat: v),
          ),
          const Divider(height: 16),
          _buildSectionHeader('Green Primary', Colors.greenAccent),
          _buildSlider(
            label: 'Hue',
            value: greenHue,
            onChanged: (v) => onChanged(greenHue: v),
          ),
          _buildSlider(
            label: 'Saturation',
            value: greenSat,
            onChanged: (v) => onChanged(greenSat: v),
          ),
          const Divider(height: 16),
          _buildSectionHeader('Blue Primary', Colors.lightBlueAccent),
          _buildSlider(
            label: 'Hue',
            value: blueHue,
            onChanged: (v) => onChanged(blueHue: v),
          ),
          _buildSlider(
            label: 'Saturation',
            value: blueSat,
            onChanged: (v) => onChanged(blueSat: v),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: Slider(
            value: value.clamp(-100.0, 100.0),
            min: -100.0,
            max: 100.0,
            divisions: 200,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            value.round().toString(),
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}
