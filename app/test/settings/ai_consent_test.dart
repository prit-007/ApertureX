import 'package:aperturex/settings/ai_consent.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiConsentNotifier', () {
    test('defaults to unprompted when no storage value exists', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(aiConsentProvider), AiConsentStatus.unprompted);
      expect(container.read(aiConsentProvider.notifier).hasConsent, isFalse);
    });

    test('persists granted consent to shared preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(aiConsentProvider.notifier).grantConsent();
      expect(container.read(aiConsentProvider), AiConsentStatus.granted);
      expect(container.read(aiConsentProvider.notifier).hasConsent, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kAiConsentPrefKey), isTrue);
    });

    test('persists declined consent to shared preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(aiConsentProvider.notifier).revokeConsent();
      expect(container.read(aiConsentProvider), AiConsentStatus.declined);
      expect(container.read(aiConsentProvider.notifier).hasConsent, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kAiConsentPrefKey), isFalse);
    });

    test('restores granted consent on initialization', () async {
      SharedPreferences.setMockInitialValues({kAiConsentPrefKey: true});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(aiConsentProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(container.read(aiConsentProvider), AiConsentStatus.granted);
      expect(container.read(aiConsentProvider.notifier).hasConsent, isTrue);
    });
  });

  group('requestConsentDialog widget test', () {
    testWidgets('shows dialog when unprompted and grants consent on confirm',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      late BuildContext testContext;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (ctx) {
                testContext = ctx;
                return const Scaffold(body: Text('Test'));
              },
            ),
          ),
        ),
      );

      final container = ProviderScope.containerOf(testContext);
      final future =
          container.read(aiConsentProvider.notifier).requestConsentDialog(testContext);
      await tester.pumpAndSettle();

      expect(find.text('On-Device AI Masking'), findsOneWidget);
      expect(find.textContaining('100% On-Device'), findsOneWidget);
      expect(find.textContaining('Zero Network'), findsOneWidget);

      await tester.tap(find.text('Consent'));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isTrue);
      expect(container.read(aiConsentProvider), AiConsentStatus.granted);
    });

    testWidgets('shows dialog when unprompted and declines on reject',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      late BuildContext testContext;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (ctx) {
                testContext = ctx;
                return const Scaffold(body: Text('Test'));
              },
            ),
          ),
        ),
      );

      final container = ProviderScope.containerOf(testContext);
      final future =
          container.read(aiConsentProvider.notifier).requestConsentDialog(testContext);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isFalse);
      expect(container.read(aiConsentProvider), AiConsentStatus.declined);
    });
  });
}
