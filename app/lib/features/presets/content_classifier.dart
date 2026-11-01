import 'preset_catalog.dart';
import 'preset_ids.dart';

/// Result of content-based preset classification.
class ClassificationResult {
  const ClassificationResult({
    required this.category,
    required this.primaryPresetId,
    required this.primaryPresetName,
    required this.alternatePresets,
    required this.reason,
  });

  final PresetCategory category;
  final String primaryPresetId;
  final String primaryPresetName;
  final List<AlternatePreset> alternatePresets;
  final String reason;
}

/// An alternate preset suggestion with id and display name.
class AlternatePreset {
  const AlternatePreset({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

/// Classifies image content to suggest relevant presets.
///
/// Takes the output of AI model inference (face count, depth confidence,
/// brightness) and maps it to a preset category + specific preset IDs.
/// Pure Dart — no Rust dependency, so it's testable without the engine.
class ContentClassifier {
  ContentClassifier._();

  /// Classifies image content and returns preset suggestions.
  ///
  /// [faceCount] — number of faces detected by YuNet (0+).
  /// [depthConfidence] — depth map reliability 0..1.
  /// [brightness] — mean luminance 0..1 (0 = dark, 1 = bright).
  static ClassificationResult classify({
    required int faceCount,
    required double depthConfidence,
    required double brightness,
  }) {
    final fc = faceCount.clamp(0, 100);
    final dc = depthConfidence.clamp(0.0, 1.0);
    final br = brightness.clamp(0.0, 1.0);

    if (fc > 0) {
      // Portrait content — faces detected
      if (br < 0.30) {
        return const ClassificationResult(
          category: PresetCategory.urban,
          primaryPresetId: PresetIds.neonMidnight,
          primaryPresetName: 'Neon Midnight',
          alternatePresets: [
            AlternatePreset(id: PresetIds.indieSleaze, name: 'Indie Sleaze'),
            AlternatePreset(id: PresetIds.vhsCamcorder, name: 'VHS Camcorder'),
          ],
          reason: 'Faces detected in low light — night portrait presets',
        );
      }
      if (br > 0.70) {
        return const ClassificationResult(
          category: PresetCategory.portrait,
          primaryPresetId: PresetIds.cleanGirl,
          primaryPresetName: 'Clean Girl',
          alternatePresets: [
            AlternatePreset(id: PresetIds.y2kBedroomPop, name: 'Y2K Bedroom Pop'),
            AlternatePreset(id: PresetIds.genZKodachrome, name: 'Gen Z Kodachrome'),
          ],
          reason: 'Faces detected in bright light — clean/bright portrait presets',
        );
      }
      return const ClassificationResult(
        category: PresetCategory.portrait,
        primaryPresetId: PresetIds.mainCharacter,
        primaryPresetName: 'Main Character',
        alternatePresets: [
          AlternatePreset(id: PresetIds.softCore, name: 'Soft Core'),
          AlternatePreset(id: PresetIds.genZKodachrome, name: 'Gen Z Kodachrome'),
          AlternatePreset(id: PresetIds.cleanGirl, name: 'Clean Girl'),
        ],
        reason: 'Faces detected — portrait presets',
      );
    }

    // No faces — landscape/scene content
    if (dc > 0.50) {
      return const ClassificationResult(
        category: PresetCategory.nature,
        primaryPresetId: PresetIds.beachDay,
        primaryPresetName: 'Beach Day',
        alternatePresets: [
          AlternatePreset(id: PresetIds.sunsetPicnic, name: 'Sunset Picnic'),
          AlternatePreset(id: PresetIds.rooftopHangout, name: 'Rooftop Hangout'),
        ],
        reason: 'No faces, reliable depth — landscape/nature presets',
      );
    }

    // Uncertain content — universal all-rounder
    return const ClassificationResult(
      category: PresetCategory.portrait,
      primaryPresetId: PresetIds.universalBrilliance,
      primaryPresetName: 'Universal Brilliance',
      alternatePresets: [
        AlternatePreset(id: PresetIds.softCore, name: 'Soft Core'),
        AlternatePreset(id: PresetIds.cleanGirl, name: 'Clean Girl'),
      ],
      reason: 'Uncertain content — universal all-rounder preset',
    );
  }
}
