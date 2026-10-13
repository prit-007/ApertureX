import 'dart:convert';

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
}
