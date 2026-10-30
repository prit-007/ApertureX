import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/recipe_controller.dart';

/// Lightroom-style HSL color mixer: pick one of eight colour bands, then shift
/// its Hue / Saturation / Luminance. Writes to the shared recipe.
class HslMixer extends ConsumerStatefulWidget {
  const HslMixer({super.key});

  @override
  ConsumerState<HslMixer> createState() => _HslMixerState();
}

class _HslMixerState extends ConsumerState<HslMixer> {
  static const List<String> _bandNames = [
    'Red',
    'Orange',
    'Yellow',
    'Green',
    'Aqua',
    'Blue',
    'Purple',
    'Magenta',
  ];

  static const List<Color> _bands = [
    Color(0xFFE53935), // red (0°)
    Color(0xFFFB8C00), // orange (30°)
    Color(0xFFFDD835), // yellow (60°)
    Color(0xFF43A047), // green (120°)
    Color(0xFF00ACC1), // aqua (180°)
    Color(0xFF1E88E5), // blue (220°)
    Color(0xFF8E24AA), // purple (280°)
    Color(0xFFD81B60), // magenta (320°)
  ];

  int _band = 0;

  Color _prevBandColor(int index) {
    return _bands[(index - 1 + _bands.length) % _bands.length];
  }

  Color _nextBandColor(int index) {
    return _bands[(index + 1) % _bands.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hsl = ref.watch(recipeControllerProvider).recipe.hsl;
    final notifier = ref.read(recipeControllerProvider.notifier);
    final activeColor = _bands[_band];
    final activeBandName = _bandNames[_band];

    Widget slider(String label, int offset, LinearGradient trackGradient) {
      final value = hsl[_band * 3 + offset];
      final isModified = value.abs() > 0.001;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isModified ? scheme.primary : scheme.onSurfaceVariant,
                      fontWeight: isModified ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () {
                    HapticFeedback.selectionClick();
                    switch (offset) {
                      case 0:
                        notifier.setHsl(_band, hue: 0.0);
                      case 1:
                        notifier.setHsl(_band, saturation: 0.0);
                      case _:
                        notifier.setHsl(_band, luminance: 0.0);
                    }
                    notifier.commit(label: 'Reset $label');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isModified
                          ? scheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isModified ? scheme.primary : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Stack(
              alignment: Alignment.center,
              children: [
                // Visual gradient underlay
                Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: trackGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: activeColor,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                      elevation: 2,
                    ),
                    overlayColor: activeColor.withValues(alpha: 0.15),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: value.clamp(-1.0, 1.0),
                    min: -1,
                    max: 1,
                    onChanged: (v) => switch (offset) {
                      0 => notifier.setHsl(_band, hue: v),
                      1 => notifier.setHsl(_band, saturation: v),
                      _ => notifier.setHsl(_band, luminance: v),
                    },
                    onChangeEnd: (_) => notifier.commit(label: 'HSL'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final hueGradient = LinearGradient(
      colors: [_prevBandColor(_band), activeColor, _nextBandColor(_band)],
    );

    final satGradient = LinearGradient(
      colors: [const Color(0xFF6E6E6E), activeColor],
    );

    final lumGradient = LinearGradient(
      colors: [const Color(0xFF141414), activeColor, const Color(0xFFF0F0F0)],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Swatch Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _bands.length; i++)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _band = i);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _bands[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: i == _band
                                  ? scheme.onSurface
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: i == _band
                                ? [
                                    BoxShadow(
                                      color: _bands[i].withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Active Band Header with Reset Action
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$activeBandName Mixer',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  notifier.setHsl(_band, hue: 0.0, saturation: 0.0, luminance: 0.0);
                  notifier.commit(label: 'Reset $activeBandName');
                },
                child: Text(
                  'Reset Band',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  for (var b = 0; b < _bands.length; b++) {
                    notifier.setHsl(b, hue: 0.0, saturation: 0.0, luminance: 0.0);
                  }
                  notifier.commit(label: 'Reset All HSL');
                },
                child: Text(
                  'Reset All',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 2),

        // Sliders with custom gradient tracks
        slider('Hue', 0, hueGradient),
        slider('Saturation', 1, satGradient),
        slider('Luminance', 2, lumGradient),
        const SizedBox(height: 6),
      ],
    );
  }
}
