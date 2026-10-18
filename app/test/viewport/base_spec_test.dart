import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/viewport/base_spec.dart';
import 'package:flutter_test/flutter_test.dart';

/// The blur slider must reach the Rust preview bake: the spec built from the
/// recipe carries every blur field across the bridge (a previous wiring break
/// left blur unreachable in both preview and export).
void main() {
  test('neutral recipe produces a disabled blur spec', () {
    final spec = baseSpecFromRecipe(const EditRecipe());
    expect(spec.blurEnabled, isFalse);
    expect(spec.blurAmount, 0);
    expect(spec.blurFocalPoint, 0.5);
    expect(spec.blurFocalRange, 0.2);
    expect(spec.blurBokehShape, 0);
    expect(spec.blurBokehBoost, 0);
  });

  test('AI-depth-calibrated recipe values ride the spec to Rust', () {
    final recipe = const EditRecipe().copyWith(
      blurEnabled: true,
      blurAmount: 0.45,
      blurFocalPoint: 0.62,
      blurFocalRange: 0.3,
      blurBokehShape: 2, // hexagon
      blurBokehBoost: 0.7,
    );
    final spec = baseSpecFromRecipe(recipe);
    expect(spec.blurEnabled, isTrue);
    expect(spec.blurAmount, 0.45);
    expect(spec.blurFocalPoint, 0.62);
    expect(spec.blurFocalRange, 0.3);
    expect(spec.blurBokehShape, 2);
    expect(spec.blurBokehBoost, 0.7);
  });

  test('spatial controls ride the spec (preview base stage)', () {
    final spec = baseSpecFromRecipe(
      const EditRecipe().copyWith(shadows: 0.4, highlights: -0.3, clarity: 0.2),
    );
    expect(spec.shadows, 0.4);
    expect(spec.highlights, -0.3);
    expect(spec.clarity, 0.2);
  });

  test('optics controls ride the spec', () {
    final spec = baseSpecFromRecipe(
      const EditRecipe().copyWith(removeChromaticAberration: true, defringePurpleAmount: 0.6),
    );
    expect(spec.removeChromaticAberration, isTrue);
    expect(spec.defringePurpleAmount, 0.6);
  });
}
