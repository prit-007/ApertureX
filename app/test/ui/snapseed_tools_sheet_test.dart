import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aperturex/edit/node_editor.dart';
import 'package:aperturex/settings/onboarding.dart';
import 'package:aperturex/settings/shell_preference.dart';
import 'package:aperturex/ui/app_shell.dart';
import 'package:aperturex/ui/common/blur_controls.dart';
import 'package:aperturex/ui/common/film_controls.dart';
import 'package:aperturex/ui/common/tone_curve_editor.dart';
import 'package:aperturex/ui/snapseed/snapseed_shell.dart';
import 'package:aperturex/ui/snapseed/snapseed_tools_sheet.dart';

void main() {
  SharedPreferences.setMockInitialValues({});
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    container.read(gestureHintSeenProvider.notifier).markGestureHintSeen();
    container.read(shellPreferenceProvider.notifier).select(AppShellKind.snapseed);
  });

  tearDown(() => container.dispose());

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: AppShell())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('tapping tools button opens comprehensive Snapseed Tools Sheet', (
    tester,
  ) async {
    await pumpShell(tester);
    expect(find.byType(SnapseedShell), findsOneWidget);

    // Find and tap the Tools button
    final toolsBtn = find.byKey(const Key('snapseed-tools-sheet-toggle'));
    expect(toolsBtn, findsOneWidget);
    await tester.tap(toolsBtn);
    await tester.pumpAndSettle();

    // Verify tools sheet is shown with signature Snapseed tools
    expect(find.byType(SnapseedToolsSheet), findsOneWidget);
    expect(find.text('Tune Image'), findsOneWidget);
    expect(find.text('Curves'), findsOneWidget);
    expect(find.text('White Balance'), findsOneWidget);
    expect(find.text('Healing'), findsOneWidget);
    expect(find.text('Lens Blur'), findsOneWidget);
    expect(find.text('Film & Grain'), findsOneWidget);
    expect(find.text('Shader Lab'), findsOneWidget);
  });

  testWidgets('selecting Selective in Tools Sheet enables node editor', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const Key('snapseed-tools-sheet-toggle')));
    await tester.pumpAndSettle();

    // Tap Selective in the tools sheet
    await tester.tap(
      find.descendant(
        of: find.byType(SnapseedToolsSheet),
        matching: find.text('Selective'),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(nodeEditorProvider).enabled, isTrue);
    expect(find.byType(SnapseedToolsSheet), findsNothing);
  });

  testWidgets('selecting White Balance in Tools Sheet switches to color category', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const Key('snapseed-tools-sheet-toggle')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('White Balance'));
    await tester.pumpAndSettle();

    expect(find.text('Temperature'), findsOneWidget);
  });

  testWidgets('selecting Curves in Tools Sheet opens ToneCurveEditor panel', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const Key('snapseed-tools-sheet-toggle')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Curves'));
    await tester.pumpAndSettle();

    expect(find.byType(ToneCurveEditor), findsOneWidget);
  });

  testWidgets('selecting Lens Blur in Tools Sheet opens BlurControls panel', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const Key('snapseed-tools-sheet-toggle')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lens Blur'));
    await tester.pumpAndSettle();

    expect(find.byType(BlurControls), findsOneWidget);
  });

  testWidgets('selecting Film & Grain in Tools Sheet opens FilmControls panel', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const Key('snapseed-tools-sheet-toggle')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Film & Grain'));
    await tester.pumpAndSettle();

    expect(find.byType(FilmControls), findsOneWidget);
  });

  testWidgets('tapping Guide & Gestures button in header opens EditorGuideSheet', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const Key('snapseed-tools-sheet-toggle')));
    await tester.pumpAndSettle();

    final guideBtn = find.byTooltip('Guide & Gestures');
    expect(guideBtn, findsOneWidget);
    await tester.tap(guideBtn);
    await tester.pumpAndSettle();

    expect(find.text('ApertureX Pro Guide'), findsOneWidget);
  });
}
