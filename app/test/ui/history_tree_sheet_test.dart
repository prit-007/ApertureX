import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/history_tree_sheet.dart';

import '../helpers/viewport_harness.dart';

void main() {
  testWidgets('HistoryTreeSheet renders branches and nodes, switches branches and jumps nodes', (tester) async {
    final container = ProviderContainer();
    final controller = container.read(recipeControllerProvider.notifier);

    // Setup history: Original -> Step 1 -> branch 'moody' -> Step B
    controller.update(Parameter.exposure, 0.5);
    controller.commit(label: 'Exposure +0.5');

    controller.createBranch('moody');
    controller.update(Parameter.saturation, -1.0);
    controller.commit(label: 'Desaturate B&W');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => HistoryTreeSheet.show(context),
                child: const Text('Open History'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open History'));
    await tester.pumpAndSettle();

    expect(find.text('Edit History & Branches'), findsOneWidget);
    expect(find.text('moody'), findsWidgets);
    expect(find.text('main'), findsWidgets);
    expect(find.text('Desaturate B&W'), findsOneWidget);

    // Switch branch to 'main'
    await tester.tap(find.text('main').first);
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).historyTree?.activeBranch, 'main');
    expect(find.text('Exposure +0.5'), findsOneWidget);

    // Tap on 'Original' to jump back to root node
    await tester.tap(find.text('Original'));
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.exposure, 0.0);
  });

  testWidgets(
    'commit metadata wraps at phone viewports and text scales with long branch names',
    (tester) async {
      for (final viewport in const [Size(360, 800), Size(320, 640)]) {
        for (final textScale in const [1.0, 1.3]) {
          setViewport(tester, viewport, textScale);
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final controller = container.read(recipeControllerProvider.notifier);

          controller.update(Parameter.exposure, 0.5);
          controller.commit(label: 'Exposure +0.5');
          controller.createBranch('a-very-long-branch-name-for-overflow');
          controller.update(Parameter.saturation, -1.0);
          controller.commit(label: 'Desaturate');

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () => HistoryTreeSheet.show(context),
                      child: const Text('Open History'),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open History'));
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: 'overflow at $viewport / textScale $textScale',
          );
          expect(
            find.text('a-very-long-branch-name-for-overflow'),
            findsWidgets,
          );
          expect(find.text('· branch head'), findsAtLeastNWidgets(1));

          // The root card sits at the end of a lazy ListView.builder; scroll
          // it into the build window at smaller scales. Target the vertical
          // Scrollable explicitly (the branch chip row scrolls horizontally).
          final originalSuffix = find.text('· original unedited');
          final verticalList = find.byWidgetPredicate(
            (w) => w is Scrollable && w.axis == Axis.vertical,
          );
          await tester.scrollUntilVisible(originalSuffix, 200, scrollable: verticalList);
          await tester.pumpAndSettle();
          expect(originalSuffix, findsOneWidget);

          // Dismiss the sheet before the next viewport iteration.
          final sheetContext = tester.element(
            find.text('· original unedited'),
          );
          Navigator.of(sheetContext).pop();
          await tester.pumpAndSettle();
        }
      }
    },
  );
}
