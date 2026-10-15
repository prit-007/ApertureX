import 'package:material_ui/material_ui.dart';

import '../../edit/parameter.dart';
import '../../edit/recipe_mapping.dart';
import 'app_primitives.dart';
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
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        SectionHeader(section.name),
        for (final parameter in parametersIn(section))
          ParameterControl(parameter: parameter),
      ],
    );
  }
}
