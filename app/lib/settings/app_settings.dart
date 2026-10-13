import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// App-wide appearance preference. Photo editing defaults to **dark chrome** so
/// the UI never biases perception of the image (ADR 0011); the user can switch.
class AppSettings extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void setThemeMode(ThemeMode mode) => state = mode;
}

final themeModeProvider = NotifierProvider<AppSettings, ThemeMode>(
  AppSettings.new,
);
