import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/features/guide/app_guide_screen.dart';

void main() {
  group('AppGuideScreen', () {
    testWidgets('renders guide list and filters by category', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ApertureX Academy'), findsOneWidget);
      expect(find.text('Exposure & Dynamic Range'), findsOneWidget);

      // Tap Detail category chip
      await tester.tap(find.text('Detail'));
      await tester.pumpAndSettle();

      expect(find.text('AI Neural Denoise & Noise Reduction'), findsOneWidget);
      expect(find.text('Parametric Sharpening & Edge Masking'), findsOneWidget);
      expect(find.text('Exposure & Dynamic Range'), findsNothing);
    });

    testWidgets('expands card and allows interactive simulator manipulation',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppGuideScreen(initialToolId: 'exposure'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Interactive Simulator'), findsOneWidget);
      expect(find.text('0 EV'), findsOneWidget);

      // Find slider in the simulator and drag it
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      await tester.drag(sliderFinder, const Offset(60, 0));
      await tester.pumpAndSettle();

      // Tap Reset icon
      final resetFinder = find.byTooltip('Reset simulator');
      if (resetFinder.evaluate().isNotEmpty) {
        await tester.tap(resetFinder);
        await tester.pumpAndSettle();
        expect(find.text('0 EV'), findsOneWidget);
      }
    });

    testWidgets('invokes onSelectTool callback when Try in Editor is tapped',
        (tester) async {
      String? selectedTool;

      await tester.pumpWidget(
        MaterialApp(
          home: AppGuideScreen(
            initialToolId: 'exposure',
            onSelectTool: (toolId) {
              selectedTool = toolId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView).last, const Offset(0, -300));
      await tester.pumpAndSettle();

      final tryButton = find.text('Try in Editor');
      expect(tryButton, findsOneWidget);

      await tester.tap(tryButton);
      await tester.pumpAndSettle();

      expect(selectedTool, 'exposure');
    });
  });
}
