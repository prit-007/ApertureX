import 'package:aperturex/core/log/activity_log.dart';
import 'package:aperturex/core/log/log_providers.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/edit/settings_clipboard.dart';
import 'package:aperturex/ui/common/copy_settings_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/viewport_harness.dart';

void main() {
  testWidgets('CopySettingsSheet displays sections and copies selection', (tester) async {
    activityLog.clear();
    final container = ProviderContainer();
    final controller = container.read(recipeControllerProvider.notifier);
    controller.update(Parameter.exposure, 1.5);
    controller.commit(label: 'Exposure set');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: CopySettingsSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Copy Settings'), findsOneWidget);
    expect(find.text('Light / Basic Tone'), findsOneWidget);
    expect(find.text('Color & Grading'), findsOneWidget);
    expect(find.text('Select All'), findsOneWidget);
    expect(find.text('Modified Only'), findsOneWidget);

    // Tap "Modified Only"
    await tester.tap(find.text('Modified Only'));
    await tester.pumpAndSettle();

    // Scroll down to reveal the confirm button
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    // Tap "Copy" button
    final btn = find.byKey(const Key('copy-settings-confirm-btn'));
    await tester.tap(btn);
    await tester.pumpAndSettle();

    final clipboard = container.read(settingsClipboardProvider.notifier).copiedSettings;
    expect(clipboard, isNotNull);
    expect(clipboard!.includes(RecipeSection.light), isTrue);

    expect(
      activityLog.entries.any((e) => e.domain == LogDomain.editor && e.message.contains('Copied')),
      isTrue,
    );
  });

  testWidgets(
    'action buttons wrap without overflow at phone viewports and text scales',
    (tester) async {
      for (final viewport in const [Size(360, 800), Size(320, 640)]) {
        for (final textScale in const [1.0, 1.3]) {
          setViewport(tester, viewport, textScale);
          activityLog.clear();
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final controller = container.read(recipeControllerProvider.notifier);
          controller.update(Parameter.exposure, 1.5);
          controller.commit(label: 'Exposure set');

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                home: Scaffold(body: CopySettingsSheet()),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull,
              reason: 'overflow at $viewport / textScale $textScale');

          final selectAll = find.widgetWithText(TextButton, 'Select All');
          final modifiedOnly = find.widgetWithText(TextButton, 'Modified Only');
          final deselectAll = find.widgetWithText(TextButton, 'Deselect All');
          expect(selectAll, findsOneWidget);
          expect(modifiedOnly, findsOneWidget);
          expect(deselectAll, findsOneWidget);
          expect(selectAll.hitTestable(), findsOneWidget);
          expect(modifiedOnly.hitTestable(), findsOneWidget);
          expect(deselectAll.hitTestable(), findsOneWidget);

          // Behavioural guard: Modified Only still narrows the selection.
          await tester.tap(modifiedOnly);
          await tester.pumpAndSettle();
          final tile = tester.widget<CheckboxListTile>(
            find.ancestor(
              of: find.text('Light / Basic Tone'),
              matching: find.byType(CheckboxListTile),
            ),
          );
          expect(tile.value, isTrue,
              reason: 'Modified Only must still select the light section');
        }
      }
    },
  );
}
