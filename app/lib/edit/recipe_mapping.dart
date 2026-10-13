import '../gesture/gesture_interpreter.dart' show GradeTool;
import 'parameter.dart';

/// The single seam mapping what each shell exposes onto the parameter catalog
/// (P2 Slice A). A parameter exists in the recipe *before* either shell
/// renders it; shells never invent parameters directly.
///
/// Snapseed tools are the gesture carousel today ([GradeTool]); Lightroom
/// categories are [RecipeSection]s.

/// Each Snapseed carousel tool adjusts these parameters.
const Map<GradeTool, List<Parameter>> snapseedToolParameters = {
  GradeTool.exposure: [Parameter.exposure],
  GradeTool.contrast: [Parameter.contrast],
  GradeTool.saturation: [Parameter.saturation],
};

/// Every parameter belonging to a [RecipeSection] (a Lightroom category).
List<Parameter> parametersIn(RecipeSection section) => [
  for (final p in Parameter.values)
    if (specOf(p).section == section) p,
];

/// The ordered Snapseed gesture carousel, flattened to parameters.
List<Parameter> get snapseedCarousel => [
  for (final tool in GradeTool.values) ...snapseedToolParameters[tool]!,
];