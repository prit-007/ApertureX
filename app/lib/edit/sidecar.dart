import 'dart:convert';
import 'package:universal_io/io.dart';

import 'depth_sidecar.dart';
import 'recipe.dart';

/// Open, human-readable sidecar for non-destructive edits. It is just the
/// recipe as flat JSON — no hidden database, no lock-in — so edit data stays
/// with the user's files and can be read by other tools (ADR: local-first).
class RecipeSidecar {
  const RecipeSidecar._();

  /// Sidecar extension appended to the image file name.
  static const String extension = '.aperturex.json';

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Serialises [recipe] to pretty JSON.
  static String encode(EditRecipe recipe) => _encoder.convert(recipe.toJson());

  /// Parses a sidecar produced by [encode] (tolerates missing/unknown keys).
  static EditRecipe decode(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('sidecar is not a JSON object');
    }
    return EditRecipe.fromJson(decoded.cast<String, Object?>());
  }

  /// The sidecar file name for an image called [imageName].
  static String fileNameFor(String imageName) => '$imageName$extension';

  /// The companion binary depth sidecar file name for [imageName].
  static String depthFileNameFor(String imageName) => DepthSidecar.fileNameFor(imageName);

  /// Saves [recipe] to [recipeFile] and companion binary depth sidecar (.axdf) if depth is present.
  static Future<void> save(
    File recipeFile,
    EditRecipe recipe, {
    DepthSidecarData? depthData,
  }) async {
    final effectiveDepth = depthData ?? recipe.depthField;
    String? depthPath = recipe.depthSidecarPath ?? recipe.depthSidecar;
    if (effectiveDepth != null) {
      final base = recipeFile.path.endsWith(extension)
          ? recipeFile.path.substring(0, recipeFile.path.length - extension.length)
          : recipeFile.path;
      final axdfFile = File(depthFileNameFor(base));
      await DepthSidecar.save(axdfFile, effectiveDepth);
      depthPath = axdfFile.path;
    }
    final toSave = recipe.copyWith(
      depthSidecar: depthPath,
      depthSidecarPath: depthPath,
      depthField: effectiveDepth,
    );
    await recipeFile.writeAsString(encode(toSave));
  }

  /// Loads [recipeFile] and automatically loads companion binary depth sidecar (.axdf) if present.
  static Future<EditRecipe> load(File recipeFile) async {
    final text = await recipeFile.readAsString();
    var recipe = decode(text);
    final base = recipeFile.path.endsWith(extension)
        ? recipeFile.path.substring(0, recipeFile.path.length - extension.length)
        : recipeFile.path;
    final axdfFile = File(depthFileNameFor(base));
    if (await axdfFile.exists()) {
      final depthData = await DepthSidecar.load(axdfFile);
      if (depthData != null) {
        recipe = recipe.copyWith(
          depthSidecar: axdfFile.path,
          depthSidecarPath: axdfFile.path,
          depthField: depthData,
        );
      }
    }
    return recipe;
  }
}
