import 'recipe.dart';

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
  const PresetImport(this.recipe, this.notes);

  final EditRecipe recipe;
  final List<PresetNote> notes;

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

  for (final key in settings.keys) {
    if (!handled.contains(key)) {
      notes.add(PresetNote(key, PresetStatus.unsupported, 'no mapping'));
    }
  }

  return PresetImport(recipe, notes);
}
