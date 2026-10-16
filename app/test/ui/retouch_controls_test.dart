import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/edit/retouch_patch.dart';
import 'package:aperturex/ui/common/retouch_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
