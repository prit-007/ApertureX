import 'dart:convert';
import 'dart:io';

import 'parameter.dart';
import 'recipe.dart';
import 'tool_definition.dart';

/// Shorthand mappings for compact QR code payloads (spec in docs/LOOK_QR_STANDARD.md).
const Map<String, String> _paramToShorthand = {
  'exposure': 'exp',
  'contrast': 'con',
  'highlights': 'high',
  'shadows': 'shad',
  'whites': 'whi',
  'blacks': 'bla',
  'temperature': 'temp',
  'tint': 'tint',
  'vibrance': 'vib',
  'saturation': 'sat',
  'clarity': 'cla',
  'texture': 'tex',
  'dehaze': 'deh',
  'vignette': 'vig',
  'grain': 'gra',
  'sharpen': 'sha',
  'filmHalation': 'hal',
  'filmBloom': 'blo',
  'gradeShadowHue': 'gsh',
  'gradeShadowSat': 'gss',
  'gradeShadowLum': 'gsl',
  'gradeMidHue': 'gmh',
  'gradeMidSat': 'gms',
  'gradeMidLum': 'gml',
  'gradeHighlightHue': 'ghh',
  'gradeHighlightSat': 'ghs',
  'gradeHighlightLum': 'ghl',
};

final Map<String, String> _shorthandToParam = {
  for (final e in _paramToShorthand.entries) e.value: e.key,
};

/// Decoded payload from an ApertureX Look QR code, URI, or JSON.
class LookQrPayload {
  const LookQrPayload({
    required this.name,
    this.author,
    this.description,
    required this.params,
    this.curves,
  });

  final String name;
  final String? author;
  final String? description;
  final Map<String, double> params;
  final Map<String, List<List<double>>>? curves;

  /// Converts this payload to a [ToolDefinition].
  ToolDefinition toToolDefinition() => ToolDefinition(
        name: name,
        description: description ?? (author != null ? 'By $author' : ''),
        params: params,
      );

  /// Applies this look onto an existing [EditRecipe].
  EditRecipe applyTo(EditRecipe base) {
    var recipe = base;
    for (final entry in params.entries) {
      final parameter = _findParameter(entry.key);
      if (parameter != null) {
        recipe = withValue(recipe, parameter, entry.value);
      }
    }
    return recipe;
  }
}

/// Open Standard Codec for ApertureX Look QR codes (ADR 0009 follow-up).
class LookQrCodec {
  const LookQrCodec._();

  static const String uriScheme = 'apx';
  static const String uriHostPath = 'look/v1';

  /// Encodes a [ToolDefinition] into an `apx://look/v1` compressed URI for QR codes.
  static String encodeToUri(
    ToolDefinition tool, {
    String? author,
    bool compress = true,
  }) {
    final sparseMap = <String, double>{};
    for (final entry in tool.params.entries) {
      final key = _paramToShorthand[entry.key] ?? entry.key;
      sparseMap[key] = entry.value;
    }

    final payloadMap = <String, dynamic>{
      'v': 1,
      if (tool.description.isNotEmpty) 'desc': tool.description,
      'p': sparseMap,
    };

    final jsonBytes = utf8.encode(jsonEncode(payloadMap));
    final compressed = compress ? zlib.encode(jsonBytes) : jsonBytes;
    final dataEncoded = base64Url.encode(compressed).replaceAll('=', '');

    final query = <String, String>{
      'name': tool.name,
      if (author != null && author.isNotEmpty) 'author': author,
      'data': dataEncoded,
    };

    final queryString = query.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$uriScheme://$uriHostPath?$queryString';
  }

  /// Encodes a [ToolDefinition] into a standard human-readable JSON string.
  static String encodeToJson(ToolDefinition tool, {String? author}) {
    final map = <String, dynamic>{
      r'$schema': 'https://aperturex.app/schema/look-v1.json',
      'v': 1,
      'name': tool.name,
      'author': ?author,
      if (tool.description.isNotEmpty) 'description': tool.description,
      'params': tool.params,
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Decodes any ApertureX Look QR code string, `apx://` URI, or raw JSON document.
  static LookQrPayload decode(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Empty Look QR payload');
    }

    if (trimmed.startsWith('$uriScheme://')) {
      return _decodeUri(trimmed);
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic> || decoded is Map) {
        return _decodeMap(decoded.cast<String, dynamic>());
      }
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Failed to parse Look payload: $e');
    }

    throw const FormatException('Invalid ApertureX Look QR format');
  }

  static LookQrPayload _decodeUri(String uriString) {
    final uri = Uri.parse(uriString);
    final query = uri.queryParameters;

    final name = query['name'] ?? 'Shared Look';
    final author = query['author'];

    final dataParam = query['data'];
    if (dataParam == null || dataParam.isEmpty) {
      final rawJson = query['raw'];
      if (rawJson != null && rawJson.isNotEmpty) {
        final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
        return _decodeMap(decoded, defaultName: name, defaultAuthor: author);
      }
      throw const FormatException('URI is missing look payload data');
    }

    // Normalise base64 padding
    var normalized = dataParam;
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }

    final compressedBytes = base64Url.decode(normalized);
    List<int> jsonBytes;
    try {
      jsonBytes = zlib.decode(compressedBytes);
    } catch (_) {
      // Fallback in case raw uncompressed bytes were passed
      jsonBytes = compressedBytes;
    }

    final jsonString = utf8.decode(jsonBytes);
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return _decodeMap(map, defaultName: name, defaultAuthor: author);
  }

  static LookQrPayload _decodeMap(
    Map<String, dynamic> map, {
    String? defaultName,
    String? defaultAuthor,
  }) {
    final name = (map['name'] as String?) ?? defaultName ?? 'Shared Look';
    final author = (map['author'] as String?) ?? defaultAuthor;
    final desc = (map['desc'] as String?) ?? (map['description'] as String?);

    // Support both 'p' (shorthand) and 'params' (canonical)
    final rawParams = (map['p'] as Map?) ?? (map['params'] as Map?);
    if (rawParams == null) {
      throw const FormatException('Look payload contains no parameters map');
    }

    final canonicalParams = <String, double>{};
    for (final entry in rawParams.entries) {
      final key = entry.key.toString();
      final canonicalKey = _shorthandToParam[key] ?? key;
      if (_findParameter(canonicalKey) != null && entry.value is num) {
        canonicalParams[canonicalKey] = (entry.value as num).toDouble();
      }
    }

    return LookQrPayload(
      name: name,
      author: author,
      description: desc,
      params: canonicalParams,
    );
  }
}

Parameter? _findParameter(String name) {
  for (final p in Parameter.values) {
    if (p.name == name) return p;
  }
  return null;
}
