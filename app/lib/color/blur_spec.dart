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
    this.blurSampleCount = 12,
  });

  /// Derives [LensBlurSpec] from [EditRecipe], clamping all fields to valid ranges.
  factory LensBlurSpec.fromRecipe(EditRecipe recipe) {
    final shapeIdx = recipe.blurBokehShape.clamp(0, BokehShape.values.length - 1);
    return LensBlurSpec(
      enabled: recipe.blurEnabled,
      amount: recipe.blurAmount.clamp(0.0, 1.0),
      focalPoint: recipe.blurFocalPoint.clamp(0.0, 1.0),
      focalRange: recipe.blurFocalRange.clamp(0.01, 1.0),
      bokehShape: BokehShape.values[shapeIdx],
      bokehBoost: recipe.blurBokehBoost.clamp(0.0, 1.0),
      blurBackgroundBlur: recipe.blurBackgroundBlur,
      blurSampleCount: recipe.blurSampleCount.clamp(1, 64),
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
  final int blurSampleCount;

  /// True when blur is disabled or zero.
  bool get isNeutral =>
      amount <= 1e-4 && !blurBackgroundBlur;

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
          other.blurBackgroundBlur == blurBackgroundBlur &&
          other.blurSampleCount == blurSampleCount;

  @override
  int get hashCode => Object.hash(
        enabled,
        amount,
        focalPoint,
        focalRange,
        bokehShape,
          bokehBoost,
          blurBackgroundBlur,
          blurSampleCount,
        );
}
