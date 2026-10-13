import 'package:material_ui/material_ui.dart';

/// Central Material 3 theming for Tessera.
///
/// The seed scheme is the fallback; on Android S+ the scheme supplied by
/// `dynamic_color` (wallpaper palette) is used instead. See ADR 0006.
class AppTheme {
  const AppTheme._();

  static const Color seed = Color(0xFF6750A4);

  static ThemeData light([ColorScheme? dynamic]) => ThemeData(
    colorScheme: dynamic ?? ColorScheme.fromSeed(seedColor: seed),
    useMaterial3: true,
  );

  static ThemeData dark([ColorScheme? dynamic]) => ThemeData(
    colorScheme:
        dynamic ??
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
    useMaterial3: true,
  );
}
