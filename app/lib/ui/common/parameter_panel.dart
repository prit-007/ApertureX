import 'package:material_ui/material_ui.dart';

import '../../edit/parameter.dart';
import '../../edit/recipe_mapping.dart';
import 'parameter_control.dart';

/// Renders every parameter in a [RecipeSection] through the shared
/// [ParameterControl]. Uses tight 12x2 spacing so sliders nest closely
/// together, minimizing vertical scroll in bottom sheets.
class ParameterPanel extends StatelessWidget {
  const ParameterPanel({super.key, required this.section});

  final RecipeSection section;

  @override
  Widget build(BuildContext context) {
    final parameters = parametersIn(section);

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(vertical: 2),
      children: [
        for (final parameter in parameters)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: RepaintBoundary(
              child: ParameterControl(parameter: parameter),
            ),
          ),
      ],
    );
  }
}
