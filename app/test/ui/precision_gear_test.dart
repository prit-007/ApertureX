import 'package:flutter/services.dart' show MethodCall, SystemChannels;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/parameter_control.dart';
import 'package:aperturex/ui/precision_gear.dart';

/// Mirrors production: [PrecisionListener] wraps the whole app so a finger
/// held *anywhere* counts toward the gear.
Widget _harness(
  ProviderContainer container, {
  List<Parameter> parameters = const [Parameter.exposure],
}) =>
    UncontrolledProviderScope(
      container: container,
      child: PrecisionListener(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final parameter in parameters)
                  ParameterControl(parameter: parameter),
              ],
            ),
          ),
        ),
      ),
    );

Key _badge(Parameter parameter) => Key('param-precision-${parameter.name}');

void main() {
  group('precision gear counting', () {
    test('engages at two pointers and never underflows', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final gear = container.read(precisionGearProvider.notifier);

      expect(precisionEngaged(container.read(precisionGearProvider)), isFalse);
      gear.begin();
      expect(container.read(precisionGearProvider), 1);
      expect(precisionEngaged(container.read(precisionGearProvider)), isFalse);

      gear.begin();
      expect(container.read(precisionGearProvider), 2);
      expect(precisionEngaged(container.read(precisionGearProvider)), isTrue);

      gear.end();
      expect(container.read(precisionGearProvider), 1);
      expect(precisionEngaged(container.read(precisionGearProvider)), isFalse);
      gear.end();
      expect(container.read(precisionGearProvider), 0);

      // A stray end (missed down) never drives the count negative — a
      // negative count would wedge the gear on forever.
      gear.end();
      expect(container.read(precisionGearProvider), 0);
    });
  });

  group('active track lease', () {
    test('a second track cannot claim while the first holds it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final lease = container.read(activeTrackProvider.notifier);

      expect(lease.claim(Parameter.exposure), isTrue);
      expect(lease.claim(Parameter.contrast), isFalse);

      lease.release(Parameter.exposure);
      expect(lease.claim(Parameter.contrast), isTrue);
      // Releasing a track that never held the lease is a no-op.
      lease.release(Parameter.exposure);
      expect(container.read(activeTrackProvider), Parameter.contrast);

      lease.release(Parameter.contrast);
      expect(container.read(activeTrackProvider), isNull);
      expect(lease.claim(Parameter.exposure), isTrue);
    });
  });

  testWidgets('a second finger held anywhere divides drag movement by 10', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(_harness(container));

    final track = find.byKey(const Key('param-track-exposure'));

    await tester.drag(track, const Offset(120, 0));
    await tester.pumpAndSettle();
    final full = container.read(recipeControllerProvider).recipe.exposure;
    expect(full, greaterThan(0));
    // Let the track's double-tap detector time out before the next gesture.
    await tester.pump(const Duration(milliseconds: 400));

    container
        .read(recipeControllerProvider.notifier)
        .reset(Parameter.exposure);
    await tester.pump();

    // One finger alone must not engage the gear...
    final hold = await tester.startGesture(const Offset(30, 550));
    await tester.pump();
    expect(find.byKey(_badge(Parameter.exposure)), findsNothing);

    // ...but the drag finger makes two, so the same 120px yields 1/10.
    await tester.drag(track, const Offset(120, 0));
    await tester.pumpAndSettle();
    final precise = container.read(recipeControllerProvider).recipe.exposure;
    expect(precise, closeTo(full / 10, full * 0.05));

    await hold.up();
    await tester.pump();
    expect(find.byKey(_badge(Parameter.exposure)), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets(
    'holding a second finger mid-drag engages the gear, ticks once, '
    'and slows the scrub',
    (tester) async {
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

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(_harness(container));

      final track = find.byKey(const Key('param-track-exposure'));
      final rect = tester.getRect(track);

      final drag = await tester.startGesture(rect.center);
      await tester.pump();
      // One starter move takes the gesture slop out of the measurement.
      await drag.moveBy(const Offset(30, 0));
      await tester.pump();

      final a0 = container.read(recipeControllerProvider).recipe.exposure;
      for (var i = 0; i < 3; i++) {
        await drag.moveBy(const Offset(30, 0));
        await tester.pump();
      }
      final a1 = container.read(recipeControllerProvider).recipe.exposure;
      final fullDelta = a1 - a0;
      expect(fullDelta, greaterThan(0));

      // The other hand lands mid-scrub: gear on (2 pointers).
      final hold = await tester.startGesture(const Offset(30, 550));
      await tester.pump();
      expect(find.byKey(_badge(Parameter.exposure)), findsOneWidget);

      // Exactly one tick — only the dragging track announces the engage.
      final ticks = platformCalls.where(
        (c) =>
            c.method == 'HapticFeedback.vibrate' &&
            c.arguments == 'HapticFeedbackType.selectionClick',
      );
      expect(ticks, hasLength(1));

      final b0 = container.read(recipeControllerProvider).recipe.exposure;
      for (var i = 0; i < 3; i++) {
        await drag.moveBy(const Offset(30, 0));
        await tester.pump();
      }
      final b1 = container.read(recipeControllerProvider).recipe.exposure;
      expect(b1 - b0, closeTo(fullDelta / 10, fullDelta * 0.05));

      await drag.up();
      await hold.up();
      await tester.pump();
      expect(find.byKey(_badge(Parameter.exposure)), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets('a second finger landing on another track cannot move it', (
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

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _harness(
        container,
        parameters: const [Parameter.exposure, Parameter.contrast],
      ),
    );

    final exposureRect = tester.getRect(
      find.byKey(const Key('param-track-exposure')),
    );
    final contrastRect = tester.getRect(
      find.byKey(const Key('param-track-contrast')),
    );

    // Finger 1 takes the lease on exposure and scrubs.
    final g1 = await tester.startGesture(exposureRect.center);
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await g1.moveBy(const Offset(30, 0));
      await tester.pump();
    }
    expect(
      container.read(recipeControllerProvider).recipe.exposure,
      greaterThan(0),
    );

    // Finger 2 lands on a *different* track and drags hard: rejected.
    final g2 = await tester.startGesture(contrastRect.center);
    await tester.pump();
    await g2.moveBy(const Offset(60, 0));
    await tester.pump();
    await g2.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(container.read(recipeControllerProvider).recipe.contrast, 0);
    // The primary scrub is unaffected.
    expect(
      container.read(recipeControllerProvider).recipe.exposure,
      greaterThan(0),
    );

    await g1.up();
    await g2.up();
    await tester.pump(const Duration(milliseconds: 400));

    // The lease came back: contrast scrubs normally on its own.
    await tester.drag(
      find.byKey(const Key('param-track-contrast')),
      const Offset(60, 0),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(recipeControllerProvider).recipe.contrast,
      greaterThan(0),
    );
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('a resting second finger on another track does not nudge it', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _harness(
        container,
        parameters: const [Parameter.exposure, Parameter.contrast],
      ),
    );

    final exposureRect = tester.getRect(
      find.byKey(const Key('param-track-exposure')),
    );
    final contrastRect = tester.getRect(
      find.byKey(const Key('param-track-contrast')),
    );

    // Finger 1 scrubs exposure (lease held, precision engages on finger 2).
    final g1 = await tester.startGesture(exposureRect.center);
    await tester.pump();
    await g1.moveBy(const Offset(30, 0));
    await tester.pump();

    // Finger 2 simply *rests* on contrast — lifting it must not nudge
    // the value by the 5% tap step. Pump past the tap's resolution window
    // so a late misfire would still be caught here.
    final g2 = await tester.startGesture(contrastRect.center);
    await tester.pump();
    await g2.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(recipeControllerProvider).recipe.contrast, 0);

    await g1.up();
    await tester.pump();

    // All fingers away: a normal single tap nudges again (the tap resolves
    // after the double-tap deadline, as in the other double-tap tests).
    await tester.tapAt(contrastRect.center + const Offset(50, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      container.read(recipeControllerProvider).recipe.contrast,
      greaterThan(0),
    );
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('the gear badge and 3-decimal readout follow pointer count', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.exposure, 0.25);
    await tester.pumpWidget(_harness(container));

    expect(find.text('+0.25'), findsOneWidget);
    expect(find.byKey(_badge(Parameter.exposure)), findsNothing);

    final first = await tester.startGesture(const Offset(30, 550));
    await tester.pump();
    // One pointer is not enough.
    expect(find.byKey(_badge(Parameter.exposure)), findsNothing);
    expect(find.text('+0.25'), findsOneWidget);

    final second = await tester.startGesture(const Offset(130, 550));
    await tester.pump();
    expect(find.byKey(_badge(Parameter.exposure)), findsOneWidget);
    expect(find.text('+0.250'), findsOneWidget);

    await first.up();
    await tester.pump();
    expect(find.byKey(_badge(Parameter.exposure)), findsNothing);
    expect(find.text('+0.25'), findsOneWidget);

    await second.up();
    await tester.pump(const Duration(milliseconds: 400));
  });
}
