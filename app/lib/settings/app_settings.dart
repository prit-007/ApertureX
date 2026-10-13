import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide appearance preference. Photo editing defaults to **dark chrome** so
/// the UI never biases perception of the image (ADR 0011); the choice is
/// persisted on-device.
class AppSettings extends Notifier<ThemeMode> {
  static const String _key = 'theme_mode';

  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.dark;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    _persist(mode);
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
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
