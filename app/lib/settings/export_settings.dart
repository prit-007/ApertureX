import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Export preferences, persisted on-device.
class ExportSettings {
  const ExportSettings({this.quality = 90, this.maxDim = 0});

  /// JPEG quality `60..100`.
  final int quality;

  /// Longest-side cap in pixels; `0` = original resolution.
  final int maxDim;

  ExportSettings copyWith({int? quality, int? maxDim}) => ExportSettings(
    quality: quality ?? this.quality,
    maxDim: maxDim ?? this.maxDim,
  );
}

class ExportSettingsNotifier extends Notifier<ExportSettings> {
  static const _qualityKey = 'export_quality';
  static const _maxDimKey = 'export_max_dim';
  bool _userSet = false;

  @override
  ExportSettings build() {
    _restore();
    return const ExportSettings();
  }

  void setQuality(int quality) {
    _userSet = true;
    state = state.copyWith(quality: quality.clamp(60, 100));
    _persist();
  }

  void setMaxDim(int maxDim) {
    _userSet = true;
    state = state.copyWith(maxDim: maxDim.clamp(0, 100000));
    _persist();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userSet) return; // never clobber a choice made during startup
      state = ExportSettings(
        quality: prefs.getInt(_qualityKey) ?? 90,
        maxDim: prefs.getInt(_maxDimKey) ?? 0,
      );
    } catch (_) {
      // No storage available (e.g. tests) — keep defaults.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_qualityKey, state.quality);
      await prefs.setInt(_maxDimKey, state.maxDim);
    } catch (_) {
      // best effort
    }
  }
}

final exportSettingsProvider =
    NotifierProvider<ExportSettingsNotifier, ExportSettings>(
      ExportSettingsNotifier.new,
    );
