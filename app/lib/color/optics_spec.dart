import '../edit/recipe.dart';

/// Optics and lens corrections specification built from an [EditRecipe].
class OpticsSpec {
  const OpticsSpec({
    this.removeChromaticAberration = false,
    this.defringePurpleAmount = 0,
    this.defringePurpleHueMin = 0.70,
    this.defringePurpleHueMax = 0.95,
    this.defringeGreenAmount = 0,
    this.defringeGreenHueMin = 0.17,
    this.defringeGreenHueMax = 0.50,
    this.profileCorrections = false,
    this.profileDistortion = 1.0,
    this.profileVignetting = 1.0,
  });

  factory OpticsSpec.fromRecipe(EditRecipe recipe) => OpticsSpec(
    removeChromaticAberration: recipe.removeChromaticAberration,
    defringePurpleAmount: recipe.defringePurpleAmount,
    defringePurpleHueMin: recipe.defringePurpleHueMin,
    defringePurpleHueMax: recipe.defringePurpleHueMax,
    defringeGreenAmount: recipe.defringeGreenAmount,
    defringeGreenHueMin: recipe.defringeGreenHueMin,
    defringeGreenHueMax: recipe.defringeGreenHueMax,
    profileCorrections: recipe.profileCorrections,
    profileDistortion: recipe.profileDistortion,
    profileVignetting: recipe.profileVignetting,
  );

  final bool removeChromaticAberration;
  final double defringePurpleAmount;
  final double defringePurpleHueMin;
  final double defringePurpleHueMax;
  final double defringeGreenAmount;
  final double defringeGreenHueMin;
  final double defringeGreenHueMax;
  final bool profileCorrections;
  final double profileDistortion;
  final double profileVignetting;

  bool get isNeutral =>
      !removeChromaticAberration &&
      defringePurpleAmount == 0 &&
      defringeGreenAmount == 0 &&
      (!profileCorrections ||
          (profileDistortion == 0 && profileVignetting == 0));
}
