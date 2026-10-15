import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/precision_rotation_dial.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> pumpDial(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 80,
                child: PrecisionRotationDial(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('PrecisionRotationDial renders 0.0° initially and updates on drag', (
    tester,
  ) async {
    await pumpDial(tester);

    expect(find.text('0.0°'), findsOneWidget);

    // Drag horizontally to the left (rotate positive)
    await tester.drag(
      find.byKey(const Key('rotation-dial-ruler')),
      const Offset(-80, 0),
    );
    await tester.pumpAndSettle();

    final straighten =
        container.read(recipeControllerProvider).recipe.straighten;
    expect(straighten, isNonZero);
    expect(straighten.abs(), greaterThan(0.5));
  });

  testWidgets('tap reset button zeroes the straighten angle', (tester) async {
    container.read(recipeControllerProvider.notifier).setStraighten(14.5);
    await pumpDial(tester);

    expect(find.text('14.5°'), findsOneWidget);

    // Tap the angle display / reset button
    await tester.tap(find.byKey(const Key('rotation-dial-reset')));
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.straighten, 0.0);
    expect(find.text('0.0°'), findsOneWidget);
  });

  testWidgets('fine nudge buttons adjust angle by 0.1°', (tester) async {
    await pumpDial(tester);

    // Tap nudge plus
    await tester.tap(find.byKey(const Key('rotation-dial-nudge-plus')));
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.straighten,
      closeTo(0.1, 0.01),
    );

    // Tap nudge minus twice
    await tester.tap(find.byKey(const Key('rotation-dial-nudge-minus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rotation-dial-nudge-minus')));
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.straighten,
      closeTo(-0.1, 0.01),
    );
  });

  testWidgets('double-tap on ruler resets angle to 0.0°', (tester) async {
    container.read(recipeControllerProvider.notifier).setStraighten(8.2);
    await pumpDial(tester);
    expect(find.text('8.2°'), findsOneWidget);

    // Double tap on ruler
    await tester.tap(find.byKey(const Key('rotation-dial-ruler')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('rotation-dial-ruler')));
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.straighten, 0.0);
    expect(find.text('0.0°'), findsOneWidget);
  });

  testWidgets('precision mode toggle switches to ultra-fine control (0.03°/px)', (tester) async {
    await pumpDial(tester);

    // Precision mode toggle is present
    expect(find.byKey(const Key('rotation-dial-precision-toggle')), findsOneWidget);

    // Tap precision toggle to activate fine mode
    await tester.tap(find.byKey(const Key('rotation-dial-precision-toggle')));
    await tester.pumpAndSettle();

    // Drag 50 pixels
    await tester.drag(
      find.byKey(const Key('rotation-dial-ruler')),
      const Offset(-50, 0),
    );
    await tester.pumpAndSettle();

    final straightenFine = container.read(recipeControllerProvider).recipe.straighten;
    // With 0.03°/px minus touch slop, net drag produces ~0.9° (compared to ~4.5° in standard mode)
    expect(straightenFine.abs(), closeTo(0.9, 0.2));
  });
}
