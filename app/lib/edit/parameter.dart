import 'recipe.dart';

/// The recipe's parameter groups (ARCHITECTURE §16, P2). Lightroom categories
/// map 1:1 onto sections; Snapseed tools map onto parameters *within* them.
enum RecipeSection { light, color, tone, effects, detail, optics, geometry, masking }

/// How a parameter is manipulated. The seed ships sliders only; the catalog is
/// the seam a future `curve` or `hueGrid` parameter slots into.
enum ParameterKind { slider }

/// Every editable scalar in the recipe — the seam both shells share. A
/// parameter exists here *before* either shell renders it.
enum Parameter {
  // Light
  exposure,
  contrast,
  highlights,
  shadows,
  whites,
  blacks,
  // Color
  temperature,
  tint,
  vibrance,
  saturation,
}

/// Static metadata for a [Parameter].
class ParameterSpec {
  const ParameterSpec({
    required this.id,
    required this.section,
    required this.label,
    this.kind = ParameterKind.slider,
    required this.min,
    required this.max,
    this.neutral = 0,
    this.scale = 1,
  }) : assert(min < max),
       assert(min <= neutral && neutral <= max);

  final Parameter id;
  final RecipeSection section;
  final String label;
  final ParameterKind kind;

  /// Inclusive slider range. Neutral lies within it.
  final double min;
  final double max;

  /// Value that leaves the image unchanged.
  final double neutral;

  /// Gesture/fine-control sensitivity: a unit delta moves the value by this
  /// (exposure is EV: a full Snapseed swipe = 2 EV via this scale).
  final double scale;
}

const Map<Parameter, ParameterSpec> parameterSpecs = {
  Parameter.exposure: ParameterSpec(
    id: Parameter.exposure,
    section: RecipeSection.light,
    label: 'Exposure',
    min: -4,
    max: 4,
    scale: 2,
  ),
  Parameter.contrast: ParameterSpec(
    id: Parameter.contrast,
    section: RecipeSection.light,
    label: 'Contrast',
    min: -1,
    max: 1,
  ),
  Parameter.highlights: ParameterSpec(
    id: Parameter.highlights,
    section: RecipeSection.light,
    label: 'Highlights',
    min: -1,
    max: 1,
  ),
  Parameter.shadows: ParameterSpec(
    id: Parameter.shadows,
    section: RecipeSection.light,
    label: 'Shadows',
    min: -1,
    max: 1,
  ),
  Parameter.whites: ParameterSpec(
    id: Parameter.whites,
    section: RecipeSection.light,
    label: 'Whites',
    min: -1,
    max: 1,
  ),
  Parameter.blacks: ParameterSpec(
    id: Parameter.blacks,
    section: RecipeSection.light,
    label: 'Blacks',
    min: -1,
    max: 1,
  ),
  Parameter.temperature: ParameterSpec(
    id: Parameter.temperature,
    section: RecipeSection.color,
    label: 'Temperature',
    min: -1,
    max: 1,
  ),
  Parameter.tint: ParameterSpec(
    id: Parameter.tint,
    section: RecipeSection.color,
    label: 'Tint',
    min: -1,
    max: 1,
  ),
  Parameter.vibrance: ParameterSpec(
    id: Parameter.vibrance,
    section: RecipeSection.color,
    label: 'Vibrance',
    min: -1,
    max: 1,
  ),
  Parameter.saturation: ParameterSpec(
    id: Parameter.saturation,
    section: RecipeSection.color,
    label: 'Saturation',
    min: -1,
    max: 1,
  ),
};

/// The [ParameterSpec] for [p]. Always present — the catalog covers the enum.
ParameterSpec specOf(Parameter p) => parameterSpecs[p]!;

/// Clamps [value] to [p]'s inclusive range.
double clampParameter(Parameter p, double value) {
  final s = specOf(p);
  return value.clamp(s.min, s.max);
}

/// The current [p] value on [recipe].
double valueOf(EditRecipe recipe, Parameter p) => switch (p) {
  Parameter.exposure => recipe.exposure,
  Parameter.contrast => recipe.contrast,
  Parameter.highlights => recipe.highlights,
  Parameter.shadows => recipe.shadows,
  Parameter.whites => recipe.whites,
  Parameter.blacks => recipe.blacks,
  Parameter.temperature => recipe.temperature,
  Parameter.tint => recipe.tint,
  Parameter.vibrance => recipe.vibrance,
  Parameter.saturation => recipe.saturation,
};

/// A copy of [recipe] with [p] set to [value] (clamped). Pure.
EditRecipe withValue(EditRecipe recipe, Parameter p, double value) {
  final v = clampParameter(p, value);
  return switch (p) {
    Parameter.exposure => recipe.copyWith(exposure: v),
    Parameter.contrast => recipe.copyWith(contrast: v),
    Parameter.highlights => recipe.copyWith(highlights: v),
    Parameter.shadows => recipe.copyWith(shadows: v),
    Parameter.whites => recipe.copyWith(whites: v),
    Parameter.blacks => recipe.copyWith(blacks: v),
    Parameter.temperature => recipe.copyWith(temperature: v),
    Parameter.tint => recipe.copyWith(tint: v),
    Parameter.vibrance => recipe.copyWith(vibrance: v),
    Parameter.saturation => recipe.copyWith(saturation: v),
  };
}