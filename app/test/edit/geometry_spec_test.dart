import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/edit/geometry_spec.dart';
import 'package:tessera/edit/recipe.dart';

void main() {
  test('neutral by default', () {
    expect(const GeometrySpec().isNeutral, isTrue);
    expect(GeometrySpec.fromRecipe(EditRecipe.neutral).isNeutral, isTrue);
  });

  test('fromRecipe maps the geometry fields', () {
    final recipe = EditRecipe.neutral.copyWith(
      rotation: 1,
      flipH: true,
      straighten: 10,
    );
    final spec = GeometrySpec.fromRecipe(recipe);
    expect(spec.rotation, 1);
    expect(spec.flipH, isTrue);
    expect(spec.flipV, isFalse);
    expect(spec.straighten, 10);
    expect(spec.isNeutral, isFalse);
  });

  test('recipe geometry round-trips through JSON', () {
    final recipe = EditRecipe.neutral.copyWith(
      rotation: 3,
      flipV: true,
      straighten: -7.5,
    );
    expect(EditRecipe.fromJson(recipe.toJson()), recipe);
  });
}
