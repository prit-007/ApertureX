import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';
import 'shared_preferences_provider.dart';

/// App-wide appearance preference. Photo editing defaults to **dark chrome** so
/// the UI never biases perception of the image (ADR 0011); the choice is
/// persisted on-device.
class AppSettings extends Notifier<ThemeMode> {
  static const String _key = 'theme_mode';
  bool _userSet = false;

  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs != null) {
      final name = prefs.getString(_key);
      if (name != null) return _fromName(name);
    } else {
      _restore();
    }
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
    } catch (e, st) {
      axLog(LogDomain.app, 'ThemeMode restore fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
    }
  }

  Future<void> _persist(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (e, st) {
      axLog(LogDomain.app, 'ThemeMode persist failed: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
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
    } catch (e, st) {
      axLog(LogDomain.app, 'Glassmorphic restore fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
    }
  }

  Future<void> _persist(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, enabled);
    } catch (e, st) {
      axLog(LogDomain.app, 'Glassmorphic persist failed: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
    }
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
    } catch (e, st) {
      axLog(LogDomain.app, 'Tile cache restore fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
    }
  }

  Future<void> _persist(int limitMb) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, limitMb);
    } catch (e, st) {
      axLog(LogDomain.app, 'Tile cache persist failed: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
    }
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
    } catch (e, st) {
      axLog(LogDomain.app, 'Stylus restore fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_palmKey, state.palmRejection);
      await prefs.setBool(_pressureKey, state.pressureSensitivity);
    } catch (e, st) {
      axLog(LogDomain.app, 'Stylus persist failed: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
    }
  }
}

final stylusSettingsProvider = NotifierProvider<StylusSettings, StylusState>(
  StylusSettings.new,
);

/// Zero-copy GPU hardware texture delivery setting (#162 / Spike B).
class ZeroCopyTextureSettings extends Notifier<bool> {
  static const String _key = 'zero_copy_texture_pipeline';
  bool _userSet = false;

  @override
  bool build() {
    _restore();
    return true; // Default enabled
  }

  void setEnabled(bool enabled) {
    _userSet = true;
    state = enabled;
    _persist(enabled);
    axLog(LogDomain.app, 'Zero-copy texture pipeline ${enabled ? "enabled" : "disabled"}');
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userSet) return;
      state = prefs.getBool(_key) ?? true;
    } catch (e, st) {
      axLog(LogDomain.app, 'ZeroCopy restore fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
    }
  }

  Future<void> _persist(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, enabled);
    } catch (e, st) {
      axLog(LogDomain.app, 'ZeroCopy persist failed: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
    }
  }
}

final zeroCopyTextureProvider = NotifierProvider<ZeroCopyTextureSettings, bool>(
  ZeroCopyTextureSettings.new,
);

/// Preference for single-finger drag on the shared image canvas (ADR 0008).
/// - [automatic]: routes to gesture tuning in Snapseed mode and pan/zoom in Lightroom mode.
/// - [gestures]: routes single-finger drags to gesture tuning (Snapseed-style scrubbing) across shells.
/// - [panZoom]: reserves single-finger drags for panning/zooming, disabling on-canvas swipe grading.
enum CanvasGestureMode { automatic, gestures, panZoom }

class CanvasGestureModeSettings extends Notifier<CanvasGestureMode> {
  static const String _key = 'canvas_gesture_mode';
  bool _userSet = false;

  @override
  CanvasGestureMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs != null) {
      final name = prefs.getString(_key);
      if (name != null) return _fromName(name);
    } else {
      _restore();
    }
    return CanvasGestureMode.automatic;
  }

  void setMode(CanvasGestureMode mode) {
    _userSet = true;
    state = mode;
    _persist(mode);
    axLog(LogDomain.app, 'Canvas gesture mode set to ${mode.name}');
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userSet) return;
      state = _fromName(prefs.getString(_key));
    } catch (e, st) {
      axLog(LogDomain.app, 'CanvasGesture restore fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
    }
  }

  Future<void> _persist(CanvasGestureMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (e, st) {
      axLog(LogDomain.app, 'CanvasGesture persist failed: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
    }
  }

  static CanvasGestureMode _fromName(String? name) => switch (name) {
    'gestures' => CanvasGestureMode.gestures,
    'panZoom' => CanvasGestureMode.panZoom,
    _ => CanvasGestureMode.automatic,
  };
}

final canvasGestureModeProvider =
    NotifierProvider<CanvasGestureModeSettings, CanvasGestureMode>(
  CanvasGestureModeSettings.new,
);



