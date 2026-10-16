import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/xmp_preset.dart';
import 'package:aperturex/edit/xmp_writer.dart';

void main() {
  /// The #77 supported subset: every field the issue's writer mapping lists,
  /// plus Texture (already imported today) — all exercised at once.
  EditRecipe subsetRecipe() => EditRecipe.neutral.copyWith(
    exposure: 0.5,
    contrast: 0.33,
    highlights: 0.12,
    shadows: -0.21,
    whites: 0.15,
    blacks: -0.25,
    clarity: 0.4,
    texture: 0.35,
    dehaze: 0.2,
    vignette: 0.6,
    vignetteMidpoint: 0.35,
    vignetteFeather: 0.7,
    vignetteRoundness: -0.4,
    vignetteHighlights: 0.3,
    grain: 0.4,
    grainSize: 0.6,
    grainRoughness: 0.3,
    temperature: 0.25,
    tint: -0.15,
    vibrance: 0.45,
    saturation: -0.2,
    rotation: 1,
    straighten: 12.5,
    crop: [0.1, 0.05, 0.9, 0.95],
  );

  test('killer round-trip: parseXmpPreset(writeXmp(recipe)) with an empty report', () {
    final original = subsetRecipe();
    final import = parseXmpPreset(writeXmp(original));

    expect(
      import.hasUnsupported,
      isFalse,
      reason:
          'compatibility report must be empty, got: '
          '${import.notes.where((n) => n.status == PresetStatus.unsupported).map((n) => '${n.setting} (${n.detail})')}',
    );

    final r = import.recipe;
    // Scale-1 fields are exact; scaled ones within float noise of the
    // 12-significant-digit writer format.
    expect(r.exposure, original.exposure);
    expect(r.rotation, original.rotation);
    expect(r.contrast, closeTo(original.contrast, 1e-9));
    expect(r.highlights, closeTo(original.highlights, 1e-9));
    expect(r.shadows, closeTo(original.shadows, 1e-9));
    expect(r.whites, closeTo(original.whites, 1e-9));
    expect(r.blacks, closeTo(original.blacks, 1e-9));
    expect(r.clarity, closeTo(original.clarity, 1e-9));
    expect(r.texture, closeTo(original.texture, 1e-9));
    expect(r.dehaze, closeTo(original.dehaze, 1e-9));
    expect(r.vignette, closeTo(original.vignette, 1e-9));
    expect(r.vignetteMidpoint, closeTo(original.vignetteMidpoint, 1e-9));
    expect(r.vignetteFeather, closeTo(original.vignetteFeather, 1e-9));
    expect(r.vignetteRoundness, closeTo(original.vignetteRoundness, 1e-9));
    expect(r.vignetteHighlights, closeTo(original.vignetteHighlights, 1e-9));
    expect(r.grain, closeTo(original.grain, 1e-9));
    expect(r.grainSize, closeTo(original.grainSize, 1e-9));
    expect(r.grainRoughness, closeTo(original.grainRoughness, 1e-9));
    expect(r.temperature, closeTo(original.temperature, 1e-9));
    expect(r.tint, closeTo(original.tint, 1e-9));
    expect(r.vibrance, closeTo(original.vibrance, 1e-9));
    expect(r.saturation, closeTo(original.saturation, 1e-9));
    expect(r.straighten, closeTo(original.straighten, 1e-9));
    for (var i = 0; i < 4; i++) {
      expect(r.crop[i], closeTo(original.crop[i], 1e-9), reason: 'crop[$i]');
    }
  });

  test('a neutral recipe round-trips to neutral with an empty report', () {
    final import = parseXmpPreset(writeXmp(EditRecipe.neutral));
    expect(import.hasUnsupported, isFalse);
    final r = import.recipe;
    expect(r.exposure, 0);
    expect(r.contrast, 0);
    expect(r.vignette, 0);
    expect(r.vignetteMidpoint, 0.5);
    expect(r.grain, 0);
    expect(r.grainSize, 0.25);
    expect(r.grainRoughness, 0.5);
    expect(r.temperature, 0);
    expect(r.tint, 0);
    expect(r.rotation, 0);
    expect(r.straighten, 0);
    expect(r.crop, fullCrop);
  });

  test('emits a real XMP envelope in the crs namespace', () {
    final xml = writeXmp(subsetRecipe());
    expect(xml, contains('<x:xmpmeta'));
    expect(xml, contains('<rdf:RDF'));
    expect(
      xml,
      contains('xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/"'),
    );
    expect(xml, contains('crs:Exposure2012="0.5"'));
    expect(xml, contains('crs:Contrast2012="33"'));
  });

  test('vignette sign matches Lightroom (a negative amount darkens)', () {
    final xml = writeXmp(EditRecipe.neutral.copyWith(vignette: 0.6));
    expect(xml, contains('crs:PostCropVignetteAmount="-60"'));
    expect(parseXmpPreset(xml).recipe.vignette, closeTo(0.6, 1e-9));
  });

  test('rotation folds quarter turns and straighten into crs:Rotation degrees', () {
    final xml = writeXmp(
      EditRecipe.neutral.copyWith(rotation: 1, straighten: 12.5),
    );
    expect(xml, contains('crs:Rotation="102.5"'));
    final r = parseXmpPreset(xml).recipe;
    expect(r.rotation, 1);
    expect(r.straighten, closeTo(12.5, 1e-9));
  });

  test('crop corners are always written; HasCrop only when cropped', () {
    final neutralXml = writeXmp(EditRecipe.neutral);
    expect(neutralXml, contains('crs:CropLeft="0"'));
    expect(neutralXml, contains('crs:CropTop="0"'));
    expect(neutralXml, contains('crs:CropRight="1"'));
    expect(neutralXml, contains('crs:CropBottom="1"'));
    expect(neutralXml, isNot(contains('HasCrop')));

    final cropped = <double>[0.1, 0, 1, 0.9];
    final croppedXml = writeXmp(EditRecipe.neutral.copyWith(crop: cropped));
    expect(croppedXml, contains('crs:HasCrop="True"'));
    expect(parseXmpPreset(croppedXml).recipe.crop, cropped);
  });
}
