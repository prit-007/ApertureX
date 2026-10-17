import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';

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
    final clamped = quality.clamp(60, 100);
    state = state.copyWith(quality: clamped);
    _persist();
    axLog(LogDomain.export, 'Export quality set to $clamped');
  }

  void setMaxDim(int maxDim) {
    _userSet = true;
    final clamped = maxDim.clamp(0, 100000);
    state = state.copyWith(maxDim: clamped);
    _persist();
    axLog(
      LogDomain.export,
      'Export max dimension set to ${clamped == 0 ? 'Original' : '$clamped px'}',
    );
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
