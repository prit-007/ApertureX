import 'package:flutter/services.dart' show MethodCall, SystemChannels;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/parameter_control.dart';

Widget _harness(ProviderContainer container, Parameter parameter) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(body: ParameterControl(parameter: parameter)),
      ),
    );

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  testWidgets('renders the label and the current value', (tester) async {
    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.contrast, 0.25);

    await tester.pumpWidget(_harness(container, Parameter.contrast));

    expect(find.text('Contrast'), findsOneWidget);
    expect(find.text('+0.25'), findsOneWidget);
  });

  testWidgets('double-tap on the track resets the parameter', (tester) async {
    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.contrast, 0.6);
    await tester.pumpWidget(_harness(container, Parameter.contrast));

    final track = find.byKey(const Key('param-track-contrast'));
    await tester.tap(track);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(track);
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.contrast, 0);
  });

  testWidgets('dragging the track changes the value', (tester) async {
    await tester.pumpWidget(_harness(container, Parameter.exposure));

    await tester.drag(
      find.byKey(const Key('param-track-exposure')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.exposure,
      greaterThan(0),
    );
  });

  testWidgets('a drag commits to history so undo restores it', (tester) async {
    await tester.pumpWidget(_harness(container, Parameter.exposure));

    await tester.drag(
      find.byKey(const Key('param-track-exposure')),
      const Offset(100, 0),
    );
    await tester.pumpAndSettle();

    final controller = container.read(recipeControllerProvider.notifier);
    expect(container.read(recipeControllerProvider).index, greaterThan(0));
    expect(container.read(recipeControllerProvider).recipe.exposure,
        greaterThan(0));

    controller.undo();
    expect(container.read(recipeControllerProvider).recipe.exposure, 0);
  });

  testWidgets('tap-to-type sets an exact value', (tester) async {
    await tester.pumpWidget(_harness(container, Parameter.contrast));

    await tester.tap(find.byKey(const Key('param-value-contrast')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0.35');
    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.contrast,
      closeTo(0.35, 1e-9),
    );
  });

  testWidgets('tap-to-type clamps to the parameter range', (tester) async {
    await tester.pumpWidget(_harness(container, Parameter.contrast));

    await tester.tap(find.byKey(const Key('param-value-contrast')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '9');
    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.contrast,
      1.0,
    );
  });

  testWidgets('dragging toward the limit fires the haptic gradient', (
    tester,
  ) async {
    final platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(_harness(container, Parameter.exposure));
    final rect = tester.getRect(find.byKey(const Key('param-track-exposure')));

    final gesture = await tester.startGesture(
      Offset(rect.center.dx - rect.width / 4, rect.center.dy),
    );
    await tester.pump();
    // Push past the safe zone (±3 EV) first...
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
    }
    // ...then keep scrubbing while real time passes: the pacer runs on a
    // real Stopwatch and the widget-test zone fakes timers.
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(25, 0));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 160)),
      );
      await tester.pump();
    }
    await gesture.up();
    // Let the double-tap detector's timeout fire so no timer stays pending.
    await tester.pump(const Duration(milliseconds: 400));

    bool isSelectionClick(MethodCall call) =>
        call.method == 'HapticFeedback.vibrate' &&
        call.arguments == 'HapticFeedbackType.selectionClick';

    expect(platformCalls.where(isSelectionClick), isNotEmpty);
    expect(container.read(recipeControllerProvider).recipe.exposure, 4.0);
  });
}
