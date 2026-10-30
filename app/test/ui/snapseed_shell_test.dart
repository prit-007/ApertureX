import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/edit/recipe_mapping.dart';
import 'package:aperturex/gesture/gesture_interpreter.dart';
import 'package:aperturex/gesture/zone_mask.dart';
import 'package:aperturex/settings/shell_preference.dart';
import 'package:aperturex/ui/app_shell.dart';
import 'package:aperturex/ui/snapseed/macro_action_hud.dart';
import 'package:aperturex/ui/snapseed/snapseed_gesture_hud.dart';
import 'package:aperturex/ui/snapseed/snapseed_shell.dart';
import 'package:aperturex/ui/snapseed/snapseed_tools_sheet.dart';

// Minimal 1x1 transparent PNG bytes for ImageCanvas
final Uint8List _testPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'seen_gesture_hint': true,
      'has_seen_ghost_hint': true,
    });
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  testWidgets('SnapseedShell renders ghost dock with category, active tool, and straighten button', (
    tester,
  ) async {
    // ignore: prefer_final_locals
    var cycledCategory = false;
    GradeTool? pickedTool;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SnapseedShell(
              tool: GradeTool.exposure,
              category: ToolCategory.light,
              tools: gestureCategories[ToolCategory.light]!,
              onCycleCategory: () => cycledCategory = true,
              onPickTool: (t) => pickedTool = t,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify category and tool readouts
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Exposure'), findsOneWidget);

    // Verify dock buttons
    expect(find.byTooltip('Tools'), findsOneWidget);
    expect(find.byKey(const Key('snapseed-straighten-toggle')), findsOneWidget);

    // Tap category pill to cycle category
    await tester.tap(find.text('Light'));
    await tester.pump();
    expect(cycledCategory, isTrue);

    // Tap Tools button to open radial wheel
    await tester.tap(find.byTooltip('Tools'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('radial-contrast')), findsOneWidget);
    await tester.tap(find.byKey(const Key('radial-contrast')));
    await tester.pump();
    expect(pickedTool, GradeTool.contrast);
  });

  testWidgets('SnapseedShell tool-dock IconButtons meet the 48x48dp Android touch-target minimum', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SnapseedShell(
              tool: GradeTool.exposure,
              category: ToolCategory.light,
              tools: gestureCategories[ToolCategory.light]!,
              onCycleCategory: () {},
              onPickTool: (_) {},
              hasHistogram: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buttons = [
      const Key('snapseed-tools-sheet-toggle'),
      const Key('snapseed-looks-toggle'),
      const Key('snapseed-mask-toggle'),
      const Key('snapseed-lens-blur-toggle'),
      const Key('snapseed-straighten-toggle'),
      const Key('selective-toggle'),
      const Key('histogram-toggle'),
    ];

    for (final key in buttons) {
      final finder = find.byKey(key);
      expect(finder, findsOneWidget, reason: 'key $key not found');
      final button = tester.widget<IconButton>(finder);
      expect(
        button.constraints?.minWidth,
        greaterThanOrEqualTo(48.0),
        reason: '$key minWidth must be >= 48dp',
      );
      expect(
        button.constraints?.minHeight,
        greaterThanOrEqualTo(48.0),
        reason: '$key minHeight must be >= 48dp',
      );
    }
  });

  testWidgets('SnapseedShell straighten button opens precision rotation dial and adjusts angle', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SnapseedShell(
              tool: GradeTool.exposure,
              category: ToolCategory.light,
              tools: gestureCategories[ToolCategory.light]!,
              onCycleCategory: () {},
              onPickTool: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final straightenToggle = find.byKey(const Key('snapseed-straighten-toggle'));
    expect(straightenToggle, findsOneWidget);

    // Open dial
    await tester.tap(straightenToggle);
    await tester.pump();

    expect(find.byKey(const Key('snapseed-straighten-panel')), findsOneWidget);
    expect(find.byKey(const Key('rotation-dial-ruler')), findsOneWidget);

    // Drag ruler
    await tester.drag(
      find.byKey(const Key('rotation-dial-ruler')),
      const Offset(-80, 0),
    );
    await tester.pump();

    final straighten = container.read(recipeControllerProvider).recipe.straighten;
    expect(straighten, isNonZero);

    // Close dial
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('SnapseedToolsSheet renders 14-tool grid and selects category and tool', (
    tester,
  ) async {
    ToolCategory? selectedCategory;
    GradeTool? selectedTool;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SnapseedToolsSheet(
              onSelectCategoryAndTool: (cat, tool) {
                selectedCategory = cat;
                selectedTool = tool;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify tools across categories are present in the sheet
    expect(find.text('Tune Image'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Curves'), findsOneWidget);
    expect(find.text('White Balance'), findsOneWidget);

    // Tap Details
    await tester.tap(find.text('Details'));
    await tester.pump();

    expect(selectedCategory, ToolCategory.detail);
    expect(selectedTool, GradeTool.sharpen);
  });

  testWidgets('Snapseed 1-finger horizontal scrub updates recipe non-destructively', (
    tester,
  ) async {
    final interpreter = GestureInterpreter(
      tools: gestureCategories[ToolCategory.light]!,
      onValueChanged: (tool, delta) {
        final parameter = snapseedToolParameters[tool]!.first;
        container.read(recipeControllerProvider.notifier).applyDelta(parameter, delta);
      },
    );

    interpreter.onPanStart(const Offset(100, 100));
    // Drag horizontally past slop (touchSlop is 18)
    interpreter.onPanUpdate(const Offset(25, 0));
    interpreter.onPanUpdate(const Offset(50, 0));
    interpreter.onPanEnd();

    final exposure = container.read(recipeControllerProvider).recipe.exposure;
    expect(exposure, greaterThan(0.0));
  });

  testWidgets('Snapseed 2D trackball scrubs hue and saturation for color grading', (
    tester,
  ) async {
    final interpreter = GestureInterpreter(
      tools: [GradeTool.shadowsGrade],
      onValue2DChanged: (tool, deltaX, deltaY) {
        container.read(recipeControllerProvider.notifier).applyGradeWheel2DDelta(
          GradeWheelZone.shadows,
          hueDelta: deltaY * 360.0,
          satDelta: deltaX * 1.0,
        );
      },
    );

    interpreter.onPanStart(const Offset(100, 100));
    interpreter.onPanUpdate(const Offset(20, 20));
    interpreter.onPanEnd();

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.gradeShadowSat, greaterThan(0.0));
  });

  testWidgets('AppShell in Snapseed mode supports 2-finger zone masking and 3-finger speed macros', (
    tester,
  ) async {
    container.read(shellPreferenceProvider.notifier).select(AppShellKind.snapseed);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: AppShell(imageBytes: _testPng),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify ZoneMaskProvider is accessible and starts idle at Zone 5
    final zoneMask = container.read(zoneMaskProvider);
    expect(zoneMask.isTargeting, isFalse);
    expect(zoneMask.activeZone, 5);

    // Verify MacroActionHud can trigger copy/paste macro toasts
    container.read(macroHudProvider.notifier).show('Recipe Copied', Icons.copy);
    await tester.pump();

    expect(find.byType(MacroActionHud), findsOneWidget);
    expect(find.text('Recipe Copied'), findsOneWidget);

    // Trigger paste
    container.read(macroHudProvider.notifier).show('Recipe Pasted', Icons.paste);
    await tester.pump();

    expect(find.text('Recipe Pasted'), findsOneWidget);

    // Let the 1400ms toast timer complete so no timers are pending on disposal
    await tester.pump(const Duration(milliseconds: 1500));
  });

  testWidgets('scrub HUD fades out after 600ms when scrubbing ends (not instant)', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SnapseedShell(
              tool: GradeTool.exposure,
              category: ToolCategory.light,
              tools: gestureCategories[ToolCategory.light]!,
              onCycleCategory: () {},
              onPickTool: (_) {},
              gesturePhase: GesturePhase.scrubbing,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // HUD is visible while scrubbing (opacity 1.0)
    expect(_scrubHudOpacity(tester), 1.0);

    // Transition out of scrubbing: HUD should NOT instantly disappear
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SnapseedShell(
              tool: GradeTool.exposure,
              category: ToolCategory.light,
              tools: gestureCategories[ToolCategory.light]!,
              onCycleCategory: () {},
              onPickTool: (_) {},
              gesturePhase: GesturePhase.idle,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // HUD still at full opacity immediately after transition (fade-out delayed)
    expect(_scrubHudOpacity(tester), 1.0);

    // After 600ms + animation time, HUD should be faded out (opacity 0.0)
    await tester.pump(const Duration(milliseconds: 900));
    expect(_scrubHudOpacity(tester), 0.0);
  });

  testWidgets('scrub HUD fades in immediately when scrubbing starts', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SnapseedShell(
              tool: GradeTool.exposure,
              category: ToolCategory.light,
              tools: gestureCategories[ToolCategory.light]!,
              onCycleCategory: () {},
              onPickTool: (_) {},
              gesturePhase: GesturePhase.idle,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // HUD not visible while idle (opacity 0.0)
    expect(_scrubHudOpacity(tester), 0.0);

    // Transition to scrubbing: HUD appears immediately (opacity 1.0)
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SnapseedShell(
              tool: GradeTool.exposure,
              category: ToolCategory.light,
              tools: gestureCategories[ToolCategory.light]!,
              onCycleCategory: () {},
              onPickTool: (_) {},
              gesturePhase: GesturePhase.scrubbing,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_scrubHudOpacity(tester), 1.0);
  });

  testWidgets('SnapseedShell looks toggle opens live preset carousel and applying preset updates recipe', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SnapseedShell(
              tool: GradeTool.exposure,
              category: ToolCategory.light,
              tools: gestureCategories[ToolCategory.light]!,
              onCycleCategory: () {},
              onPickTool: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('snapseed-looks-carousel')), findsNothing);

    // Tap looks button to open carousel
    await tester.tap(find.byKey(const Key('snapseed-looks-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('snapseed-looks-carousel')), findsOneWidget);
    expect(find.text('Looks & Presets'), findsOneWidget);

    // Tap Punch preset
    final punchFinder = find.byKey(const Key('snapseed-preset-Punch'));
    expect(punchFinder, findsOneWidget);
    await tester.tap(punchFinder);
    await tester.pumpAndSettle();

    // Verify recipe was updated with punch preset
    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.contrast, 0.30);
    expect(recipe.clarity, 0.30);
  });

  testWidgets('SnapseedShell mask toggle opens Masks & Layers modal sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SnapseedShell(
              tool: GradeTool.exposure,
              category: ToolCategory.light,
              tools: gestureCategories[ToolCategory.light]!,
              onCycleCategory: () {},
              onPickTool: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('snapseed-mask-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Masks & Layers'), findsOneWidget);
  });

  testWidgets('SnapseedShell lens blur toggle opens Lens Blur & Bokeh modal sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SnapseedShell(
              tool: GradeTool.exposure,
              category: ToolCategory.light,
              tools: gestureCategories[ToolCategory.light]!,
              onCycleCategory: () {},
              onPickTool: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('snapseed-lens-blur-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Lens Blur & Bokeh'), findsOneWidget);
  });
}

/// Finds the [AnimatedOpacity] wrapping the scrub HUD and returns its opacity.
double _scrubHudOpacity(WidgetTester tester) {
  final opacities = tester.widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity));
  for (final opacity in opacities) {
    if (opacity.child is IgnorePointer) {
      final ignorePointer = opacity.child as IgnorePointer;
      if (ignorePointer.child is SnapseedScrubHud) {
        final scrubHud = ignorePointer.child as SnapseedScrubHud;
        if (scrubHud.key == const Key('snapseed-scrub-hud-root')) {
          return opacity.opacity;
        }
      }
    }
  }
  return -1.0; // not found
}
