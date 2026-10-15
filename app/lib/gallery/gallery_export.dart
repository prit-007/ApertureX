import 'dart:typed_data';

import 'package:gal/gal.dart';

import '../color/grade_spec.dart';
import '../color/spatial_spec.dart';
import '../edit/geometry_spec.dart';
import '../edit/recipe.dart';
import '../engine/engine.dart';
import '../engine/image_format.dart';
import 'gallery_source.dart';

/// Exports gallery assets to the device Photos/DCIM (batch or single), applying
/// each asset's recipe. Grading reuses the exact preview path, and the source
/// EXIF is preserved (#12/#13).
class GalleryExporter {
  const GalleryExporter(this.source);

  final GallerySource source;

  /// Grades and saves one asset with [recipe]; returns the bytes written.
  Future<int> exportAsset(String assetId, EditRecipe recipe) async {
    final src = await source.loadImage(assetId);
    if (src.isEmpty) return 0;

    // RAW/DNG sources go through the Rust RAW decode (already sRGB RGBA8);
    // wide-gamut/EXIF handling below is JPEG-specific.
    final Uint8List rgba;
    final int width;
    final int height;
    var exif = Uint8List(0);
    if (isRawImage(src)) {
      final decoded = await TesseraEngine.decodeRawRgba(src);
      rgba = decoded.rgba;
      width = decoded.width;
      height = decoded.height;
    } else {
      final decoded = await TesseraEngine.decodeJpegRgba(src);
      exif = await TesseraEngine.extractExif(src);
      // Normalize wide-gamut input (Display P3 -> sRGB) so colours are faithful.
      final space = await TesseraEngine.detectColorspace(src);
      rgba = space == 2
          ? await TesseraEngine.p3ToSrgb(
              decoded.rgba,
              width: decoded.width,
              height: decoded.height,
            )
          : decoded.rgba;
      width = decoded.width;
      height = decoded.height;
    }

    final out = await TesseraEngine.exportJpeg(
      rgba: rgba,
      width: width,
      height: height,
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
