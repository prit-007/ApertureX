import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/edit/retouch_patch.dart';
import 'package:aperturex/ui/common/retouch_controls.dart';
import 'package:aperturex/ui/common/retouch_toolbar.dart';

import '../helpers/viewport_harness.dart';

void main() {
  testWidgets('RetouchToolbar adds spot, switches modes, and deletes patch', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RetouchToolbar(),
            ),
          ),
        ),
      ),
    );

    // Initial state: no patches
    expect(container.read(recipeControllerProvider).recipe.retouchPatches, isEmpty);

    // Tap "Add"
    await tester.tap(find.byKey(const Key('retouch-toolbar-add')));
    await tester.pumpAndSettle();

    final patches = container.read(recipeControllerProvider).recipe.retouchPatches;
    expect(patches.length, 1);
    expect(container.read(selectedRetouchPatchIndexProvider), 0);

    // Delete button should now be visible
    expect(find.byKey(const Key('retouch-toolbar-delete')), findsOneWidget);

    // Switch mode to Clone
    await tester.tap(find.byKey(const Key('retouch-toolbar-clone')));
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.retouchPatches.first.mode,
      RetouchMode.clone,
    );

    // Tap Delete
    await tester.tap(find.byKey(const Key('retouch-toolbar-delete')));
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.retouchPatches, isEmpty);
    expect(container.read(selectedRetouchPatchIndexProvider), isNull);
  });

  testWidgets(
    'toolbar renders and scrolls horizontally on a 320dp / 1.3x viewport',
    (tester) async {
      setViewport(tester, const Size(320, 640), 1.3);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: RetouchToolbar(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Create a patch via the existing add action so the Delete button renders.
      await tester.tap(find.byKey(const Key('retouch-toolbar-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('retouch-toolbar-delete')), findsOneWidget);
      expect(tester.takeException(), isNull);

      final scrollable = find.descendant(
        of: find.byKey(const Key('retouch-toolbar')),
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
    },
  );
}
