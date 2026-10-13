import '../gesture/gesture_interpreter.dart' show GradeTool;
import 'recipe.dart';

/// Maps an [EditRecipe] onto the preview shader's uniform contract and the
/// export path's CPU parameters. Single source of truth so preview and export
/// can never disagree on the *input* values (ARCHITECTURE §16, §8).
///
/// Uniform contract (must match `shaders/grade.frag`):
///   floats 0,1 = surface size; 2 = exposure; 3 = contrast; 4 = saturation.
class GradeUniforms {
  const GradeUniforms({
    required this.exposure,
    required this.contrast,
    required this.saturation,
  });

  final double exposure;
  final double contrast;
  final double saturation;

  /// Recipe → uniforms for the currently-renderable subset.
  ///
  /// Highlights/shadows/temperature/etc. are not yet in the shader; they are
  /// intentionally dropped here until the shader grows.
  factory GradeUniforms.fromRecipe(EditRecipe recipe) => GradeUniforms(
    exposure: recipe.exposure,
    contrast: recipe.contrast,
    saturation: recipe.saturation,
  );
}

/// Sensitivity and clamp range applied when a gesture delta lands on a tool.
///
/// Exposure is EV (a full swipe = 2 EV, preserving the seed's feel); the others
/// are unitless -1..1.
class _ToolRange {
  const _ToolRange(this.sensitivity, this.min, this.max);
  final double sensitivity;
  final double min;
  final double max;
}

const Map<GradeTool, _ToolRange> _ranges = {
  GradeTool.exposure: _ToolRange(2.0, -4.0, 4.0),
  GradeTool.contrast: _ToolRange(1.0, -1.0, 1.0),
  GradeTool.saturation: _ToolRange(1.0, -1.0, 1.0),
};

/// Applies a gesture [delta] to [tool]'s field on [recipe], returning a new
/// recipe. Pure and immutable; the receiver is untouched.
EditRecipe applyToolDelta(EditRecipe recipe, GradeTool tool, double delta) {
  final range = _ranges[tool]!;
  final current = _read(recipe, tool);
  final next = (current + delta * range.sensitivity).clamp(range.min, range.max);
  return _write(recipe, tool, next);
}

/// Resets [tool]'s field on [recipe] back to neutral. Pure.
EditRecipe resetTool(EditRecipe recipe, GradeTool tool) =>
    _write(recipe, tool, 0);

double _read(EditRecipe recipe, GradeTool tool) => switch (tool) {
  GradeTool.exposure => recipe.exposure,
  GradeTool.contrast => recipe.contrast,
  GradeTool.saturation => recipe.saturation,
};

EditRecipe _write(EditRecipe recipe, GradeTool tool, double value) =>
    switch (tool) {
      GradeTool.exposure => recipe.copyWith(exposure: value),
      GradeTool.contrast => recipe.copyWith(contrast: value),
      GradeTool.saturation => recipe.copyWith(saturation: value),
    };
