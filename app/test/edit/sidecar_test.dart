import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/sidecar.dart';

void main() {
  test('encode/decode round-trips a full recipe', () {
    final recipe = EditRecipe.neutral.copyWith(
      exposure: 1.2,
      saturation: -0.3,
      rotation: 1,
      flipH: true,
    );
    final json = RecipeSidecar.encode(recipe);

    expect(json, contains('exposure')); // human-readable
    expect(RecipeSidecar.decode(json), recipe);
  });

  test('fileNameFor appends the open extension', () {
    expect(RecipeSidecar.fileNameFor('photo.jpg'), 'photo.jpg.aperturex.json');
  });

  test('decode rejects non-object JSON', () {
    expect(
      () => RecipeSidecar.decode('[1,2,3]'),
      throwsA(isA<FormatException>()),
    );
  });
}
