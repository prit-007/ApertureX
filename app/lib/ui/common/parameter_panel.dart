import 'package:material_ui/material_ui.dart';

import '../../edit/parameter.dart';
import '../../edit/recipe_mapping.dart';
import 'parameter_control.dart';

/// Throwaway panel (Slice B exit criteria): renders every parameter in a
/// [RecipeSection] through the shared [ParameterControl], proving the control
/// works before the real shell layout exists.
class ParameterPanel extends StatelessWidget {
  const ParameterPanel({super.key, required this.section});

  final RecipeSection section;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Text(
            section.name.toUpperCase(),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ),
        for (final parameter in parametersIn(section))
          ParameterControl(parameter: parameter),
      ],
    );
  }
}
