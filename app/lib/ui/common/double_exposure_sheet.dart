import 'package:flutter/material.dart';
import '../../edit/recipe.dart';

/// Bottom sheet for configuring Double Exposure blending.
class DoubleExposureSheet extends StatelessWidget {
  const DoubleExposureSheet({
    super.key,
    required this.layer,
    required this.onChanged,
    required this.onPickImage,
  });

  final DoubleExposureLayer? layer;
  final ValueChanged<DoubleExposureLayer?> onChanged;
  final VoidCallback onPickImage;

  static const List<String> blendModeNames = [
    'Normal',
    'Screen',
    'Multiply',
    'Overlay',
    'Lighten',
    'Darken',
    'Add',
    'Subtract',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = layer;

    if (current == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Double Exposure', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Blend a secondary image using Screen, Multiply, Overlay, or Lighten.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('choose-double-exposure-btn'),
              onPressed: () {
                onChanged(
                  const DoubleExposureLayer(
                    blendModeIndex: 1, // Screen
                    opacity: 0.6,
                  ),
                );
                onPickImage();
              },
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Choose Overlay Image'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Double Exposure', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton(
                key: const Key('remove-double-exposure-btn'),
                onPressed: () => onChanged(null),
                child: const Text('Remove Layer'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Blend Mode', style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: blendModeNames.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final isSelected = current.blendModeIndex == idx;
                return ChoiceChip(
                  label: Text(blendModeNames[idx]),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      onChanged(current.copyWith(blendModeIndex: idx));
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(width: 80, child: Text('Opacity')),
              Expanded(
                child: Slider(
                  value: current.opacity.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  onChanged: (v) => onChanged(current.copyWith(opacity: v)),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${(current.opacity * 100).round()}%',
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 80, child: Text('Scale')),
              Expanded(
                child: Slider(
                  value: current.scale.clamp(0.5, 3.0),
                  min: 0.5,
                  max: 3.0,
                  onChanged: (v) => onChanged(current.copyWith(scale: v)),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${current.scale.toStringAsFixed(1)}x',
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
