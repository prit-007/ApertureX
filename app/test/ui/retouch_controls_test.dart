import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/edit/retouch_patch.dart';
import 'package:aperturex/ui/common/retouch_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/viewport_harness.dart';

void main() {
  testWidgets('RetouchControls Heal Spot + and Clone Spot + add patches', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: RetouchControls(),
            ),
          ),
        ),
      ),
    );

    expect(container.read(recipeControllerProvider).recipe.retouchPatches, isEmpty);

    // Tap Heal Spot +
    await tester.tap(find.byKey(const Key('retouch-add-heal')));
    await tester.pumpAndSettle();

    var patches = container.read(recipeControllerProvider).recipe.retouchPatches;
    expect(patches.length, 1);
    expect(patches.first.mode, RetouchMode.heal);
    expect(container.read(selectedRetouchPatchIndexProvider), 0);

    // Tap Clone Spot +
    await tester.tap(find.byKey(const Key('retouch-add-clone')));
    await tester.pumpAndSettle();

    patches = container.read(recipeControllerProvider).recipe.retouchPatches;
    expect(patches.length, 2);
    expect(patches[1].mode, RetouchMode.clone);
    expect(container.read(selectedRetouchPatchIndexProvider), 1);

    // Tap #1 Heal chip in selector bar
    await tester.tap(find.text('#1 Heal'));
    await tester.pumpAndSettle();
    expect(container.read(selectedRetouchPatchIndexProvider), 0);

    // Tap Reset Source
    await tester.tap(find.byKey(const Key('retouch-reset-source')));
    await tester.pumpAndSettle();
    final p0 = container.read(recipeControllerProvider).recipe.retouchPatches.first;
    expect(p0.sourceX, isNotNull);
  });

  testWidgets(
    'patch footer fits the 208dp sidebar at phone viewports and text scales',
    (tester) async {
      for (final viewport in const [Size(360, 800), Size(320, 640)]) {
        for (final textScale in const [1.0, 1.3]) {
          setViewport(tester, viewport, textScale);
          final container = ProviderContainer();
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 208,
                    height: 600,
                    child: RetouchControls(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // The patch-selector chip row is also a Scrollable, so target the
          // vertical ListView explicitly for both scroll directions.
          final verticalList = find.byWidgetPredicate(
            (w) => w is Scrollable && w.axis == Axis.vertical,
          );

          // Add a patch so Delete Patch + Clear All render. The list may carry
          // the previous iteration's scroll offset, so scroll the button back.
          final addHeal = find.byKey(const Key('retouch-add-heal'));
          await tester.scrollUntilVisible(addHeal, -200, scrollable: verticalList);
          await tester.pumpAndSettle();
          await tester.tap(addHeal);
          await tester.pumpAndSettle();
          expect(container.read(recipeControllerProvider).recipe.retouchPatches, hasLength(1));

          expect(tester.takeException(), isNull,
              reason: 'overflow at $viewport / textScale $textScale');

          // The footer lives at the end of a lazy ListView; scroll it into
          // the build window at narrow widths.
          final footer = find.text('1 patch applied');
          await tester.scrollUntilVisible(footer, 200, scrollable: verticalList);
          await tester.pumpAndSettle();

          expect(footer, findsOneWidget);
          expect(find.widgetWithText(TextButton, 'Delete Patch'), findsOneWidget);
          expect(find.widgetWithText(TextButton, 'Clear All'), findsOneWidget);
          expect(footer.hitTestable(), findsOneWidget);
          expect(
            find.widgetWithText(TextButton, 'Delete Patch').hitTestable(),
            findsOneWidget,
          );
          expect(
            find.widgetWithText(TextButton, 'Clear All').hitTestable(),
            findsOneWidget,
          );

          // Behavioural guard: the buttons stay tappable (not clipped away).
          final clearAll = find.widgetWithText(TextButton, 'Clear All');
          await tester.ensureVisible(clearAll);
          await tester.pumpAndSettle();
          await tester.tap(clearAll);
          await tester.pumpAndSettle();
          expect(container.read(recipeControllerProvider).recipe.retouchPatches, isEmpty);
        }
      }
    },
  );
}
