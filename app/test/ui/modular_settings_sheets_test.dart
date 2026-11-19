import 'package:aperturex/ui/settings/settings_about_sheet.dart';
import 'package:aperturex/ui/settings/settings_ai_sheet.dart';
import 'package:aperturex/ui/settings/settings_export_defaults_sheet.dart';
import 'package:aperturex/ui/settings/settings_hub.dart';
import 'package:aperturex/ui/settings/settings_shell_sheet.dart';
import 'package:aperturex/ui/settings/settings_stylus_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SettingsHub renders all categories', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SettingsHub(),
          ),
        ),
      ),
    );

    expect(find.text('Settings Hub'), findsOneWidget);
    expect(find.text('Workspace & Shell'), findsOneWidget);
    expect(find.text('Stylus & Input'), findsOneWidget);
    expect(find.text('Export Defaults'), findsOneWidget);
    expect(find.text('Privacy & Local AI'), findsOneWidget);
    expect(find.text('About ApertureX'), findsOneWidget);
  });

  testWidgets('SettingsShellSheet toggles shell preference and theme', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SettingsShellSheet(),
          ),
        ),
      ),
    );

    expect(find.text('Workspace & Shell'), findsOneWidget);
    expect(find.byKey(const Key('shell-selector-segmented')), findsOneWidget);
    expect(find.byKey(const Key('theme-selector-segmented')), findsOneWidget);
    expect(find.byKey(const Key('settings-glassmorphic-toggle')), findsOneWidget);
  });

  testWidgets('SettingsStylusSheet displays palm rejection and pressure controls', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SettingsStylusSheet(),
          ),
        ),
      ),
    );

    expect(find.text('Stylus & Input'), findsOneWidget);
    expect(find.byKey(const Key('settings-stylus-palm-rejection')), findsOneWidget);
    expect(find.byKey(const Key('settings-stylus-pressure-sensitivity')), findsOneWidget);
    expect(find.text('Inverted Stylus Support'), findsOneWidget);
  });

  testWidgets('SettingsExportDefaultsSheet renders quality and C2PA toggles', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SettingsExportDefaultsSheet(),
          ),
        ),
      ),
    );

    expect(find.text('Export Defaults'), findsOneWidget);
    expect(find.text('Quality'), findsOneWidget);
    expect(find.text('C2PA Content Credentials'), findsOneWidget);
  });

  testWidgets('SettingsAiSheet renders on-device AI processing toggle', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SettingsAiSheet(),
          ),
        ),
      ),
    );

    expect(find.text('Privacy & Local AI'), findsOneWidget);
    expect(find.byKey(const Key('settings-ai-consent-toggle')), findsOneWidget);
  });

  testWidgets('SettingsAboutSheet displays offline claim', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsAboutSheet(),
        ),
      ),
    );

    expect(find.text('About ApertureX'), findsOneWidget);
    expect(find.textContaining('100% Offline. Zero Cloud Analytics.'), findsOneWidget);
  });
}
