import 'dart:convert';

import 'recipe.dart';

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
PresetImport parseXmpPreset(String xml) {
  final settings = _extractSettings(xml);
  final notes = <PresetNote>[];
  var recipe = EditRecipe.neutral;
  final handled = <String>{};

  /// Reads [key] (Lightroom scale → ours via [scale]) and records a note.
  void apply(
    String key,
    String label,
    double scale,
    EditRecipe Function(EditRecipe, double) set, {
    bool approximated = false,
    double? min,
    double? max,
  }) {
    final raw = settings[key];
    if (raw == null) {
      notes.add(PresetNote(label, PresetStatus.unsupported, 'not in preset'));
      return;
    }
    handled.add(key);
    var v = (double.tryParse(raw) ?? 0) * scale;
    if (min != null || max != null) {
      v = v.clamp(min ?? -1e9, max ?? 1e9);
    }
    recipe = set(recipe, v);
    notes.add(
      PresetNote(
        label,
        approximated ? PresetStatus.approximated : PresetStatus.applied,
        raw,
      ),
    );
  }

  apply('Exposure2012', 'Exposure', 1, (r, v) => r.copyWith(exposure: v));
  apply('Contrast2012', 'Contrast', 0.01, (r, v) => r.copyWith(contrast: v));
  apply('Highlights2012', 'Highlights', 0.01, (r, v) => r.copyWith(highlights: v));
  apply('Shadows2012', 'Shadows', 0.01, (r, v) => r.copyWith(shadows: v));
  apply('Whites2012', 'Whites', 0.01, (r, v) => r.copyWith(whites: v));
  apply('Blacks2012', 'Blacks', 0.01, (r, v) => r.copyWith(blacks: v));
  apply('Vibrance', 'Vibrance', 0.01, (r, v) => r.copyWith(vibrance: v));
  apply('Saturation', 'Saturation', 0.01, (r, v) => r.copyWith(saturation: v));
  apply('Clarity2012', 'Clarity', 0.01, (r, v) => r.copyWith(clarity: v));
  apply('Texture', 'Texture', 0.01, (r, v) => r.copyWith(texture: v));
  apply(
    'Tint',
    'Tint',
    0.0067,
    (r, v) => r.copyWith(tint: v),
    min: -1,
    max: 1,
  );
  // Temperature is an absolute Kelvin value in Lightroom; we approximate it as
  // a relative -1..1 shift.
  apply(
    'Temperature',
    'Temperature',
    0.0002,
    (r, v) => r.copyWith(temperature: v),
    approximated: true,
    min: -1,
    max: 1,
  );

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
