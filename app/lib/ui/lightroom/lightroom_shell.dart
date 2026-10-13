import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../color/interactive_histogram.dart';
import '../../color/tat.dart';
import '../../edit/parameter.dart';
import '../common/geometry_controls.dart';
import '../common/hsl_mixer.dart';
import '../common/parameter_panel.dart';
import '../common/tone_curve_editor.dart';

enum _Tab { panel, curve, mix, geometry }

/// Lightroom shell: histogram + tabs (categorized panels / tone curve / HSL
/// mixer) over the shared recipe. Owns no edit state.
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
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
                selectedIcon: const Icon(Icons.colorize, color: Colors.white),
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
                _tabButton(
                  section.name.toUpperCase(),
                  _tab == _Tab.panel && section == _section,
                  () => setState(() {
                    _section = section;
                    _tab = _Tab.panel;
                  }),
                ),
              _tabButton(
                'CURVE',
                _tab == _Tab.curve,
                () => setState(() => _tab = _Tab.curve),
              ),
              _tabButton(
                'MIX',
                _tab == _Tab.mix,
                () => setState(() => _tab = _Tab.mix),
              ),
              _tabButton(
                'GEOMETRY',
                _tab == _Tab.geometry,
                () => setState(() => _tab = _Tab.geometry),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 260,
          child: switch (_tab) {
            _Tab.panel => ParameterPanel(section: _section),
            _Tab.curve => const ToneCurveEditor(),
            _Tab.mix => const HslMixer(),
            _Tab.geometry => const GeometryControls(),
          },
        ),
      ],
    );
  }

  Widget _tabButton(String label, bool selected, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white38,
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
