import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aperturex/gesture/gesture_interpreter.dart';
import 'package:aperturex/ui/snapseed/snapseed_gesture_hud.dart';
import 'package:aperturex/ui/snapseed/snapseed_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SnapseedScrubHud', () {
    testWidgets('renders bipolar parameter with zero-centered dual progress bar and readout', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SnapseedScrubHud(
              tool: GradeTool.exposure,
              value: 0.50,
              visible: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('snapseed-scrub-hud')), findsOneWidget);
      expect(find.text('Brightness'), findsOneWidget);
      expect(find.text('+0.50'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders 2D grade tool with hue and saturation values', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SnapseedScrubHud(
              tool: GradeTool.shadowsGrade,
              value: 0.0,
              hue: 120.0,
              sat: 0.45,
              visible: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('snapseed-scrub-hud')), findsOneWidget);
      expect(find.text('Shadows Grade'), findsOneWidget);
      expect(find.text('H:120° S:45%'), findsOneWidget);
    });
  });

  group('SnapseedParameterCarousel', () {
    testWidgets('renders full tool category list and highlights the active tool', (
      tester,
    ) async {
      final lightTools = gestureCategories[ToolCategory.light]!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SnapseedParameterCarousel(
              category: ToolCategory.light,
              tools: lightTools,
              activeTool: GradeTool.contrast,
              values: const {
                GradeTool.exposure: 0.25,
                GradeTool.contrast: -0.15,
                GradeTool.highlights: 0.0,
                GradeTool.shadows: 0.0,
                GradeTool.whites: 0.0,
                GradeTool.blacks: 0.0,
              },
              visible: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('snapseed-parameter-carousel')), findsOneWidget);
      expect(find.text('LIGHT'), findsOneWidget);
      expect(find.text('Brightness'), findsOneWidget);
      expect(find.text('Contrast'), findsOneWidget);
      expect(find.text('Highlights'), findsOneWidget);
      expect(find.text('Shadows'), findsOneWidget);
      expect(find.text('Whites'), findsOneWidget);
      expect(find.text('Blacks'), findsOneWidget);

      expect(find.byKey(const Key('carousel-tool-contrast')), findsOneWidget);
      expect(find.text('-15'), findsOneWidget);
    });
  });

  group('SnapseedShell HUD integration', () {
    testWidgets('displays scrub HUD when gesturePhase is scrubbing', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SnapseedShell(
                tool: GradeTool.exposure,
                category: ToolCategory.light,
                tools: gestureCategories[ToolCategory.light]!,
                gesturePhase: GesturePhase.scrubbing,
                onCycleCategory: () {},
                onPickTool: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('snapseed-scrub-hud')), findsOneWidget);
    });

    testWidgets('displays parameter carousel when gesturePhase is cycling', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SnapseedShell(
                tool: GradeTool.contrast,
                category: ToolCategory.light,
                tools: gestureCategories[ToolCategory.light]!,
                gesturePhase: GesturePhase.cycling,
                onCycleCategory: () {},
                onPickTool: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('snapseed-parameter-carousel')), findsOneWidget);
    });
  });
}
