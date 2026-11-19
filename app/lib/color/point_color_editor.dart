import 'package:flutter/material.dart';
import '../edit/recipe.dart';

/// Interactive editor for Point Color targets with range and shift controls.
class PointColorEditor extends StatefulWidget {
  const PointColorEditor({
    super.key,
    required this.pointColors,
    required this.onChanged,
  });

  final List<PointColorDef> pointColors;
  final ValueChanged<List<PointColorDef>> onChanged;

  @override
  State<PointColorEditor> createState() => _PointColorEditorState();
}

class _PointColorEditorState extends State<PointColorEditor> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = widget.pointColors;

    if (points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.colorize, size: 40, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'No Point Color Targets',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Select a precise color range to adjust hue, saturation, and luminance independently.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('add-point-color-btn'),
                onPressed: () {
                  widget.onChanged([
                    const PointColorDef(
                      targetHue: 0.05,
                      targetSat: 0.6,
                      targetLum: 0.5,
                      rangeHue: 0.1,
                      rangeSat: 0.3,
                      rangeLum: 0.3,
                      falloff: 0.5,
                    ),
                  ]);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Color Target'),
              ),
            ],
          ),
        ),
      );
    }

    final selected = _selectedIndex < points.length ? points[_selectedIndex] : points.first;
    final targetColor = HSLColor.fromAHSL(
      1.0,
      selected.targetHue * 360.0,
      selected.targetSat.clamp(0.0, 1.0),
      selected.targetLum.clamp(0.0, 1.0),
    ).toColor();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Color Targets', style: theme.textTheme.titleSmall),
              const Spacer(),
              IconButton(
                key: const Key('add-another-point-color-btn'),
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Add Target',
                onPressed: () {
                  final updated = List<PointColorDef>.from(points)
                    ..add(
                      PointColorDef(
                        targetHue: (selected.targetHue + 0.2) % 1.0,
                        targetSat: 0.6,
                        targetLum: 0.5,
                      ),
                    );
                  widget.onChanged(updated);
                  setState(() => _selectedIndex = updated.length - 1);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Swatches row
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: points.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final p = points[index];
                final col = HSLColor.fromAHSL(
                  1.0,
                  p.targetHue * 360.0,
                  p.targetSat.clamp(0.0, 1.0),
                  p.targetLum.clamp(0.0, 1.0),
                ).toColor();
                final isSelected = index == _selectedIndex;

                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? theme.colorScheme.primary : Colors.white24,
                        width: isSelected ? 3 : 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 24),
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: targetColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Target: ${(selected.targetHue * 360).round()}° H, ${(selected.targetSat * 100).round()}% S',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                key: const Key('delete-point-color-btn'),
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () {
                  final updated = List<PointColorDef>.from(points)..removeAt(_selectedIndex);
                  widget.onChanged(updated);
                  if (_selectedIndex >= updated.length && updated.isNotEmpty) {
                    setState(() => _selectedIndex = updated.length - 1);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSlider(
            label: 'Hue Shift',
            value: selected.hueShift,
            min: -1.0,
            max: 1.0,
            onChanged: (v) => _updateSelected(selected.copyWith(hueShift: v)),
          ),
          _buildSlider(
            label: 'Sat Shift',
            value: selected.satShift,
            min: -1.0,
            max: 1.0,
            onChanged: (v) => _updateSelected(selected.copyWith(satShift: v)),
          ),
          _buildSlider(
            label: 'Lum Shift',
            value: selected.lumShift,
            min: -1.0,
            max: 1.0,
            onChanged: (v) => _updateSelected(selected.copyWith(lumShift: v)),
          ),
          const SizedBox(height: 8),
          Text('Range & Falloff', style: theme.textTheme.labelMedium),
          _buildSlider(
            label: 'Hue Range',
            value: selected.rangeHue,
            min: 0.01,
            max: 0.5,
            onChanged: (v) => _updateSelected(selected.copyWith(rangeHue: v)),
          ),
          _buildSlider(
            label: 'Sat Range',
            value: selected.rangeSat,
            min: 0.01,
            max: 0.8,
            onChanged: (v) => _updateSelected(selected.copyWith(rangeSat: v)),
          ),
          _buildSlider(
            label: 'Lum Range',
            value: selected.rangeLum,
            min: 0.01,
            max: 0.8,
            onChanged: (v) => _updateSelected(selected.copyWith(rangeLum: v)),
          ),
          _buildSlider(
            label: 'Falloff',
            value: selected.falloff,
            min: 0.0,
            max: 1.0,
            onChanged: (v) => _updateSelected(selected.copyWith(falloff: v)),
          ),
        ],
      ),
    );
  }

  void _updateSelected(PointColorDef updated) {
    final list = List<PointColorDef>.from(widget.pointColors);
    list[_selectedIndex] = updated;
    widget.onChanged(list);
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 11, fontFeatures: []),
          ),
        ),
      ],
    );
  }
}
