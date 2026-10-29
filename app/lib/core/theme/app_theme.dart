import 'package:material_ui/material_ui.dart';

import 'design_tokens.dart';

/// Central Material 3 theming for ApertureX (ADR 0011).
///
/// Keeps the **dynamic accent** (wallpaper `primary`/`secondary`/`tertiary`) but
/// forces **neutral greys** for every surface role, so grading a photo against
/// the UI never tints the user's perception. Every component theme is defined
/// here so screens and sheets never hardcode colours, shapes or motion.
class AppTheme {
  const AppTheme._();

  static const Color seed = Color(0xFF6750A4);

  static ThemeData light([ColorScheme? dynamic]) => _build(
    _neutralize(
      dynamic ?? ColorScheme.fromSeed(seedColor: seed),
      Brightness.light,
    ),
    Brightness.light,
  );

  static ThemeData dark([ColorScheme? dynamic]) => _build(
    _neutralize(
      dynamic ??
          ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      Brightness.dark,
    ),
    Brightness.dark,
  );

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = base.textTheme;

    const controlShape = RoundedRectangleBorder(borderRadius: Radii.mdAll);
    const buttonShape = RoundedRectangleBorder(borderRadius: Radii.pillAll);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.xlAll),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Radii.mdAll),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.md,
        ),
        border: const OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: buttonShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: buttonShape,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: controlShape),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      textTheme: text.copyWith(
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Overrides only the neutral surface roles; the accent roles are untouched.
  static ColorScheme _neutralize(ColorScheme s, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return s.copyWith(
      surface: dark ? const Color(0xFF0B0B0C) : const Color(0xFFF7F7F7),
      onSurface: dark ? const Color(0xFFECECEC) : const Color(0xFF1B1B1B),
      onSurfaceVariant: dark
          ? const Color(0xFFB0B0B0)
          : const Color(0xFF4A4A4A),
      surfaceContainerLowest: dark
          ? const Color(0xFF050506)
          : const Color(0xFFFFFFFF),
      surfaceContainerLow: dark
          ? const Color(0xFF121214)
          : const Color(0xFFF1F1F1),
      surfaceContainer: dark
          ? const Color(0xFF18181A)
          : const Color(0xFFEBEBEB),
      surfaceContainerHigh: dark
          ? const Color(0xFF202022)
          : const Color(0xFFE4E4E4),
      surfaceContainerHighest: dark
          ? const Color(0xFF262628)
          : const Color(0xFFDDDDDD),
      outline: dark ? const Color(0xFF38383B) : const Color(0xFFBFBFBF),
      outlineVariant: dark ? const Color(0xFF262628) : const Color(0xFFD5D5D5),
    );
  }
}
