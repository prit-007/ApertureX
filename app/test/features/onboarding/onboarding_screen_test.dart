import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/features/onboarding/onboarding_screen.dart';
import 'package:aperturex/settings/onboarding.dart';
import 'package:aperturex/settings/shell_preference.dart';

void main() {
  group('OnboardingScreen', () {
    testWidgets('renders first slide with welcome information and advances on Next',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to ApertureX'), findsOneWidget);
      expect(find.text('PROFESSIONAL FOSS SUITE'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Tap Next to advance
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Two Shells, One Shared Recipe'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);

      // Tap Next twice more to reach the last slide
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Neural Forge & Pro Diagnostics'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Choose Your Editing Style'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);

      // Tap Get Started
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(container.read(hasCompletedOnboardingProvider), isTrue);
    });

    testWidgets('skip button completes onboarding immediately',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(hasCompletedOnboardingProvider), isFalse);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(container.read(hasCompletedOnboardingProvider), isTrue);
    });

    testWidgets('allows switching preferred editing shell on last slide',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Advance to last slide
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Gesture HUD'), findsOneWidget);
      await tester.tap(find.text('Gesture HUD'));
      await tester.pumpAndSettle();

      expect(container.read(shellPreferenceProvider), AppShellKind.snapseed);
    });
  });
}
