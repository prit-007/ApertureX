import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/core/theme/window_size_class.dart';
import 'package:aperturex/ui/app_shell.dart';

void main() {
  group('Accessibility matrix — text scale', () {
    testWidgets('renders without overflow at textScale 1.3', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                // ignore: prefer_const_constructors
                textScaler: TextScaler.linear(1.3),
              ),
              child: child!,
            ),
            home: const Scaffold(body: AppShell()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow at textScale 2.0', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                // ignore: prefer_const_constructors
                textScaler: TextScaler.linear(2.0),
              ),
              child: child!,
            ),
            home: const Scaffold(body: AppShell()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Accessibility matrix — RTL', () {
    testWidgets('renders without overflow in RTL', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: AppShell()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('WindowSizeClass — foldable boundaries', () {
    test('760 dp is medium (foldable front display)', () {
      expect(windowSizeClassFor(760), WindowSizeClass.medium);
    });

    test('900 dp is expanded (tablet portrait)', () {
      expect(windowSizeClassFor(900), WindowSizeClass.expanded);
    });

    test('1440 dp is large (laptop)', () {
      expect(windowSizeClassFor(1440), WindowSizeClass.large);
    });
  });
}
