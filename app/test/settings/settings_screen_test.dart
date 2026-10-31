import 'package:aperturex/settings/ai_consent.dart';
import 'package:aperturex/settings/app_settings.dart';
import 'package:aperturex/settings/settings_screen.dart';
import 'package:aperturex/ui/common/settings_sheet.dart' show kOfflineClaim;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  testWidgets('SettingsScreen renders all major settings categories and offline claim', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('INTERFACE SHELL'), findsOneWidget);
    expect(find.text('STYLUS & INPUT'), findsOneWidget);
    expect(find.text('ENGINE & PERFORMANCE'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('EXPORT DEFAULTS'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('EXPORT DEFAULTS'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('PRIVACY & LOCAL AI'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('PRIVACY & LOCAL AI'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-offline-claim')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(kOfflineClaim), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('DIAGNOSTICS'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('DIAGNOSTICS'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('HELP & ACADEMY'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('HELP & ACADEMY'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('ABOUT & DEVELOPERS'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('ABOUT & DEVELOPERS'), findsOneWidget);
  });

  testWidgets('SettingsScreen glassmorphic and stylus toggles update providers', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final glassFinder = find.byKey(const Key('settings-screen-glassmorphic-toggle'));
    expect(container.read(glassmorphicUiProvider), isFalse);
    await tester.tap(glassFinder);
    await tester.pumpAndSettle();
    expect(container.read(glassmorphicUiProvider), isTrue);

    final palmFinder = find.byKey(const Key('settings-screen-palm-rejection'));
    expect(container.read(stylusSettingsProvider).palmRejection, isTrue);
    await tester.tap(palmFinder);
    await tester.pumpAndSettle();
    expect(container.read(stylusSettingsProvider).palmRejection, isFalse);
  });

  testWidgets('SettingsScreen AI consent toggle updates aiConsentProvider', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final aiFinder = find.byKey(const Key('settings-screen-ai-consent'));
    await tester.scrollUntilVisible(
      aiFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(container.read(aiConsentProvider), AiConsentStatus.unprompted);
    await tester.tap(aiFinder);
    await tester.pumpAndSettle();
    expect(container.read(aiConsentProvider), AiConsentStatus.granted);
  });

  testWidgets('SettingsScreen check for updates does not throw ScaffoldMessenger error', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final updateFinder = find.text('Check for Updates');
    await tester.scrollUntilVisible(
      updateFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(updateFinder, findsOneWidget);
    await tester.tap(updateFinder);
    await tester.pump();
  });
}
