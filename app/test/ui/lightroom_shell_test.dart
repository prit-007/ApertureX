import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aperturex/ui/common/blur_controls.dart';
import 'package:aperturex/ui/common/color_grading_editor.dart';
import 'package:aperturex/ui/common/hsl_mixer.dart';
import 'package:aperturex/ui/common/optics_controls.dart';
import 'package:aperturex/ui/common/retouch_controls.dart';
import 'package:aperturex/ui/common/tone_curve_editor.dart';
import 'package:aperturex/ui/lightroom/lightroom_shell.dart';

/// Issue #44: the top chip row is derived solely from the `RecipeSection`
/// catalog, and Curve/Mix are secondary tabs inside the colour panels.
///
/// Regressed with the empty-tool fix: only sections that carry real controls
/// are chips. `tone` is intentionally absent — its Curve/Mix views live inside
/// Color (issue #44) and it carries no sliders of its own, so its panel used
/// to render empty; `optics` has controls now (issue #66).
void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: LightroomShell())),
      ),
    );
  }

  testWidgets('the top chip row covers every section that has real controls', (
    tester,
  ) async {
    await pump(tester);

    for (final label in const [
      'Light',
      'Color',
      'Retouch',
      'Blur',
      'Effects',
      'Detail',
      'Optics',
      'Geometry',
      'Masking',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'missing $label chip');
    }
  });

  testWidgets('empty section (Tone) is not offered as a chip, while Optics is offered', (
    tester,
  ) async {
    await pump(tester);

    // Tone has no sliders of its own (its views live in Color).
    // Optics has controls now and is present.
    expect(find.text('Tone'), findsNothing);
    expect(find.text('Optics'), findsOneWidget);
  });

  testWidgets('Optics section displays OpticsControls', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Optics'));
    await tester.pumpAndSettle();
    expect(find.byType(OpticsControls), findsOneWidget);
  });

  testWidgets('Retouch section displays RetouchControls', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Retouch'));
    await tester.pumpAndSettle();
    expect(find.byType(RetouchControls), findsOneWidget);
  });

  testWidgets('Blur section displays BlurControls', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Blur'));
    await tester.pumpAndSettle();
    expect(find.byType(BlurControls), findsOneWidget);
  });

  testWidgets(
    'Curve, Mix, and Grade live inside the Color panel, not the top row',
    (tester) async {
      await pump(tester);

      // No Curve/Mix/Grade chips until a colour section is open.
      expect(find.text('Curve'), findsNothing);
      expect(find.text('Mix'), findsNothing);
      expect(find.text('Grade'), findsNothing);

      await tester.tap(find.text('Color'));
      await tester.pumpAndSettle();

      expect(find.text('Curve'), findsOneWidget);
      expect(find.text('Mix'), findsOneWidget);
      expect(find.text('Grade'), findsOneWidget);

      await tester.tap(find.text('Curve'));
      await tester.pumpAndSettle();
      expect(find.byType(ToneCurveEditor), findsOneWidget);

      await tester.tap(find.text('Mix'));
      await tester.pumpAndSettle();
      expect(find.byType(HslMixer), findsOneWidget);

      await tester.tap(find.text('Grade'));
      await tester.pumpAndSettle();
      expect(find.byType(ColorGradingEditor), findsOneWidget);
    },
  );
}
