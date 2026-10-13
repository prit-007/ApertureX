import 'package:material_ui/material_ui.dart';

/// Central Material 3 theming for ApertureX (ADR 0011).
///
/// Keeps the **dynamic accent** (wallpaper `primary`/`secondary`/`tertiary`) but
/// forces **neutral greys** for every surface role, so grading a photo against
/// the UI never tints the user's perception. The seed scheme is the fallback; on
/// Android S+ the scheme from `dynamic_color` supplies the accent.
class AppTheme {
  const AppTheme._();

  static const Color seed = Color(0xFF6750A4);

  static ThemeData light([ColorScheme? dynamic]) {
    final scheme = dynamic ?? ColorScheme.fromSeed(seedColor: seed);
    return ThemeData(
      colorScheme: _neutralize(scheme, Brightness.light),
      useMaterial3: true,
    );
  }

  static ThemeData dark([ColorScheme? dynamic]) {
    final scheme =
        dynamic ??
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
    return ThemeData(
      colorScheme: _neutralize(scheme, Brightness.dark),
      useMaterial3: true,
    );
  }

  /// Overrides only the neutral surface roles; the accent roles are untouched.
  static ColorScheme _neutralize(ColorScheme s, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return s.copyWith(
      surface: dark ? const Color(0xFF0E0E0E) : const Color(0xFFF7F7F7),
      onSurface: dark ? const Color(0xFFECECEC) : const Color(0xFF1B1B1B),
      onSurfaceVariant: dark
          ? const Color(0xFFB0B0B0)
          : const Color(0xFF4A4A4A),
      surfaceContainerLowest: dark
          ? const Color(0xFF080808)
          : const Color(0xFFFFFFFF),
      surfaceContainerLow: dark
          ? const Color(0xFF141414)
          : const Color(0xFFF1F1F1),
      surfaceContainer: dark
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFEBEBEB),
      surfaceContainerHigh: dark
          ? const Color(0xFF202020)
          : const Color(0xFFE4E4E4),
      surfaceContainerHighest: dark
          ? const Color(0xFF262626)
          : const Color(0xFFDDDDDD),
      outline: dark ? const Color(0xFF3A3A3A) : const Color(0xFFBFBFBF),
      outlineVariant: dark ? const Color(0xFF2A2A2A) : const Color(0xFFD5D5D5),
    );
  }
}
