import 'package:material_ui/material_ui.dart';

import '../../edit/parameter.dart';
import '../../edit/recipe_mapping.dart';
import 'parameter_control.dart';

/// Renders every parameter in a [RecipeSection] through the shared
/// [ParameterControl].
class ParameterPanel extends StatelessWidget {
  const ParameterPanel({super.key, required this.section});

  final RecipeSection section;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (final parameter in parametersIn(section))
          ParameterControl(parameter: parameter),
      ],
    );
  }
}
