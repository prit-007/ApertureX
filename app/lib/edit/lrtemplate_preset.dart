import 'dart:convert';

import 'recipe.dart';
import 'tone_curve.dart';
import 'xmp_crs.dart';
import 'xmp_preset.dart';

/// Legacy aliases for basic sliders in pre-PV2012 presets.
const Map<String, List<String>> _legacyAliases = {
  'Exposure2012': ['Exposure'],
  'Contrast2012': ['Contrast'],
  'Highlights2012': ['Highlights', 'HighlightRecovery'],
  'Shadows2012': ['Shadows', 'FillLight'],
  'Whites2012': ['Whites'],
  'Blacks2012': ['Blacks'],
  'Clarity2012': ['Clarity'],
};

/// 8 color bands in Lightroom HSL order.
const List<String> _hslBands = [
  'Red',
  'Orange',
  'Yellow',
  'Green',
  'Aqua',
  'Blue',
  'Purple',
  'Magenta',
];

/// Metadata and switch keys to absorb without polluting the unsupported report.
const Set<String> _absorbedKeys = {
  'id',
  'internalName',
  'title',
  'type',
  'version',
  'ProcessVersion',
  'uuid',
  'EnableColorAdjustments',
  'EnableSplitToning',
  'EnableDetail',
  'EnableToneCurve',
  'EnableCircularGradientBasedCorrections',
  'EnableGradientBasedCorrections',
  'AutoExposure',
  'AutoContrast',
  'AutoShadows',
  'AutoBrightness',
  'ToneCurveName',
  'ToneCurveName2012',
  'HasCrop',
};

/// Parses a classic Lightroom `.lrtemplate` preset (Lua table format) and
/// returns a [PresetImport] with the resulting [EditRecipe] and compatibility
/// report notes (ADR 0009).
PresetImport parseLrtemplatePreset(String content) {
  final notes = <PresetNote>[];
  if (content.trim().isEmpty) {
    return PresetImport(EditRecipe.neutral, notes);
  }

  final Map<String, dynamic> rawSettings;
  try {
    final parsed = LuaParser(content).parse();
    rawSettings = _findSettingsMap(parsed);
  } catch (_) {
    // Malformed input fails gracefully into neutral recipe with error note
    return const PresetImport(
      EditRecipe.neutral,
      [PresetNote('Syntax', PresetStatus.unsupported, 'Malformed Lua table')],
    );
  }

  if (rawSettings.isEmpty) {
    return PresetImport(EditRecipe.neutral, notes);
  }

  var recipe = EditRecipe.neutral;
  final handled = <String>{};

  // 1. Walk crsBindings (Basic, Vignette, Grain, Temp, Tint).
  for (final binding in crsBindings) {
    dynamic val = rawSettings[binding.key];
    String matchedKey = binding.key;

    if (val == null && _legacyAliases.containsKey(binding.key)) {
      for (final alias in _legacyAliases[binding.key]!) {
        if (rawSettings.containsKey(alias)) {
          val = rawSettings[alias];
          matchedKey = alias;
          break;
        }
      }
    }

    if (val == null) {
      notes.add(
        PresetNote(binding.label, PresetStatus.unsupported, 'not in preset'),
      );
      continue;
    }

    handled.add(matchedKey);
    final numVal = double.tryParse(val.toString()) ?? 0.0;
    recipe = binding.set(recipe, binding.fromCrs(numVal));
    notes.add(
      PresetNote(
        binding.label,
        binding.approximated ? PresetStatus.approximated : PresetStatus.applied,
        val.toString(),
      ),
    );
  }

  // 2. Detail & Noise
  final sharpness = _findNum(rawSettings, ['Sharpness', 'SharpenAmount']);
  if (sharpness != null) {
    handled.addAll(['Sharpness', 'SharpenAmount']);
    recipe = recipe.copyWith(sharpen: (sharpness * 0.01).clamp(0.0, 1.0));
    notes.add(PresetNote('Sharpen', PresetStatus.applied, sharpness.toString()));
  }

  final sharpRadius = _findNum(rawSettings, ['SharpenRadius']);
  if (sharpRadius != null) {
    handled.add('SharpenRadius');
    recipe = recipe.copyWith(sharpenRadius: sharpRadius.clamp(0.5, 3.0));
  }

  final sharpDetail = _findNum(rawSettings, ['SharpenDetail']);
  if (sharpDetail != null) {
    handled.add('SharpenDetail');
    recipe = recipe.copyWith(sharpenDetail: (sharpDetail * 0.01).clamp(0.0, 1.0));
  }

  final sharpMasking = _findNum(rawSettings, ['SharpenEdgeMasking']);
  if (sharpMasking != null) {
    handled.add('SharpenEdgeMasking');
    recipe = recipe.copyWith(sharpenMasking: (sharpMasking * 0.01).clamp(0.0, 1.0));
  }

  final lumaDenoise = _findNum(rawSettings, ['LuminanceSmoothing']);
  if (lumaDenoise != null) {
    handled.add('LuminanceSmoothing');
    recipe = recipe.copyWith(denoiseLuma: (lumaDenoise * 0.01).clamp(0.0, 1.0));
    notes.add(PresetNote('Luminance Noise', PresetStatus.applied, lumaDenoise.toString()));
  }

  final chromaDenoise = _findNum(rawSettings, ['ColorNoiseReduction']);
  if (chromaDenoise != null) {
    handled.add('ColorNoiseReduction');
    recipe = recipe.copyWith(denoiseChroma: (chromaDenoise * 0.01).clamp(0.0, 1.0));
    notes.add(PresetNote('Color Noise', PresetStatus.applied, chromaDenoise.toString()));
  }

  // 3. Color Grading / Split Toning
  final splitHighHue = _findNum(rawSettings, ['SplitToningHighlightHue']);
  final splitHighSat = _findNum(rawSettings, ['SplitToningHighlightSaturation']);
  final splitShadowHue = _findNum(rawSettings, ['SplitToningShadowHue']);
  final splitShadowSat = _findNum(rawSettings, ['SplitToningShadowSaturation']);
  final splitBalance = _findNum(rawSettings, ['SplitToningBalance']);

  if (splitHighHue != null || splitShadowHue != null) {
    handled.addAll([
      'SplitToningHighlightHue',
      'SplitToningHighlightSaturation',
      'SplitToningShadowHue',
      'SplitToningShadowSaturation',
      'SplitToningBalance',
    ]);
    recipe = recipe.copyWith(
      gradeHighlightHue: splitHighHue != null ? (splitHighHue / 360.0).clamp(0.0, 1.0) : 0.0,
      gradeHighlightSat: splitHighSat != null ? (splitHighSat / 100.0).clamp(0.0, 1.0) : 0.0,
      gradeShadowHue: splitShadowHue != null ? (splitShadowHue / 360.0).clamp(0.0, 1.0) : 0.0,
      gradeShadowSat: splitShadowSat != null ? (splitShadowSat / 100.0).clamp(0.0, 1.0) : 0.0,
      gradeBalance: splitBalance != null ? (splitBalance / 100.0).clamp(-1.0, 1.0) : 0.0,
    );
    notes.add(const PresetNote('Split Toning', PresetStatus.applied));
  }

  // Modern ColorGrade wheels
  final cgMidHue = _findNum(rawSettings, ['ColorGradeMidtoneHue']);
  final cgMidSat = _findNum(rawSettings, ['ColorGradeMidtoneSat']);
  final cgMidLum = _findNum(rawSettings, ['ColorGradeMidtoneLum']);
  final cgShadowLum = _findNum(rawSettings, ['ColorGradeShadowLum']);
  final cgHighlightLum = _findNum(rawSettings, ['ColorGradeHighlightLum']);
  final cgBlending = _findNum(rawSettings, ['ColorGradeBlending']);

  if (cgMidHue != null || cgMidSat != null || cgMidLum != null) {
    handled.addAll([
      'ColorGradeMidtoneHue',
      'ColorGradeMidtoneSat',
      'ColorGradeMidtoneLum',
      'ColorGradeShadowLum',
      'ColorGradeHighlightLum',
      'ColorGradeBlending',
    ]);
    recipe = recipe.copyWith(
      gradeMidHue: cgMidHue != null ? (cgMidHue / 360.0).clamp(0.0, 1.0) : recipe.gradeMidHue,
      gradeMidSat: cgMidSat != null ? (cgMidSat / 100.0).clamp(0.0, 1.0) : recipe.gradeMidSat,
      gradeMidLum: cgMidLum != null ? (cgMidLum / 100.0).clamp(-1.0, 1.0) : recipe.gradeMidLum,
      gradeShadowLum: cgShadowLum != null ? (cgShadowLum / 100.0).clamp(-1.0, 1.0) : recipe.gradeShadowLum,
      gradeHighlightLum: cgHighlightLum != null ? (cgHighlightLum / 100.0).clamp(-1.0, 1.0) : recipe.gradeHighlightLum,
      gradeBlending: cgBlending != null ? (cgBlending / 100.0).clamp(0.0, 1.0) : recipe.gradeBlending,
    );
  }

  // 4. Tone Curves
  final masterCurveData = rawSettings['ToneCurvePV2012'] ?? rawSettings['ToneCurve'];
  if (masterCurveData != null) {
    handled.addAll(['ToneCurvePV2012', 'ToneCurve']);
    final curve = _parseCurve(masterCurveData);
    if (curve != null) {
      recipe = recipe.copyWith(masterCurve: curve);
      notes.add(PresetNote('Tone Curve', PresetStatus.applied, '${curve.points.length ~/ 2} points'));
    }
  }

  final redCurveData = rawSettings['ToneCurvePV2012Red'] ?? rawSettings['ToneCurveRed'];
  if (redCurveData != null) {
    handled.addAll(['ToneCurvePV2012Red', 'ToneCurveRed']);
    final curve = _parseCurve(redCurveData);
    if (curve != null) recipe = recipe.copyWith(redCurve: curve);
  }

  final greenCurveData = rawSettings['ToneCurvePV2012Green'] ?? rawSettings['ToneCurveGreen'];
  if (greenCurveData != null) {
    handled.addAll(['ToneCurvePV2012Green', 'ToneCurveGreen']);
    final curve = _parseCurve(greenCurveData);
    if (curve != null) recipe = recipe.copyWith(greenCurve: curve);
  }

  final blueCurveData = rawSettings['ToneCurvePV2012Blue'] ?? rawSettings['ToneCurveBlue'];
  if (blueCurveData != null) {
    handled.addAll(['ToneCurvePV2012Blue', 'ToneCurveBlue']);
    final curve = _parseCurve(blueCurveData);
    if (curve != null) recipe = recipe.copyWith(blueCurve: curve);
  }

  // 5. HSL
  var hasHsl = false;
  final hsl = List<double>.from(recipe.hsl);
  for (var i = 0; i < _hslBands.length; i++) {
    final band = _hslBands[i];
    final hue = _findNum(rawSettings, ['HueAdjustment$band']);
    final sat = _findNum(rawSettings, ['SaturationAdjustment$band']);
    final lum = _findNum(rawSettings, ['LuminanceAdjustment$band']);

    if (hue != null) {
      handled.add('HueAdjustment$band');
      hsl[i * 3 + 0] = (hue / 100.0).clamp(-1.0, 1.0);
      hasHsl = true;
    }
    if (sat != null) {
      handled.add('SaturationAdjustment$band');
      hsl[i * 3 + 1] = (sat / 100.0).clamp(-1.0, 1.0);
      hasHsl = true;
    }
    if (lum != null) {
      handled.add('LuminanceAdjustment$band');
      hsl[i * 3 + 2] = (lum / 100.0).clamp(-1.0, 1.0);
      hasHsl = true;
    }
  }
  if (hasHsl) {
    recipe = recipe.copyWith(hsl: hsl);
    notes.add(const PresetNote('HSL', PresetStatus.applied, '8 bands'));
  }

  // 6. Crop & Rotation
  final cropValues = <double>[];
  for (final key in crsCropKeys) {
    final raw = rawSettings[key];
    if (raw == null) continue;
    handled.add(key);
    final numVal = double.tryParse(raw.toString()) ?? 0.0;
    cropValues.add(numVal.clamp(0.0, 1.0));
  }
  if (cropValues.length == crsCropKeys.length) {
    recipe = recipe.copyWith(crop: cropValues);
    notes.add(PresetNote('Crop', PresetStatus.applied, cropValues.map((v) => v.toStringAsFixed(2)).join(', ')));
  } else if (cropValues.isNotEmpty) {
    notes.add(const PresetNote('Crop', PresetStatus.unsupported, 'incomplete'));
  }

  final rotationRaw = rawSettings['Rotation'] ?? rawSettings['CropAngle'];
  if (rotationRaw != null) {
    handled.addAll(['Rotation', 'CropAngle']);
    final angle = double.tryParse(rotationRaw.toString()) ?? 0.0;
    final (quarter, straighten) = rotationFromDegrees(angle);
    recipe = recipe.copyWith(
      rotation: quarter,
      straighten: straighten.clamp(-45.0, 45.0).toDouble(),
    );
    notes.add(PresetNote('Rotation', PresetStatus.applied, rotationRaw.toString()));
  }

  // 7. Looks
  final look = _extractLook(rawSettings, handled, notes);

  // 8. Unsupported / Unknown keys
  for (final key in rawSettings.keys) {
    if (!handled.contains(key) && !_absorbedKeys.contains(key)) {
      notes.add(PresetNote(key, PresetStatus.unsupported, 'no mapping'));
    }
  }

  return PresetImport(recipe, notes, look: look);
}

ToneCurve? _parseCurve(dynamic data) {
  if (data is! List) return null;
  final points = <double>[];
  for (final item in data) {
    final numVal = double.tryParse(item.toString());
    if (numVal == null) return null;
    points.add((numVal / 255.0).clamp(0.0, 1.0));
  }
  if (points.length < 4 || points.length % 2 != 0) return null;
  return ToneCurve(points);
}

double? _findNum(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    if (map.containsKey(key) && map[key] != null) {
      final v = double.tryParse(map[key].toString());
      if (v != null) return v;
    }
  }
  return null;
}

PresetLook _extractLook(
  Map<String, dynamic> settings,
  Set<String> handled,
  List<PresetNote> notes,
) {
  final table = settings['LookTable']?.toString() ?? settings['ProfileLookTable']?.toString();
  final name = settings['LookName']?.toString();

  if (table == null && name == null) return const PresetLook();

  for (final key in const ['LookName', 'LookTable', 'ProfileLookTable', 'LookAmount']) {
    if (settings.containsKey(key)) handled.add(key);
  }

  if (table != null) {
    final bytes = _base64Length(table);
    notes.add(
      PresetNote(
        'Look',
        PresetStatus.approximated,
        'embedded look table (${bytes}B) approximated by our color ops',
      ),
    );
    return PresetLook(kind: PresetLookKind.embedded, name: name, tableBytes: bytes);
  }

  notes.add(
    PresetNote('Look', PresetStatus.approximated, 'named look "$name" approximated by our color ops'),
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

Map<String, dynamic> _findSettingsMap(dynamic parsed) {
  if (parsed is! Map<String, dynamic>) return const {};
  if (parsed['settings'] is Map<String, dynamic>) {
    return parsed['settings'] as Map<String, dynamic>;
  }
  if (parsed['value'] is Map<String, dynamic>) {
    final val = parsed['value'] as Map<String, dynamic>;
    if (val['settings'] is Map<String, dynamic>) {
      return val['settings'] as Map<String, dynamic>;
    }
    return val;
  }
  for (final v in parsed.values) {
    if (v is Map<String, dynamic>) {
      if (v['settings'] is Map<String, dynamic>) {
        return v['settings'] as Map<String, dynamic>;
      }
    }
  }
  return parsed;
}

/// A lightweight, fault-tolerant recursive-descent Lua table parser.
class LuaParser {
  LuaParser(this.source);

  final String source;
  int _pos = 0;

  dynamic parse() {
    _skipWhitespaceAndComments();
    if (_pos >= source.length) return const <String, dynamic>{};

    // If file starts with `s = {` or `return {` or `var = {`, skip until table or parse table
    while (_pos < source.length) {
      if (source[_pos] == '{') {
        return _parseTable();
      }
      if (source[_pos] == '=') {
        _pos++;
        _skipWhitespaceAndComments();
        if (_pos < source.length && source[_pos] == '{') {
          return _parseTable();
        }
      } else {
        _pos++;
      }
    }
    return const <String, dynamic>{};
  }

  dynamic _parseValue() {
    _skipWhitespaceAndComments();
    if (_pos >= source.length) return null;

    final char = source[_pos];
    if (char == '{') {
      return _parseTable();
    }
    if (char == '"' || char == "'") {
      return _parseString();
    }
    if (char == '[' && _pos + 1 < source.length && source[_pos + 1] == '[') {
      return _parseMultilineString();
    }
    if (char == '-' || (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57)) {
      return _parseNumber();
    }
    if (_isIdentifierStart(char)) {
      final ident = _parseIdentifier();
      if (ident == 'true') return true;
      if (ident == 'false') return false;
      if (ident == 'nil') return null;
      return ident;
    }
    return null;
  }

  dynamic _parseTable() {
    _pos++; // Skip '{'
    _skipWhitespaceAndComments();

    final map = <String, dynamic>{};
    final list = <dynamic>[];
    var isMap = false;

    while (_pos < source.length) {
      _skipWhitespaceAndComments();
      if (_pos >= source.length) break;
      if (source[_pos] == '}') {
        _pos++;
        break;
      }

      // Check key syntax:
      // 1) `["key"] = val`
      // 2) `key = val`
      // 3) `val` (list element)
      String? key;
      final savedPos = _pos;

      if (source[_pos] == '[') {
        _pos++;
        _skipWhitespaceAndComments();
        final rawKey = _parseValue();
        _skipWhitespaceAndComments();
        if (_pos < source.length && source[_pos] == ']') {
          _pos++;
          _skipWhitespaceAndComments();
          if (_pos < source.length && source[_pos] == '=') {
            _pos++;
            key = rawKey.toString();
          }
        }
      } else if (_isIdentifierStart(source[_pos])) {
        final ident = _parseIdentifier();
        _skipWhitespaceAndComments();
        if (_pos < source.length && source[_pos] == '=') {
          _pos++;
          key = ident;
        } else {
          // It was not a key, rollback to parse as value
          _pos = savedPos;
        }
      }

      if (key != null) {
        isMap = true;
        final value = _parseValue();
        map[key] = value;
      } else {
        final value = _parseValue();
        if (value != null) {
          list.add(value);
        }
      }

      _skipWhitespaceAndComments();
      if (_pos < source.length && (source[_pos] == ',' || source[_pos] == ';')) {
        _pos++;
      }
    }

    if (!isMap && list.isNotEmpty) {
      return list;
    }
    if (list.isNotEmpty) {
      for (var i = 0; i < list.length; i++) {
        map[(i + 1).toString()] = list[i];
      }
    }
    return map;
  }

  String _parseString() {
    final quote = source[_pos];
    _pos++;
    final sb = StringBuffer();
    while (_pos < source.length) {
      final c = source[_pos++];
      if (c == quote) break;
      if (c == '\\' && _pos < source.length) {
        final escaped = source[_pos++];
        switch (escaped) {
          case 'n':
            sb.write('\n');
          case 'r':
            sb.write('\r');
          case 't':
            sb.write('\t');
          default:
            sb.write(escaped);
        }
      } else {
        sb.write(c);
      }
    }
    return sb.toString();
  }

  String _parseMultilineString() {
    _pos += 2; // skip '[['
    final end = source.indexOf(']]', _pos);
    if (end == -1) {
      final res = source.substring(_pos);
      _pos = source.length;
      return res;
    }
    final res = source.substring(_pos, end);
    _pos = end + 2;
    return res;
  }

  num _parseNumber() {
    final start = _pos;
    if (source[_pos] == '-') _pos++;
    while (_pos < source.length) {
      final c = source.codeUnitAt(_pos);
      if ((c >= 48 && c <= 57) || c == 46 || c == 101 || c == 69 || c == 43 || c == 45) {
        _pos++;
      } else {
        break;
      }
    }
    final text = source.substring(start, _pos);
    return num.tryParse(text) ?? 0;
  }

  String _parseIdentifier() {
    final start = _pos;
    while (_pos < source.length && _isIdentifierPart(source[_pos])) {
      _pos++;
    }
    return source.substring(start, _pos);
  }

  bool _isIdentifierStart(String char) {
    final c = char.codeUnitAt(0);
    return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95;
  }

  bool _isIdentifierPart(String char) {
    final c = char.codeUnitAt(0);
    return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 95;
  }

  void _skipWhitespaceAndComments() {
    while (_pos < source.length) {
      final c = source[_pos];
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
        _pos++;
        continue;
      }
      if (c == '-' && _pos + 1 < source.length && source[_pos + 1] == '-') {
        _pos += 2;
        if (_pos + 1 < source.length && source[_pos] == '[' && source[_pos + 1] == '[') {
          // Block comment
          _pos += 2;
          final end = source.indexOf(']]', _pos);
          if (end == -1) {
            _pos = source.length;
          } else {
            _pos = end + 2;
          }
        } else {
          // Line comment
          while (_pos < source.length && source[_pos] != '\n') {
            _pos++;
          }
        }
        continue;
      }
      break;
    }
  }
}
