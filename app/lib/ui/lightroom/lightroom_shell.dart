import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../color/interactive_histogram.dart';
import '../../edit/parameter.dart';
import '../common/parameter_panel.dart';
import '../common/tone_curve_editor.dart';

/// Lightroom shell skeleton (P2): a histogram + category nav over a parameter
/// panel. Reads/writes the shared controller through [ParameterPanel]; owns no
/// edit state.
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
  bool _curve = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            child: InteractiveHistogram(),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final section in _sections)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextButton(
                    onPressed: () => setState(() {
                      _section = section;
                      _curve = false;
                    }),
                    child: Text(
                      section.name.toUpperCase(),
                      style: TextStyle(
                        color: !_curve && section == _section
                            ? Colors.white
                            : Colors.white38,
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: !_curve && section == _section
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextButton(
                  onPressed: () => setState(() => _curve = true),
                  child: Text(
                    'CURVE',
                    style: TextStyle(
                      color: _curve ? Colors.white : Colors.white38,
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: _curve ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 260,
          child: _curve
              ? const ToneCurveEditor()
              : ParameterPanel(section: _section),
        ),
      ],
    );
  }
}
