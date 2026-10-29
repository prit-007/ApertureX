import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/look_qr_codec.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/tool_definition.dart';

void main() {
  group('LookQrCodec', () {
    const testTool = ToolDefinition(
      name: 'Portra Warmth',
      description: 'Analog film warmth with soft contrast',
      params: {
        'exposure': 0.35,
        'contrast': -0.15,
        'highlights': -0.20,
        'shadows': 0.15,
        'temperature': 0.12,
        'vibrance': 0.18,
        'grain': 0.25,
      },
    );

    test('encodes and decodes roundtrip via apx://look/v1 URI with compression', () {
      final uriString = LookQrCodec.encodeToUri(
        testTool,
        author: '@devparadise',
      );

      expect(uriString, startsWith('apx://look/v1?'));
      expect(uriString, anyOf(contains('name=Portra%20Warmth'), contains('name=Portra+Warmth')));
      expect(uriString, contains('author=%40devparadise'));
      expect(uriString, contains('data='));

      final decoded = LookQrCodec.decode(uriString);
      expect(decoded.name, 'Portra Warmth');
      expect(decoded.author, '@devparadise');
      expect(decoded.description, 'Analog film warmth with soft contrast');
      expect(decoded.params['exposure'], closeTo(0.35, 1e-4));
      expect(decoded.params['contrast'], closeTo(-0.15, 1e-4));
      expect(decoded.params['highlights'], closeTo(-0.20, 1e-4));
      expect(decoded.params['shadows'], closeTo(0.15, 1e-4));
      expect(decoded.params['temperature'], closeTo(0.12, 1e-4));
      expect(decoded.params['vibrance'], closeTo(0.18, 1e-4));
      expect(decoded.params['grain'], closeTo(0.25, 1e-4));
    });

    test('encodes and decodes roundtrip via standard JSON', () {
      final jsonString = LookQrCodec.encodeToJson(
        testTool,
        author: '@photographer',
      );

      expect(jsonString, contains('"name": "Portra Warmth"'));
      expect(jsonString, contains('"author": "@photographer"'));

      final decoded = LookQrCodec.decode(jsonString);
      expect(decoded.name, 'Portra Warmth');
      expect(decoded.author, '@photographer');
      expect(decoded.params['exposure'], closeTo(0.35, 1e-4));
    });

    test('decodes shorthand parameter keys correctly', () {
      const shorthandJson = '''
      {
        "v": 1,
        "name": "Shorthand Look",
        "p": {
          "exp": 0.5,
          "con": 0.25,
          "temp": -0.1,
          "vib": 0.3,
          "gsh": 210.0,
          "gss": 0.4
        }
      }
      ''';

      final decoded = LookQrCodec.decode(shorthandJson);
      expect(decoded.name, 'Shorthand Look');
      expect(decoded.params['exposure'], closeTo(0.5, 1e-4));
      expect(decoded.params['contrast'], closeTo(0.25, 1e-4));
      expect(decoded.params['temperature'], closeTo(-0.1, 1e-4));
      expect(decoded.params['vibrance'], closeTo(0.3, 1e-4));
      expect(decoded.params['gradeShadowHue'], closeTo(210.0, 1e-4));
      expect(decoded.params['gradeShadowSat'], closeTo(0.4, 1e-4));
    });

    test('safely ignores unknown parameter keys for forward compatibility', () {
      const futureJson = '''
      {
        "v": 99,
        "name": "Future Look",
        "params": {
          "exposure": 0.2,
          "quantumSuperResolutionAI": 9.99
        }
      }
      ''';

      final decoded = LookQrCodec.decode(futureJson);
      expect(decoded.name, 'Future Look');
      expect(decoded.params['exposure'], closeTo(0.2, 1e-4));
      expect(decoded.params.containsKey('quantumSuperResolutionAI'), isFalse);
    });

    test('applies look parameters directly to an EditRecipe', () {
      final payload = LookQrCodec.decode(
        LookQrCodec.encodeToUri(testTool, author: '@filmlover'),
      );

      const recipe = EditRecipe();
      final updated = payload.applyTo(recipe);

      expect(updated.exposure, closeTo(0.35, 1e-4));
      expect(updated.contrast, closeTo(-0.15, 1e-4));
      expect(updated.highlights, closeTo(-0.20, 1e-4));
      expect(updated.shadows, closeTo(0.15, 1e-4));
      expect(updated.temperature, closeTo(0.12, 1e-4));
      expect(updated.vibrance, closeTo(0.18, 1e-4));
      expect(updated.grain, closeTo(0.25, 1e-4));
    });

    test('applies a degree-valued grade hue without clamping to 1.0', () {
      const hueJson = '''
      {
        "v": 1,
        "name": "Split Tone 210",
        "p": { "gsh": 210.0 }
      }
      ''';

      final payload = LookQrCodec.decode(hueJson);
      final updated = payload.applyTo(const EditRecipe());

      expect(updated.gradeShadowHue, 210.0);
    });

    test('throws FormatException on malformed or invalid QR payloads', () {
      expect(() => LookQrCodec.decode('not a valid look or json'), throwsFormatException);
      expect(() => LookQrCodec.decode('apx://look/v1?data=invalid_base64!!!'), throwsFormatException);
      expect(() => LookQrCodec.decode('{"no_name_or_params": true}'), throwsFormatException);
    });
  });
}
