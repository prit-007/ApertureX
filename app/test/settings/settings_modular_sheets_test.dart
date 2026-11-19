import 'package:aperturex/l10n/app_strings.dart';
import 'package:aperturex/ui/settings/settings_about_sheet.dart';
import 'package:aperturex/ui/settings/settings_ai_sheet.dart';
import 'package:aperturex/ui/settings/settings_export_defaults_sheet.dart';
import 'package:aperturex/ui/settings/settings_hub.dart';
import 'package:aperturex/ui/settings/settings_shell_sheet.dart';
import 'package:aperturex/ui/settings/settings_stylus_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestableWidget(Widget child, {Locale locale = const Locale('en')}) {
    return ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppStrings.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  group('SettingsModularSheets Widget & i18n Tests', () {
    testWidgets('SettingsHub renders category tiles in English and Spanish', (tester) async {
      // English
      await tester.pumpWidget(buildTestableWidget(const SettingsHub()));
      await tester.pumpAndSettle();

      expect(find.text('Settings Hub'), findsOneWidget);
      expect(find.text('Workspace & Shell'), findsOneWidget);
      expect(find.text('Stylus & Input'), findsOneWidget);
      expect(find.text('Export Defaults'), findsOneWidget);
      expect(find.text('Privacy & Local AI'), findsOneWidget);
      expect(find.text('About ApertureX'), findsOneWidget);

      // Spanish
      await tester.pumpWidget(buildTestableWidget(const SettingsHub(), locale: const Locale('es')));
      await tester.pumpAndSettle();

      expect(find.text('Panel de Ajustes'), findsOneWidget);
      expect(find.text('Espacio de trabajo y estructura'), findsOneWidget);
      expect(find.text('Lápiz y entrada táctil'), findsOneWidget);
      expect(find.text('Predeterminados de exportación'), findsOneWidget);
      expect(find.text('Privacidad e IA local'), findsOneWidget);
      expect(find.text('Acerca de ApertureX'), findsOneWidget);
    });

    testWidgets('SettingsShellSheet renders with localized strings', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const SettingsShellSheet(), locale: const Locale('es')));
      await tester.pumpAndSettle();

      expect(find.text('Espacio de trabajo y estructura'), findsOneWidget);
      expect(find.text('Estructura del editor'), findsOneWidget);
      expect(find.text('Paneles (Lightroom)'), findsOneWidget);
      expect(find.text('Gestos (Snapseed)'), findsOneWidget);
      expect(find.text('Modo de tema'), findsOneWidget);
      expect(find.text('Interfaz translúcida'), findsOneWidget);
    });

    testWidgets('SettingsStylusSheet renders with localized strings', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const SettingsStylusSheet(), locale: const Locale('de')));
      await tester.pumpAndSettle();

      expect(find.text('Stylus & Eingabe'), findsOneWidget);
      expect(find.text('Handflächenerkennung'), findsOneWidget);
      expect(find.text('Druckempfindlichkeit'), findsOneWidget);
      expect(find.text('Stiftradiermodus-Unterstützung'), findsOneWidget);
    });

    testWidgets('SettingsExportDefaultsSheet renders with localized strings', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const SettingsExportDefaultsSheet(), locale: const Locale('fr')));
      await tester.pumpAndSettle();

      expect(find.text('Valeurs d\'exportation par défaut'), findsOneWidget);
      expect(find.text('Qualité'), findsOneWidget);
      expect(find.text('Taille max (bord long)'), findsOneWidget);
      expect(find.text('Identifiants de contenu C2PA'), findsOneWidget);
    });

    testWidgets('SettingsAiSheet renders with localized strings', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const SettingsAiSheet(), locale: const Locale('ja')));
      await tester.pumpAndSettle();

      expect(find.text('プライバシーとローカルAI'), findsOneWidget);
      expect(find.text('デバイス内AI処理'), findsOneWidget);
      expect(find.text('AIモデル & ニューラルランタイム'), findsOneWidget);
    });

    testWidgets('SettingsAboutSheet renders with localized strings and honest claim', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const SettingsAboutSheet(), locale: const Locale('zh')));
      await tester.pumpAndSettle();

      expect(find.text('关于 ApertureX'), findsOneWidget);
      expect(find.text('应用概览与理念'), findsOneWidget);
      expect(find.text('开发者与维护者'), findsOneWidget);
      expect(find.text('开源许可证'), findsOneWidget);
      expect(find.text(kOfflineClaim), findsOneWidget);
      expect(kOfflineClaim.contains('100% On-Device Processing'), isTrue);
    });
  });
}
