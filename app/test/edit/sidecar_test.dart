import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/depth_sidecar.dart';
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

  test('encode/decode round-trips depthSidecarPath and companion file name', () {
    final recipe = EditRecipe.neutral.copyWith(
      blurEnabled: true,
      blurAmount: 0.65,
      depthSidecarPath: 'photo.axdf',
    );
    final json = RecipeSidecar.encode(recipe);
    expect(json, contains('depthSidecarPath'));
    final decoded = RecipeSidecar.decode(json);
    expect(decoded.depthSidecarPath, 'photo.axdf');
    expect(decoded.blurEnabled, isTrue);
    expect(RecipeSidecar.depthFileNameFor('photo.jpg'), 'photo.axdf');
  });

  test('RecipeSidecar.save and load round-trips recipe with companion AXDF depth sidecar', () async {
    final tempDir = await Directory.systemTemp.createTemp('sidecar_roundtrip_test');
    try {
      final imageFile = File('${tempDir.path}/sample.jpg');
      final recipeFile = File(RecipeSidecar.fileNameFor(imageFile.path));
      final depthData = DepthSidecarData(
        width: 2,
        height: 2,
        confidence: 0.92,
        source: DepthSourceType.neural,
        contentHash: 42,
        plane: Float32List.fromList([0.1, 0.2, 0.3, 0.4]),
      );

      final recipe = EditRecipe.neutral.copyWith(
        blurEnabled: true,
        blurAmount: 0.5,
        depthField: depthData,
      );

      await RecipeSidecar.save(recipeFile, recipe, depthData: depthData);

      // Verify recipe JSON and companion AXDF files exist
      expect(await recipeFile.exists(), isTrue);
      final axdfFile = File(RecipeSidecar.depthFileNameFor(imageFile.path));
      expect(await axdfFile.exists(), isTrue);

      // Load back
      final loaded = await RecipeSidecar.load(recipeFile);
      expect(loaded.blurEnabled, isTrue);
      expect(loaded.depthField, isNotNull);
      expect(loaded.depthField!.width, 2);
      expect(loaded.depthField!.height, 2);
      expect(loaded.depthField!.confidence, closeTo(0.92, 1e-4));
      expect(loaded.depthField!.plane.length, 4);
      expect(loaded.depthSidecar, axdfFile.path);
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });
}
