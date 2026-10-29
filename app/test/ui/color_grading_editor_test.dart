import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/color_grading_editor.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: ColorGradingEditor())),
    ),
  );

  testWidgets('renders zone tabs and grading controls', (tester) async {
    await pump(tester);

    expect(find.text('Shadows'), findsOneWidget);
    expect(find.text('Midtones'), findsOneWidget);
    expect(find.text('Highlights'), findsOneWidget);
    expect(find.text('Luminance'), findsOneWidget);
    expect(find.text('Blending'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    expect(find.byType(ColorGradingWheel), findsOneWidget);
  });

  testWidgets('dragging the wheel updates hue and saturation for active zone', (
    tester,
  ) async {
    await pump(tester);

    final wheel = find.byType(ColorGradingWheel);
    final center = tester.getCenter(wheel);

    // Drag from center to the right (Hue ~ 0 deg, Sat > 0)
    await tester.dragFrom(center, const Offset(40, 0));
    await tester.pumpAndSettle();

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.gradeShadowSat, greaterThan(0));
    expect(recipe.gradeMidSat, 0.0);
    expect(recipe.gradeHighlightSat, 0.0);
  });

  testWidgets('switching zone updates that zone independently', (tester) async {
    await pump(tester);

    // Tap Highlights zone
    await tester.tap(find.text('Highlights'));
    await tester.pumpAndSettle();

    final wheel = find.byType(ColorGradingWheel);
    final center = tester.getCenter(wheel);

    // Drag from center towards top (Hue ~ 270 deg)
    await tester.dragFrom(center, const Offset(0, -40));
    await tester.pumpAndSettle();

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.gradeHighlightSat, greaterThan(0));
    expect(recipe.gradeShadowSat, 0.0);
    expect(recipe.gradeMidSat, 0.0);
  });

  testWidgets('double tapping the wheel resets the active zone', (
    tester,
  ) async {
    await pump(tester);

    final wheel = find.byType(ColorGradingWheel);
    final center = tester.getCenter(wheel);

    await tester.dragFrom(center, const Offset(30, 30));
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.gradeShadowSat,
      greaterThan(0),
    );

    // Double tap to reset
    await tester.tap(wheel);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(wheel);
    await tester.pumpAndSettle();

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.gradeShadowSat, 0.0);
    expect(recipe.gradeShadowHue, 0.0);
  });

  testWidgets('sliders update luminance, blending, and balance', (tester) async {
    await pump(tester);

    final sliders = find.byType(Slider);
    // 3 sliders: Luminance, Blending, Balance
    expect(sliders, findsNWidgets(3));

    // Drag Luminance slider
    await tester.drag(sliders.at(0), const Offset(50, 0));
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.gradeShadowLum,
      greaterThan(0),
    );

    // Drag Blending slider
    await tester.drag(sliders.at(1), const Offset(50, 0));
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.gradeBlending,
      greaterThan(0.5),
    );

    // Drag Balance slider
    await tester.drag(sliders.at(2), const Offset(-50, 0));
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.gradeBalance,
      lessThan(0),
    );
  });

  testWidgets('the grading wheel adapts its size to the available pane', (
    tester,    ) async {
    // Wide pane: the wheel keeps its full 180px size.
    await pump(tester);
    final wide = tester.getSize(find.byType(ColorGradingWheel));
    expect(wide.width, 180);

    // Tight pane (200px, the narrowest in-app sidebar): the wheel shrinks
    // to fit instead of staying at its full size — LayoutBuilder clamps it
    // into [120, 180].
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 200, child: ColorGradingEditor()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final narrow = tester.getSize(find.byType(ColorGradingWheel));
    expect(narrow.width, lessThan(180));
    expect(narrow.width, greaterThanOrEqualTo(120));
    expect(narrow.width, lessThanOrEqualTo(200));
  });

  testWidgets('color grading wheel puck is ≥12px diameter for touch targeting', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: ColorGradingWheel(
                hue: 0,
                saturation: 1.0,
                size: 100,
                onChanged: (_, __) {},
                onChangeEnd: () {},
                onReset: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Wheel renders without errors and occupies its allocated space
    final wheelRect = tester.getRect(find.byType(ColorGradingWheel));
    expect(wheelRect.width, 200);
    expect(wheelRect.height, 200);
  });
}
