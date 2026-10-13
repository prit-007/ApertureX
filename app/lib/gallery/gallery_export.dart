import 'package:gal/gal.dart';

import '../color/grade_spec.dart';
import '../color/spatial_spec.dart';
import '../edit/geometry_spec.dart';
import '../edit/recipe.dart';
import '../engine/engine.dart';
import 'gallery_source.dart';

/// Exports gallery assets to the device Photos/DCIM (batch or single), applying
/// each asset's recipe. Grading reuses the exact preview path, and the source
/// EXIF is preserved (#12/#13).
class GalleryExporter {
  const GalleryExporter(this.source);

  final GallerySource source;

  /// Grades and saves one asset with [recipe]; returns the bytes written.
  Future<int> exportAsset(String assetId, EditRecipe recipe) async {
    final jpeg = await source.loadImage(assetId);
    if (jpeg.isEmpty) return 0;

    final decoded = await TesseraEngine.decodeJpegRgba(jpeg);
    final exif = await TesseraEngine.extractExif(jpeg);

    // Normalize wide-gamut input (Display P3 -> sRGB) so colours are faithful.
    final space = await TesseraEngine.detectColorspace(jpeg);
    final rgba = space == 2
        ? await TesseraEngine.p3ToSrgb(
            decoded.rgba,
            width: decoded.width,
            height: decoded.height,
          )
        : decoded.rgba;

    final out = await TesseraEngine.exportJpeg(
      rgba: rgba,
      width: decoded.width,
      height: decoded.height,
      spec: GradeSpec.fromRecipe(recipe),
      spatial: SpatialSpec.fromRecipe(recipe),
      geometry: GeometrySpec.fromRecipe(recipe),
      exif: exif,
    );

    await Gal.putImageBytes(out, name: 'aperturex_$assetId');
    return out.length;
  }

  /// Exports many assets, mapping each id to its recipe via [recipeFor].
  Future<int> exportBatch(
    Iterable<String> assetIds,
    EditRecipe Function(String id) recipeFor,
  ) async {
    var count = 0;
    for (final id in assetIds) {
      await exportAsset(id, recipeFor(id));
      count++;
    }
    return count;
  }
}
