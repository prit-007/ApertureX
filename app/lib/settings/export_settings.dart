import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';

/// Export preferences, persisted on-device.
class ExportSettings {
  const ExportSettings({
    this.quality = 90,
    this.maxDim = 0,
    this.colorSpace = 0,
    this.ultraHdr = false,
    this.hdrHeadroom = 2.0,
  });

  /// JPEG quality `60..100`.
  final int quality;

  /// Longest-side cap in pixels; `0` = original resolution.
  final int maxDim;

  /// Color space: `0` = sRGB, `1` = Display-P3 (Wide Color Gamut).
  final int colorSpace;

  /// Enable Ultra HDR (ISO 21496-1) gain map embedding.
  final bool ultraHdr;

  /// HDR peak headroom in EV stops (1.0..4.0, default 2.0 = 400% SDR brightness).
  final double hdrHeadroom;

  ExportSettings copyWith({
    int? quality,
    int? maxDim,
    int? colorSpace,
    bool? ultraHdr,
    double? hdrHeadroom,
  }) => ExportSettings(
    quality: quality ?? this.quality,
    maxDim: maxDim ?? this.maxDim,
    colorSpace: colorSpace ?? this.colorSpace,
    ultraHdr: ultraHdr ?? this.ultraHdr,
    hdrHeadroom: hdrHeadroom ?? this.hdrHeadroom,
  );
}

class ExportSettingsNotifier extends Notifier<ExportSettings> {
  static const _qualityKey = 'export_quality';
  static const _maxDimKey = 'export_max_dim';
  static const _colorSpaceKey = 'export_color_space';
  static const _ultraHdrKey = 'export_ultra_hdr';
  static const _hdrHeadroomKey = 'export_hdr_headroom';
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

  void setColorSpace(int colorSpace) {
    _userSet = true;
    state = state.copyWith(colorSpace: colorSpace);
    _persist();
    axLog(
      LogDomain.export,
      'Export color space set to ${colorSpace == 1 ? 'Display-P3 (Wide Gamut)' : 'sRGB'}',
    );
  }

  void setUltraHdr(bool enabled) {
    _userSet = true;
    state = state.copyWith(ultraHdr: enabled);
    _persist();
    axLog(LogDomain.export, 'Export Ultra HDR set to $enabled');
  }

  void setHdrHeadroom(double headroom) {
    _userSet = true;
    final clamped = headroom.clamp(1.0, 4.0);
    state = state.copyWith(hdrHeadroom: clamped);
    _persist();
    axLog(LogDomain.export, 'Export HDR headroom set to +${clamped.toStringAsFixed(1)} EV');
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userSet) return; // never clobber a choice made during startup
      state = ExportSettings(
        quality: prefs.getInt(_qualityKey) ?? 90,
        maxDim: prefs.getInt(_maxDimKey) ?? 0,
        colorSpace: prefs.getInt(_colorSpaceKey) ?? 0,
        ultraHdr: prefs.getBool(_ultraHdrKey) ?? false,
        hdrHeadroom: prefs.getDouble(_hdrHeadroomKey) ?? 2.0,
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
      await prefs.setInt(_colorSpaceKey, state.colorSpace);
      await prefs.setBool(_ultraHdrKey, state.ultraHdr);
      await prefs.setDouble(_hdrHeadroomKey, state.hdrHeadroom);
    } catch (_) {
      // best effort
    }
  }
}

final exportSettingsProvider =
    NotifierProvider<ExportSettingsNotifier, ExportSettings>(
      ExportSettingsNotifier.new,
    );
