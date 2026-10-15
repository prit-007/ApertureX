import 'dart:ui' show Color, ImageByteFormat, PictureRecorder;

import 'package:flutter/services.dart' show MethodCall, SystemChannels;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/muted_parameters.dart';
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

  testWidgets('tap-to-type selects the existing text so typing overwrites', (
    tester,
  ) async {
    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.contrast, 0.25);
    await tester.pumpWidget(_harness(container, Parameter.contrast));

    await tester.tap(find.byKey(const Key('param-value-contrast')));
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, '0.25');
    expect(editable.controller.selection.baseOffset, 0);
    expect(editable.controller.selection.extentOffset, '0.25'.length);
  });

  testWidgets('tap-to-type opens a bottom sheet, not a centred dialog', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(container, Parameter.contrast));

    await tester.tap(find.byKey(const Key('param-value-contrast')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
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

  testWidgets('long-pressing the label mutes it without losing the value', (
    tester,
  ) async {
    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.exposure, 2.5);
    await tester.pumpWidget(_harness(container, Parameter.exposure));

    final label = find.byKey(const Key('param-label-exposure'));
    await tester.longPress(label);
    await tester.pump();

    // Muted: bypassed in the render, value kept; label + readout dimmed to
    // 0.3 (no strikethrough — that reads as "deleted", not "bypassed").
    expect(
      container.read(mutedParametersProvider),
      contains(Parameter.exposure),
    );
    expect(container.read(recipeControllerProvider).recipe.exposure, 2.5);
    final labelText = tester.widget<Text>(find.text('Exposure'));
    expect(labelText.style?.decoration, isNot(TextDecoration.lineThrough));
    final labelOpacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Exposure'), matching: find.byType(Opacity)),
    );
    expect(labelOpacity.opacity, 0.3);
    final valueOpacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('+2.50'), matching: find.byType(Opacity)),
    );
    expect(valueOpacity.opacity, 0.3);

    // Double-tap restores it.
    await tester.tap(label);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(label);
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(mutedParametersProvider), isEmpty);
    expect(container.read(recipeControllerProvider).recipe.exposure, 2.5);
    expect(
      tester.widget<Text>(find.text('Exposure')).style?.decoration,
      TextDecoration.none,
    );
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: find.text('Exposure'), matching: find.byType(Opacity)),
          )
          .opacity,
      1.0,
    );
  });

  Future<Color> paintTrackPixel(WidgetTester tester, {required Key key}) async {
    final custom = tester.widget<CustomPaint>(
      find.descendant(of: find.byKey(key), matching: find.byType(CustomPaint)),
    );
    return tester.runAsync(() async {
      final recorder = PictureRecorder();
      custom.painter!.paint(Canvas(recorder), const Size(300, 36));
      final image = await recorder.endRecording().toImage(300, 36);
      final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
      final data = bytes!.buffer.asUint8List();
      // Centre pixel = the neutral marker: the fill (and thumb) sit here.
      const cx = 150, cy = 18;
      final i = (cy * 300 + cx) * 4;
      return Color.fromARGB(data[i + 3], data[i], data[i + 1], data[i + 2]);
    }).then((c) => c!);
  }

  testWidgets('a muted parameter dims the track fill to the surface colour', (
    tester,
  ) async {
    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.exposure, 2.5);
    await tester.pumpWidget(_harness(container, Parameter.exposure));

    final scheme = Theme.of(
      tester.element(find.byKey(const Key('param-track-exposure'))),
    ).colorScheme;
    final active = await paintTrackPixel(
      tester,
      key: const Key('param-track-exposure'),
    );
    expect(active, scheme.primary);

    await tester.longPress(find.byKey(const Key('param-label-exposure')));
    await tester.pump();

    final bypassed = await paintTrackPixel(
      tester,
      key: const Key('param-track-exposure'),
    );
    expect(bypassed, scheme.surfaceContainerHighest);
    expect(bypassed, isNot(scheme.primary));
  });
}
