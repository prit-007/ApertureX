import '../edit/recipe.dart';

/// A Dart-native snapshot of the render settings — the twelve point-wise
/// scalars plus the four tone-curve point lists — mapped by the engine facade
/// onto Rust's `ColorParams` / `CurveParams`. Build with [GradeSpec.fromRecipe].
class GradeSpec {
  const GradeSpec({
    this.exposure = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.temperature = 0,
    this.tint = 0,
    this.vibrance = 0,
    this.gradeShadowHue = 0,
    this.gradeShadowSat = 0,
    this.gradeMidHue = 0,
    this.gradeMidSat = 0,
    this.gradeHighlightHue = 0,
    this.gradeHighlightSat = 0,
    this.masterCurve = const <double>[],
    this.redCurve = const <double>[],
    this.greenCurve = const <double>[],
    this.blueCurve = const <double>[],
  });

  final double exposure;
  final double contrast;
  final double saturation;
  final double temperature;
  final double tint;
  final double vibrance;
  final double gradeShadowHue;
  final double gradeShadowSat;
  final double gradeMidHue;
  final double gradeMidSat;
  final double gradeHighlightHue;
  final double gradeHighlightSat;

  /// Flat tone-curve control points (`[x0,y0,...]`); empty = identity.
  final List<double> masterCurve;
  final List<double> redCurve;
  final List<double> greenCurve;
  final List<double> blueCurve;

  factory GradeSpec.fromRecipe(EditRecipe recipe) => GradeSpec(
    exposure: recipe.exposure,
    contrast: recipe.contrast,
    saturation: recipe.saturation,
    temperature: recipe.temperature,
    tint: recipe.tint,
    vibrance: recipe.vibrance,
    gradeShadowHue: recipe.gradeShadowHue,
    gradeShadowSat: recipe.gradeShadowSat,
    gradeMidHue: recipe.gradeMidHue,
    gradeMidSat: recipe.gradeMidSat,
    gradeHighlightHue: recipe.gradeHighlightHue,
    gradeHighlightSat: recipe.gradeHighlightSat,
    masterCurve: recipe.masterCurve.points,
    redCurve: recipe.redCurve.points,
    greenCurve: recipe.greenCurve.points,
    blueCurve: recipe.blueCurve.points,
  );
}
