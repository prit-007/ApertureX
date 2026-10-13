import 'package:material_ui/material_ui.dart';

import '../../edit/parameter.dart';
import '../common/parameter_panel.dart';

/// Lightroom shell skeleton (P2 Slice C): a category nav over a parameter
/// panel. Reads/writes the shared controller through [ParameterPanel] — it owns
/// no edit state.
class LightroomShell extends StatefulWidget {
  const LightroomShell({super.key});

  @override
  State<LightroomShell> createState() => _LightroomShellState();
}

class _LightroomShellState extends State<LightroomShell> {
  static const List<RecipeSection> _sections = [
    RecipeSection.light,
    RecipeSection.color,
  ];

  RecipeSection _section = RecipeSection.light;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                    onPressed: () => setState(() => _section = section),
                    child: Text(
                      section.name.toUpperCase(),
                      style: TextStyle(
                        color: section == _section
                            ? Colors.white
                            : Colors.white38,
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: section == _section
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 232, child: ParameterPanel(section: _section)),
      ],
    );
  }
}
