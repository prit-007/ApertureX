import 'dart:convert';

import 'recipe.dart';
import 'xmp_crs.dart';

/// Where a preset's "Look" (creative profile/LUT) comes from.
enum PresetLookKind {
  /// No look referenced in the preset.
  none,

  /// A look named by `crs:LookName` (its table lives in a separate file).
  named,

  /// An inline `crs:LookTable` / `crs:ProfileLookTable` base64 blob.
  embedded,
}

/// An embedded or named look found in a preset (ADR 0009 §4).
///
/// Adobe's look/profile tables are a proprietary hue/saturation-encoded format;
/// we surface them for the compatibility report but approximate the render with
/// our own tone/color ops rather than claiming an exact match.
class PresetLook {
  const PresetLook({
    this.kind = PresetLookKind.none,
    this.name,
    this.tableBytes = 0,
  });

  final PresetLookKind kind;
  final String? name;
  final int tableBytes;

  bool get isPresent => kind != PresetLookKind.none;
}

/// How an imported preset setting mapped onto our recipe.
enum PresetStatus { applied, approximated, unsupported }

/// One line of the compatibility report.
class PresetNote {
  const PresetNote(this.setting, this.status, [this.detail = '']);

  final String setting;
  final PresetStatus status;
  final String detail;
}

/// A parsed preset plus the compatibility report (ADR 0009 — fidelity is
/// *measured and reported*, never promised).
class PresetImport {
  const PresetImport(this.recipe, this.notes, {this.look = const PresetLook()});

  final EditRecipe recipe;
  final List<PresetNote> notes;
  final PresetLook look;

  bool get hasUnsupported =>
      notes.any((n) => n.status == PresetStatus.unsupported);
}

/// Extracts Lightroom/ACR settings. Real presets store them as `crs:` **XML
/// attributes** on `<rdf:Description>`; we also accept child elements.
Map<String, String> _extractSettings(String xml) {
  final out = <String, String>{};
  for (final m in RegExp(r'crs:([A-Za-z0-9_]+)\s*=\s*"([^"]*)"').allMatches(xml)) {
    out[m.group(1)!] = m.group(2)!.trim();
  }
  for (final m in RegExp(r'<crs:([A-Za-z0-9_]+)>([^<]*)</crs:\1>').allMatches(xml)) {
    out.putIfAbsent(m.group(1)!, () => m.group(2)!.trim());
  }
  return out;
}

/// Parses a Lightroom `.xmp` preset (best-effort) and reports, per setting,
/// whether it was applied, approximated, or unsupported.
///
/// Scalar fields walk the shared [crsBindings] table (the same table
/// `writeXmp` serialises from, so import → export round-trips), then the
/// composite Crop/Rotation attributes are folded back in.
PresetImport parseXmpPreset(String xml) {
  final settings = _extractSettings(xml);
  final notes = <PresetNote>[];
  var recipe = EditRecipe.neutral;
  final handled = <String>{};

  for (final binding in crsBindings) {
    final raw = settings[binding.key];
    if (raw == null) {
      notes.add(
        PresetNote(binding.label, PresetStatus.unsupported, 'not in preset'),
      );
      continue;
    }
    handled.add(binding.key);
    recipe = binding.set(recipe, binding.fromCrs(double.tryParse(raw) ?? 0));
    notes.add(
      PresetNote(
        binding.label,
        binding.approximated
            ? PresetStatus.approximated
            : PresetStatus.applied,
        raw,
      ),
    );
  }

  // Crop: four normalized corners written together (see writeXmp). HasCrop is
  // absorbed silently — it only tells ACR the corners are active.
  if (settings.containsKey('HasCrop')) handled.add('HasCrop');
  final cropValues = <double>[];
  for (final key in crsCropKeys) {
    final raw = settings[key];
    if (raw == null) continue;
    handled.add(key);
    cropValues.add((double.tryParse(raw) ?? 0).clamp(0.0, 1.0).toDouble());
  }
  if (cropValues.length == crsCropKeys.length) {
    recipe = recipe.copyWith(crop: cropValues);
    notes.add(
      PresetNote(
        'Crop',
        PresetStatus.applied,
        cropValues.map((v) => v.toStringAsFixed(2)).join(', '),
      ),
    );
  } else if (cropValues.isNotEmpty) {
    notes.add(const PresetNote('Crop', PresetStatus.unsupported, 'incomplete'));
  } else {
    notes.add(
      const PresetNote('Crop', PresetStatus.unsupported, 'not in preset'),
    );
  }

  // Rotation: one Lightroom-style angle carrying quarter turns + straighten.
  final rotationRaw = settings['Rotation'];
  if (rotationRaw == null) {
    notes.add(
      const PresetNote('Rotation', PresetStatus.unsupported, 'not in preset'),
    );
  } else {
    handled.add('Rotation');
    final (quarter, straighten) = rotationFromDegrees(
      double.tryParse(rotationRaw) ?? 0,
    );
    recipe = recipe.copyWith(
      rotation: quarter,
      straighten: straighten.clamp(-45.0, 45.0).toDouble(),
    );
    notes.add(PresetNote('Rotation', PresetStatus.applied, rotationRaw));
  }

  final look = _extractLook(settings, handled, notes);

  for (final key in settings.keys) {
    if (!handled.contains(key)) {
      notes.add(PresetNote(key, PresetStatus.unsupported, 'no mapping'));
    }
  }

  return PresetImport(recipe, notes, look: look);
}

/// Reads the preset's look: an inline base64 `crs:LookTable` /
/// `crs:ProfileLookTable`, or a `crs:LookName` reference (ADR 0009 §4).
PresetLook _extractLook(
  Map<String, String> settings,
  Set<String> handled,
  List<PresetNote> notes,
) {
  final table = settings['LookTable'] ?? settings['ProfileLookTable'];
  final name = settings['LookName'];

  if (table == null && name == null) return const PresetLook();

  for (final key in const ['LookName', 'LookTable', 'ProfileLookTable']) {
    if (settings.containsKey(key)) handled.add(key);
  }
  handled.add('LookAmount');

  if (table != null) {
    final bytes = _base64Length(table);
    notes.add(
      PresetNote(
        'Look',
        PresetStatus.approximated,
        'embedded look table (${bytes}B) approximated by our color ops',
      ),
    );
    return PresetLook(
      kind: PresetLookKind.embedded,
      name: name,
      tableBytes: bytes,
    );
  }

  notes.add(
    PresetNote(
      'Look',
      PresetStatus.approximated,
      'named look "$name" approximated by our color ops',
    ),
  );
  return PresetLook(kind: PresetLookKind.named, name: name);
}

int _base64Length(String encoded) {
  try {
    return base64.decode(encoded.replaceAll(RegExp(r'\s'), '')).length;
  } on FormatException {
    return 0;
  }
}
