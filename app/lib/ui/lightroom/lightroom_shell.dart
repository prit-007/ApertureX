import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../color/interactive_histogram.dart';
import '../../color/tat.dart';
import '../../edit/parameter.dart';
import '../common/geometry_controls.dart';
import '../common/hsl_mixer.dart';
import '../common/mask_controls.dart';
import '../common/parameter_panel.dart';
import '../common/tone_curve_editor.dart';

enum _Tab { panel, curve, mix, geometry, mask }

/// Lightroom shell: histogram + categorized panels (tone / colour / effects /
/// detail), a tone curve, an HSL mixer, geometry and masks — all over the shared
/// recipe. Owns no edit state.
class LightroomShell extends ConsumerStatefulWidget {
  const LightroomShell({super.key});

  @override
  ConsumerState<LightroomShell> createState() => _LightroomShellState();
}

class _LightroomShellState extends ConsumerState<LightroomShell> {
  static const List<RecipeSection> _sections = [
    RecipeSection.light,
    RecipeSection.color,
    RecipeSection.effects,
    RecipeSection.detail,
  ];

  RecipeSection _section = RecipeSection.light;
  _Tab _tab = _Tab.panel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        labelStyle: TextStyle(
          fontSize: 12,
          letterSpacing: 0.8,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  child: InteractiveHistogram(),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Target Adjustment Tool: drag the image to target the '
                    'HSL colour under the pointer',
                isSelected: ref.watch(tatModeProvider),
                onPressed: () => ref.read(tatModeProvider.notifier).toggle(),
                icon: const Icon(Icons.colorize),
                selectedIcon: Icon(Icons.colorize, color: scheme.primary),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final section in _sections)
                chip(
                  section.name,
                  _tab == _Tab.panel && section == _section,
                  () => setState(() {
                    _section = section;
                    _tab = _Tab.panel;
                  }),
                ),
              chip('Curve', _tab == _Tab.curve, () => setState(() => _tab = _Tab.curve)),
              chip('Mix', _tab == _Tab.mix, () => setState(() => _tab = _Tab.mix)),
              chip('Geometry', _tab == _Tab.geometry, () => setState(() => _tab = _Tab.geometry)),
              chip('Mask', _tab == _Tab.mask, () => setState(() => _tab = _Tab.mask)),
            ],
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        SizedBox(
          height: 272,
          child: switch (_tab) {
            _Tab.panel => ParameterPanel(section: _section),
            _Tab.curve => const ToneCurveEditor(),
            _Tab.mix => const HslMixer(),
            _Tab.geometry => const GeometryControls(),
            _Tab.mask => const MaskControls(),
          },
        ),
      ],
    );
  }
}
