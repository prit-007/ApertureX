import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';

/// App-wide appearance preference. Photo editing defaults to **dark chrome** so
/// the UI never biases perception of the image (ADR 0011); the choice is
/// persisted on-device.
class AppSettings extends Notifier<ThemeMode> {
  static const String _key = 'theme_mode';
  bool _userSet = false;

  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.dark;
  }

  void setThemeMode(ThemeMode mode) {
    _userSet = true;
    state = mode;
    _persist(mode);
    axLog(LogDomain.app, 'Theme mode set to ${mode.name}');
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userSet) return;
      state = _fromName(prefs.getString(_key));
    } catch (_) {
      // No storage available (e.g. tests) — keep the dark default.
    }
  }

  Future<void> _persist(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {
      // best effort
    }
  }

  static ThemeMode _fromName(String? name) => switch (name) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
}

final themeModeProvider = NotifierProvider<AppSettings, ThemeMode>(
  AppSettings.new,
);

/// Glassmorphic UI mode preference: frosted glass translucency on panels and HUD
/// so the underlying image remains visible while editing.
class GlassmorphicUiSettings extends Notifier<bool> {
  static const String _key = 'glassmorphic_ui';
  bool _userSet = false;

  @override
  bool build() {
    _restore();
    return false;
  }

  void setEnabled(bool enabled) {
    _userSet = true;
    state = enabled;
    _persist(enabled);
    axLog(LogDomain.app, 'Glassmorphic UI set to $enabled');
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userSet) return;
      state = prefs.getBool(_key) ?? false;
    } catch (_) {}
  }

  Future<void> _persist(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, enabled);
    } catch (_) {}
  }
}

final glassmorphicUiProvider = NotifierProvider<GlassmorphicUiSettings, bool>(
  GlassmorphicUiSettings.new,
);

/// Tile cache limit in megabytes (ADR 0005, memory budget).
class TileCacheSettings extends Notifier<int> {
  static const String _key = 'tile_cache_limit_mb';
  static const int defaultLimitMb = 512;
  bool _userSet = false;

  @override
  int build() {
    _restore();
    return defaultLimitMb;
  }

  void setLimitMb(int limitMb) {
    _userSet = true;
    state = limitMb;
    _persist(limitMb);
    axLog(LogDomain.app, 'Tile cache limit set to ${limitMb}MB');
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userSet) return;
      state = prefs.getInt(_key) ?? defaultLimitMb;
    } catch (_) {}
  }

  Future<void> _persist(int limitMb) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, limitMb);
    } catch (_) {}
  }
}

final tileCacheSettingsProvider = NotifierProvider<TileCacheSettings, int>(
  TileCacheSettings.new,
);

/// Stylus and palm rejection preferences.
class StylusState {
  const StylusState({
    this.palmRejection = true,
    this.pressureSensitivity = true,
  });

  final bool palmRejection;
  final bool pressureSensitivity;

  StylusState copyWith({
    bool? palmRejection,
    bool? pressureSensitivity,
  }) => StylusState(
    palmRejection: palmRejection ?? this.palmRejection,
    pressureSensitivity: pressureSensitivity ?? this.pressureSensitivity,
  );
}

class StylusSettings extends Notifier<StylusState> {
  static const String _palmKey = 'stylus_palm_rejection';
  static const String _pressureKey = 'stylus_pressure_sensitivity';
  bool _userSet = false;

  @override
  StylusState build() {
    _restore();
    return const StylusState();
  }

  void setPalmRejection(bool enabled) {
    _userSet = true;
    state = state.copyWith(palmRejection: enabled);
    _persist();
    axLog(LogDomain.app, 'Palm rejection set to $enabled');
  }

  void setPressureSensitivity(bool enabled) {
    _userSet = true;
    state = state.copyWith(pressureSensitivity: enabled);
    _persist();
    axLog(LogDomain.app, 'Pressure sensitivity set to $enabled');
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userSet) return;
      state = StylusState(
        palmRejection: prefs.getBool(_palmKey) ?? true,
        pressureSensitivity: prefs.getBool(_pressureKey) ?? true,
      );
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_palmKey, state.palmRejection);
      await prefs.setBool(_pressureKey, state.pressureSensitivity);
    } catch (_) {}
  }
}

final stylusSettingsProvider = NotifierProvider<StylusSettings, StylusState>(
  StylusSettings.new,
);

