import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/history_tree_sheet.dart';

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
}
