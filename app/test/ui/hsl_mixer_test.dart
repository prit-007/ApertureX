import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/hsl_mixer.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: HslMixer())),
    ),
  );

  testWidgets('moving the hue slider edits the selected band', (tester) async {
    await pump(tester);

    // The first Slider is Hue for the default band (red, index 0).
    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.hsl[0],
      greaterThan(0),
    );
  });

  testWidgets('selecting another band edits that band', (tester) async {
    await pump(tester);

    // Tap the third colour swatch (yellow, index 2).
    final swatches = find.byType(GestureDetector);
    await tester.tap(swatches.at(2));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pumpAndSettle();

    final hsl = container.read(recipeControllerProvider).recipe.hsl;
    expect(hsl[2 * 3], greaterThan(0)); // yellow hue
    expect(hsl[0], 0); // red untouched
  });

  testWidgets('band swatches keep a 30px circle in a 48px touch target', (
    tester,
  ) async {
    await pump(tester);

    final swatch = find.byType(GestureDetector).at(2);
    expect(tester.getSize(swatch), const Size(48, 48));
    final circle = find.descendant(of: swatch, matching: find.byType(Container));
    expect(tester.getSize(circle), const Size(30, 30));

    // A tap in the expanded corner (inside 48px, outside the 30px circle)
    // must still select the band.
    await tester.tapAt(tester.getCenter(swatch) + const Offset(20, 20));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pumpAndSettle();

    final hsl = container.read(recipeControllerProvider).recipe.hsl;
    expect(hsl[2 * 3], greaterThan(0)); // yellow hue
    expect(hsl[0], 0); // red untouched
  });
}
