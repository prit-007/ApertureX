import '../edit/recipe.dart';

/// Bokeh aperture blade shape.
enum BokehShape {
  circle('Circle'),
  pentagon('5 Blade'),
  hexagon('6 Blade'),
  septagon('7 Blade'),
  catsEye("Cat's Eye"),
  soapBubble('Soap Bubble'),
  swirl('Swirl');

  const BokehShape(this.label);
  final String label;
}

/// Pure-Dart optical lens blur specification derived from [EditRecipe].
class LensBlurSpec {
  const LensBlurSpec({
    this.enabled = false,
    this.amount = 0.0,
    this.focalPoint = 0.5,
    this.focalRange = 0.2,
    this.bokehShape = BokehShape.circle,
    this.bokehBoost = 0.0,
    this.blurBackgroundBlur = false,
  });

  /// Derives [LensBlurSpec] from [EditRecipe].
  factory LensBlurSpec.fromRecipe(EditRecipe recipe) {
    final shapeIdx =
        recipe.blurBokehShape.clamp(0, BokehShape.values.length - 1);
    return LensBlurSpec(
      enabled: recipe.blurEnabled,
      amount: recipe.blurAmount,
      focalPoint: recipe.blurFocalPoint,
      focalRange: recipe.blurFocalRange,
      bokehShape: BokehShape.values[shapeIdx],
      bokehBoost: recipe.blurBokehBoost,
      blurBackgroundBlur: recipe.blurBackgroundBlur,
    );
  }

  /// Whether lens blur is engaged.
  final bool enabled;

  /// Amount of optical blur `0..1` (1.0 = wide open f/1.2).
  final double amount;

  /// Focal depth plane in sharp focus `0..1`.
  final double focalPoint;

  /// Depth of field range in sharp focus `0..1`.
  final double focalRange;

  /// Bokeh aperture blade shape.
  final BokehShape bokehShape;

  /// Specular highlight boost `0..1`.
  final double bokehBoost;

  /// When true, applies background-only blur (subject stays sharp).
  final bool blurBackgroundBlur;

  /// True when blur is disabled or zero.
  bool get isNeutral =>
      !enabled || (amount <= 1e-4 && !blurBackgroundBlur);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LensBlurSpec &&
          other.enabled == enabled &&
          other.amount == amount &&
          other.focalPoint == focalPoint &&
          other.focalRange == focalRange &&
          other.bokehShape == bokehShape &&
          other.bokehBoost == bokehBoost &&
          other.blurBackgroundBlur == blurBackgroundBlur;

  @override
  int get hashCode => Object.hash(
        enabled,
        amount,
        focalPoint,
        focalRange,
        bokehShape,
        bokehBoost,
        blurBackgroundBlur,
      );
}
