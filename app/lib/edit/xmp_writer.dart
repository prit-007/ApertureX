import 'package:flutter/foundation.dart' show listEquals;

import 'recipe.dart';
import 'xmp_crs.dart';

/// Serialises an [EditRecipe] to a Lightroom/Capture One/darktable-readable
/// `.xmp` document (#77 — the anti-lock-in direction of the existing preset
/// importer: edits can leave the app in a form other tools open).
///
/// Every mapping comes from the shared [crsBindings] table, so
/// `parseXmpPreset(writeXmp(recipe))` round-trips the supported subset by
/// construction (the killer test in `xmp_writer_test.dart`). Attributes the
/// recipe has no Lightroom counterpart for (curves, HSL, masks, film physics…)
/// are simply not part of the XMP subset — those stay in the
/// `.aperturex.json` sidecar, which is schema-complete.
String writeXmp(EditRecipe recipe) {
  final attrs = <String>[];
  for (final binding in crsBindings) {
    attrs.add('    crs:${binding.key}="${_fmt(binding.toCrs(binding.get(recipe)))}"');
  }

  // Crop corners are always written (even the full frame) so the reader never
  // reports a "not in preset" gap for them; HasCrop is only set when the rect
  // actually crops — ACR ignores corners without it, which is exactly the
  // right behaviour for the neutral full frame.
  final crop = recipe.crop;
  for (var i = 0; i < crsCropKeys.length; i++) {
    attrs.add('    crs:${crsCropKeys[i]}="${_fmt(crop[i])}"');
  }
  if (!listEquals(crop, fullCrop)) {
    attrs.add('    crs:HasCrop="True"');
  }

  attrs.add(
    '    crs:Rotation="${_fmt(rotationDegrees(recipe.rotation, recipe.straighten))}"',
  );

  return '''
<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="ApertureX">
 <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about=""
    xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/"
${attrs.join('\n')}
  />
 </rdf:RDF>
</x:xmpmeta>
''';
}

/// Formats a Lightroom attribute value: 12 significant digits (so the writer
/// is lossless enough for an exact round-trip while keeping sidecars
/// human-readable — `33`, not `33.000000000000004`), trailing zeros trimmed,
/// plain decimal (XMP reals, not Dart's `e` notation, whenever the value
/// allows it).
String _fmt(double value) {
  if (value == 0) return '0'; // also normalises -0.0
  var s = value.toStringAsPrecision(12);
  if (!s.contains('e') && s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}
