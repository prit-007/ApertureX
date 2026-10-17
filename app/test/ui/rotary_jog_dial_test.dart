import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/parameter_control.dart';
import 'package:aperturex/ui/common/rotary_jog_dial.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  final List<MethodCall> hapticCalls = <MethodCall>[];

  setUp(() {
    container = ProviderContainer();
    hapticCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        hapticCalls.add(call);
      }
      return null;
    });
  });

  tearDown(() {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpJogDial(
    WidgetTester tester, {
    Parameter parameter = Parameter.exposure,
    JogDialDockEdge dockEdge = JogDialDockEdge.right,
    VoidCallback? onClose,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: RotaryJogDial(
              parameter: parameter,
              initialDockEdge: dockEdge,
              onClose: onClose,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('RotaryJogDial renders HUD readout, rotary wheel, and action buttons', (
    tester,
  ) async {
    await pumpJogDial(tester);

    expect(find.byKey(const Key('jog-dial-label')), findsOneWidget);
    expect(find.text('Exposure'), findsOneWidget);
    expect(find.byKey(const Key('jog-dial-value')), findsOneWidget);
    expect(find.text('+0.00'), findsOneWidget);

    expect(find.byKey(const Key('jog-dial-rotary-wheel')), findsOneWidget);
    expect(find.byKey(const Key('jog-dial-reset')), findsOneWidget);
    expect(find.byKey(const Key('jog-dial-gear-toggle')), findsOneWidget);
    expect(find.byKey(const Key('jog-dial-dock-toggle')), findsOneWidget);
    expect(find.byKey(const Key('jog-dial-close')), findsOneWidget);
  });

  testWidgets('RotaryJogDial toggles dock edge between right and left', (tester) async {
    await pumpJogDial(tester, dockEdge: JogDialDockEdge.right);

    // Initially docked on right: wheel center X is towards right edge
    final wheelInitial = tester.getCenter(find.byKey(const Key('jog-dial-rotary-wheel')));
    expect(wheelInitial.dx, greaterThan(200));

    // Tap dock toggle to flip to left edge
    await tester.tap(find.byKey(const Key('jog-dial-dock-toggle')));
    await tester.pumpAndSettle();

    final wheelLeft = tester.getCenter(find.byKey(const Key('jog-dial-rotary-wheel')));
    expect(wheelLeft.dx, lessThan(200));
  });

  testWidgets('RotaryJogDial drag scrubs parameter value in 0.1 increments and fires haptics', (
    tester,
  ) async {
    await pumpJogDial(tester);

    final wheel = find.byKey(const Key('jog-dial-rotary-wheel'));

    // Drag up/down on the wheel
    await tester.drag(wheel, const Offset(0, -60));
    await tester.pumpAndSettle();

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.exposure, greaterThan(0.0));
    expect(hapticCalls, isNotEmpty);
  });

  testWidgets('RotaryJogDial crossing 0.0 neutral triggers mediumImpact haptic', (
    tester,
  ) async {
    // Start from non-zero
    container.read(recipeControllerProvider.notifier).update(Parameter.exposure, 0.2);
    await pumpJogDial(tester);
    hapticCalls.clear();

    final wheel = find.byKey(const Key('jog-dial-rotary-wheel'));

    // Drag down to cross through 0.0 into negative
    await tester.drag(wheel, const Offset(0, 80));
    await tester.pumpAndSettle();

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.exposure, lessThan(0.0));

    // Confirm mediumImpact was triggered during crossing
    final mediumImpactCalls = hapticCalls.where(
      (c) => c.arguments == 'HapticFeedbackType.mediumImpact',
    );
    expect(mediumImpactCalls, isNotEmpty);
  });

  testWidgets('RotaryJogDial reset button restores parameter to 0.0', (tester) async {
    container.read(recipeControllerProvider.notifier).update(Parameter.exposure, 1.5);
    await pumpJogDial(tester);
    expect(find.text('+1.50'), findsOneWidget);

    await tester.tap(find.byKey(const Key('jog-dial-reset')));
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.exposure, 0.0);
    expect(find.text('+0.00'), findsOneWidget);
  });

  testWidgets('RotaryJogDial gear toggle switches between standard and fine gear', (
    tester,
  ) async {
    await pumpJogDial(tester);

    expect(find.text('0.1x'), findsOneWidget);

    await tester.tap(find.byKey(const Key('jog-dial-gear-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('0.01x'), findsOneWidget);
  });

  testWidgets('RotaryJogDial barrier tap or close button triggers onClose', (
    tester,
  ) async {
    var closed = false;
    await pumpJogDial(tester, onClose: () => closed = true);

    // Tap outside barrier on the left screen area
    await tester.tapAt(const Offset(40, 400));
    await tester.pumpAndSettle();
    expect(closed, isTrue);

    // Also verify close icon button triggers onClose
    closed = false;
    await tester.tap(find.byKey(const Key('jog-dial-close')));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
  });

  testWidgets('ParameterControl opens RotaryJogDial via jog dial button', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: ParameterControl(parameter: Parameter.exposure),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final jogBtn = find.byKey(const Key('param-jog-dial-exposure'));
    expect(jogBtn, findsOneWidget);

    await tester.tap(jogBtn);
    await tester.pumpAndSettle();

    expect(find.byType(RotaryJogDial), findsOneWidget);
    expect(find.byKey(const Key('jog-dial-label')), findsOneWidget);
  });
}
