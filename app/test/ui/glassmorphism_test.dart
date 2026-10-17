import 'dart:ui' show ImageFilter;

import 'package:aperturex/settings/app_settings.dart';
import 'package:aperturex/settings/shell_preference.dart';
import 'package:aperturex/ui/app_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('Glassmorphism disabled by default: sheet renders without blur', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: AppShell(),
          ),
        ),
      ),
    );

    expect(container.read(glassmorphicUiProvider), isFalse);

    // Verify BackdropFilter has sigma 0 when disabled
    final sheetBody = find.byKey(const Key('lightroom-sheet-body'));
    expect(sheetBody, findsOneWidget);

    final backdropFilters = tester.widgetList<BackdropFilter>(
      find.descendant(of: sheetBody, matching: find.byType(BackdropFilter)),
    );
    expect(backdropFilters, isNotEmpty);
    expect(backdropFilters.first.filter, equals(ImageFilter.blur(sigmaX: 0, sigmaY: 0)));
  });

  testWidgets('Glassmorphism enabled: sheet and handle render with frosted glass blur', (tester) async {
    final container = ProviderContainer(
      overrides: [
        glassmorphicUiProvider.overrideWith(_EnabledGlassmorphicNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: AppShell(),
          ),
        ),
      ),
    );

    expect(container.read(glassmorphicUiProvider), isTrue);

    // Verify sheet body has sigma 20
    final sheetBody = find.byKey(const Key('lightroom-sheet-body'));
    expect(sheetBody, findsOneWidget);

    final backdropFilters = tester.widgetList<BackdropFilter>(
      find.descendant(of: sheetBody, matching: find.byType(BackdropFilter)),
    );
    expect(backdropFilters, isNotEmpty);
    expect(backdropFilters.first.filter, equals(ImageFilter.blur(sigmaX: 20, sigmaY: 20)));
  });

  testWidgets('Glassmorphism enabled: Top HUD in Snapseed mode renders with frosted glass blur', (tester) async {
    final container = ProviderContainer(
      overrides: [
        glassmorphicUiProvider.overrideWith(_EnabledGlassmorphicNotifier.new),
        shellPreferenceProvider.overrideWith(_SnapseedShellNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: AppShell(
              topHud: Text('HUD-Content'),
            ),
          ),
        ),
      ),
    );

    final hudFinder = find.text('HUD-Content');
    expect(hudFinder, findsOneWidget);

    // Find parent BackdropFilter around the HUD
    final hudBackdrop = tester.widget<BackdropFilter>(
      find.ancestor(of: hudFinder, matching: find.byType(BackdropFilter)).first,
    );
    expect(hudBackdrop.filter, equals(ImageFilter.blur(sigmaX: 16, sigmaY: 16)));
  });
}

class _EnabledGlassmorphicNotifier extends GlassmorphicUiSettings {
  @override
  bool build() => true;
}

class _SnapseedShellNotifier extends ShellPreference {
  @override
  AppShellKind build() => AppShellKind.snapseed;
}
