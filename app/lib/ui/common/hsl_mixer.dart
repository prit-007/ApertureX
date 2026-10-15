import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/recipe_controller.dart';

/// Lightroom-style HSL color mixer: pick one of eight colour bands, then shift
/// its Hue / Saturation / Luminance. Writes to the shared recipe.
class HslMixer extends ConsumerStatefulWidget {
  const HslMixer({super.key});

  @override
  ConsumerState<HslMixer> createState() => _HslMixerState();
}

class _HslMixerState extends ConsumerState<HslMixer> {
  static const List<Color> _bands = [
    Color(0xFFE53935), // red
    Color(0xFFFB8C00), // orange
    Color(0xFFFDD835), // yellow
    Color(0xFF43A047), // green
    Color(0xFF00ACC1), // aqua
    Color(0xFF1E88E5), // blue
    Color(0xFF8E24AA), // purple
    Color(0xFFD81B60), // magenta
  ];

  int _band = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hsl = ref.watch(recipeControllerProvider).recipe.hsl;
    final notifier = ref.read(recipeControllerProvider.notifier);

    Widget slider(String label, int offset) {
      final value = hsl[_band * 3 + offset];
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              child: Text(
                label,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            Expanded(
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
            SizedBox(
              width: 44,
              child: Text(
                '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}',
                textAlign: TextAlign.end,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 10,
            children: [
              for (var i = 0; i < _bands.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _band = i),
                  // Opaque so the whole 48px target is hit-testable, not
                  // just the 30px painted circle.
                  behavior: HitTestBehavior.opaque,
                  // 30px circle inside a 48px (Material a11y minimum) target.
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
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        slider('Hue', 0),
        slider('Saturation', 1),
        slider('Luminance', 2),
      ],
    );
  }
}
