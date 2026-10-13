/// The non-destructive edit recipe — the single source of truth every UI shell
/// reads and writes (ARCHITECTURE §16, ADR 0008).
///
/// Versioned JSON. The schema is a **Lightroom-aligned superset**; this first
/// slice models the Light and Color groups. Fields the preview shader cannot
/// yet render (highlights/shadows/whites/blacks/temperature/tint/vibrance) are
/// carried **forward-compatible**: stored, round-tripped and equal-tested, but
/// not yet applied by the renderer.
///
/// Values are neutral-at-zero so an all-zero recipe is an identity transform.
class EditRecipe {
  const EditRecipe({
    this.schemaVersion = currentSchemaVersion,
    this.exposure = 0,
    this.contrast = 0,
    this.highlights = 0,
    this.shadows = 0,
    this.whites = 0,
    this.blacks = 0,
    this.temperature = 0,
    this.tint = 0,
    this.vibrance = 0,
    this.saturation = 0,
  });

  /// Bumped only on a breaking schema change (ARCHITECTURE §16).
  static const int currentSchemaVersion = 1;

  /// All-neutral recipe: applying it is an identity transform.
  static const EditRecipe neutral = EditRecipe();

  final int schemaVersion;

  // Light.
  final double exposure; // EV, neutral 0.
  final double contrast; // unitless, neutral 0.
  final double highlights; // unitless, neutral 0 (not yet rendered).
  final double shadows; // unitless, neutral 0 (not yet rendered).
  final double whites; // unitless, neutral 0 (not yet rendered).
  final double blacks; // unitless, neutral 0 (not yet rendered).

  // Color.
  final double temperature; // unitless, neutral 0 (not yet rendered).
  final double tint; // unitless, neutral 0 (not yet rendered).
  final double vibrance; // unitless, neutral 0 (not yet rendered).
  final double saturation; // unitless, neutral 0.

  /// Returns a copy with the given fields replaced. Fields left `null` keep
  /// their current value; the receiver is never mutated.
  EditRecipe copyWith({
    int? schemaVersion,
    double? exposure,
    double? contrast,
    double? highlights,
    double? shadows,
    double? whites,
    double? blacks,
    double? temperature,
    double? tint,
    double? vibrance,
    double? saturation,
  }) {
    return EditRecipe(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      exposure: exposure ?? this.exposure,
      contrast: contrast ?? this.contrast,
      highlights: highlights ?? this.highlights,
      shadows: shadows ?? this.shadows,
      whites: whites ?? this.whites,
      blacks: blacks ?? this.blacks,
      temperature: temperature ?? this.temperature,
      tint: tint ?? this.tint,
      vibrance: vibrance ?? this.vibrance,
      saturation: saturation ?? this.saturation,
    );
  }

  /// Serialises to a plain JSON-ready map.
  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'exposure': exposure,
    'contrast': contrast,
    'highlights': highlights,
    'shadows': shadows,
    'whites': whites,
    'blacks': blacks,
    'temperature': temperature,
    'tint': tint,
    'vibrance': vibrance,
    'saturation': saturation,
  };

  /// Deserialises from [json], tolerating missing keys (default to neutral) and
  /// ignoring unknown keys so an older reader survives a newer recipe.
  factory EditRecipe.fromJson(Map<String, Object?> json) {
    double asDouble(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return EditRecipe(
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
      exposure: asDouble('exposure'),
      contrast: asDouble('contrast'),
      highlights: asDouble('highlights'),
      shadows: asDouble('shadows'),
      whites: asDouble('whites'),
      blacks: asDouble('blacks'),
      temperature: asDouble('temperature'),
      tint: asDouble('tint'),
      vibrance: asDouble('vibrance'),
      saturation: asDouble('saturation'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EditRecipe &&
      other.schemaVersion == schemaVersion &&
      other.exposure == exposure &&
      other.contrast == contrast &&
      other.highlights == highlights &&
      other.shadows == shadows &&
      other.whites == whites &&
      other.blacks == blacks &&
      other.temperature == temperature &&
      other.tint == tint &&
      other.vibrance == vibrance &&
      other.saturation == saturation;

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    exposure,
    contrast,
    highlights,
    shadows,
    whites,
    blacks,
    Object.hash(temperature, tint, vibrance, saturation),
  );

  @override
  String toString() =>
      'EditRecipe(v$schemaVersion, exposure: $exposure, contrast: $contrast, '
      'saturation: $saturation)';
}
