import 'package:flutter_test/flutter_test.dart';

import 'package:aperturex/features/presets/content_classifier.dart';
import 'package:aperturex/features/presets/preset_catalog.dart';

void main() {
  group('ContentClassifier', () {
    test('portrait with faces and high depth confidence suggests portrait presets', () {
      final result = ContentClassifier.classify(
        faceCount: 2,
        depthConfidence: 0.8,
        brightness: 0.5,
      );
      expect(result.category, PresetCategory.portrait);
      expect(result.primaryPresetId, 'movie_main_character');
      expect(result.primaryPresetName, 'Main Character');
      expect(
        result.alternatePresets.map((p) => p.id),
        contains('movie_soft_core'),
      );
      expect(
        result.alternatePresets.map((p) => p.id),
        contains('movie_gen_z_kodachrome'),
      );
      expect(
        result.alternatePresets.map((p) => p.id),
        contains('movie_clean_girl'),
      );
      expect(result.reason, contains('Faces'));
    });

    test('landscape with no faces and high depth confidence suggests nature presets', () {
      final result = ContentClassifier.classify(
        faceCount: 0,
        depthConfidence: 0.8,
        brightness: 0.5,
      );
      expect(result.category, PresetCategory.nature);
      expect(result.primaryPresetId, 'nature_beach_day');
      expect(result.primaryPresetName, 'Beach Day');
      expect(
        result.alternatePresets.map((p) => p.id),
        contains('nature_sunset_picnic'),
      );
      expect(
        result.alternatePresets.map((p) => p.id),
        contains('nature_rooftop_hangout'),
      );
      expect(result.reason, anyOf(contains('landscape'), contains('nature')));
    });

    test('night scene with faces suggests neon/dark presets', () {
      final result = ContentClassifier.classify(
        faceCount: 1,
        depthConfidence: 0.6,
        brightness: 0.15,
      );
      expect(result.category, PresetCategory.urban);
      expect(result.primaryPresetId, 'movie_neon_midnight');
      expect(result.primaryPresetName, 'Neon Midnight');
      expect(
        result.alternatePresets.map((p) => p.id),
        contains('movie_indie_sleaze'),
      );
      expect(result.reason, anyOf(contains('night'), contains('low light')));
    });

    test('bright scene with faces suggests clean/bright presets', () {
      final result = ContentClassifier.classify(
        faceCount: 2,
        depthConfidence: 0.7,
        brightness: 0.8,
      );
      expect(result.primaryPresetId, 'movie_clean_girl');
      expect(result.primaryPresetName, 'Clean Girl');
      expect(
        result.alternatePresets.map((p) => p.id),
        contains('movie_y2k_bedroom_pop'),
      );
    });

    test('low depth confidence still classifies based on faces', () {
      final result = ContentClassifier.classify(
        faceCount: 3,
        depthConfidence: 0.2,
        brightness: 0.5,
      );
      // Faces detected → still portrait even with low depth confidence
      expect(result.category, PresetCategory.portrait);
      expect(result.primaryPresetId, 'movie_main_character');
    });

    test('no faces and low depth confidence defaults to universal/all-rounder', () {
      final result = ContentClassifier.classify(
        faceCount: 0,
        depthConfidence: 0.2,
        brightness: 0.5,
      );
      expect(result.category, PresetCategory.portrait);
      expect(result.primaryPresetId, 'cultural_universal_brilliance');
      expect(result.primaryPresetName, 'Universal Brilliance');
    });

    test('classification reason is non-empty', () {
      final result = ContentClassifier.classify(
        faceCount: 1,
        depthConfidence: 0.5,
        brightness: 0.5,
      );
      expect(result.reason.isNotEmpty, isTrue);
    });
  });
}
