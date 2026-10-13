import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tessera/edit/parameter.dart';
import 'package:tessera/edit/recipe_controller.dart';
import 'package:tessera/ui/snapseed/edit_hud.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: EditHud())),
    ),
  );

  testWidgets('shows only the parameters that were changed', (tester) async {
    await pump(tester);
    expect(find.textContaining('EXP'), findsNothing); // neutral -> empty

    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.exposure, 0.5);
    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.contrast, -0.2);
    await tester.pump();

    expect(find.textContaining('EXP'), findsOneWidget);
    expect(find.textContaining('CON'), findsOneWidget);
    expect(find.textContaining('SAT'), findsNothing);
  });
}
