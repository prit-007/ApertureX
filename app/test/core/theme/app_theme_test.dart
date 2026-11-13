import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('light theme constructs valid Material 3 theme with neutral surfaces', () {
      final theme = AppTheme.light();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
      expect(theme.appBarTheme.elevation, 0);
    });

    test('dark theme constructs valid Material 3 theme with neutral surfaces', () {
      final theme = AppTheme.dark();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
      expect(theme.appBarTheme.elevation, 0);
    });

    test('accepts dynamic color schemes without crashing', () {
      final dynamicScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF00AA55),
        brightness: Brightness.dark,
      );
      final theme = AppTheme.dark(dynamicScheme);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, dynamicScheme.primary);
    });

    test('configures page transitions with predictive back for Android and Cupertino for iOS', () {
      final theme = AppTheme.dark();
      final builders = theme.pageTransitionsTheme.builders;
      expect(builders[TargetPlatform.android], isA<PredictiveBackPageTransitionsBuilder>());
      expect(builders[TargetPlatform.iOS], isA<CupertinoPageTransitionsBuilder>());
    });
  });
}
