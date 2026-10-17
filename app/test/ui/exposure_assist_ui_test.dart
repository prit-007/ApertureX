import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/viewport/exposure_assist.dart';
import 'package:aperturex/ui/app_shell.dart';
import 'package:aperturex/ui/lightroom/lightroom_shell.dart';

void main() {
  group('Exposure Assist UI', () {
    testWidgets('pill in _CompareHint cycles through assist modes', (tester) async {
      final container = ProviderContainer();

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
      await tester.pump();

      expect(container.read(exposureAssistProvider).mode, ExposureAssistMode.off);
      expect(find.text('Assist'), findsWidgets);

      // Tap Assist
      await tester.tap(find.text('Assist').first);
      await tester.pump();

      expect(container.read(exposureAssistProvider).mode, ExposureAssistMode.zebras);
      expect(find.text('Zebras'), findsWidgets);

      // Tap Zebras -> changes to IRE false color
      await tester.tap(find.text('Zebras').first);
      await tester.pump();

      expect(container.read(exposureAssistProvider).mode, ExposureAssistMode.falseColor);
      expect(find.text('IRE'), findsWidgets);

      // Tap IRE -> turns off
      await tester.tap(find.text('IRE').first);
      await tester.pump();

      expect(container.read(exposureAssistProvider).mode, ExposureAssistMode.off);
      expect(find.text('Assist'), findsWidgets);
    });

    testWidgets('Lightroom action bar button cycles exposure assist', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: LightroomShell(),
            ),
          ),
        ),
      );
      await tester.pump();

      final assistFinder = find.byTooltip('Exposure Assist: Zebras & False Color Heatmap (ARRI IRE)');
      expect(assistFinder, findsOneWidget);

      await tester.tap(assistFinder);
      await tester.pump();
      expect(container.read(exposureAssistProvider).mode, ExposureAssistMode.zebras);

      await tester.tap(assistFinder);
      await tester.pump();
      expect(container.read(exposureAssistProvider).mode, ExposureAssistMode.falseColor);

      await tester.tap(assistFinder);
      await tester.pump();
      expect(container.read(exposureAssistProvider).mode, ExposureAssistMode.off);
    });
  });
}
