import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/parameter_panel.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: ParameterPanel(section: RecipeSection.detail),
        ),
      ),
    ),
  );

  testWidgets('renders all advanced sharpening controls and noise controls', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Sharpening'), findsOneWidget);
    expect(find.text('Radius'), findsOneWidget);
    expect(find.text('Detail'), findsOneWidget);
    expect(find.text('Masking'), findsOneWidget);
    expect(find.text('Noise (Luma)'), findsOneWidget);
    expect(find.text('Noise (Chroma)'), findsOneWidget);
  });

  testWidgets('dragging radius, detail, and masking tracks updates the recipe', (
    tester,
  ) async {
    await pump(tester);

    // Drag radius track
    final radiusTrack = find.byKey(const Key('param-track-sharpenRadius'));
    expect(radiusTrack, findsOneWidget);
    await tester.drag(radiusTrack, const Offset(60, 0));
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.sharpenRadius,
      greaterThan(1.0),
    );

    // Drag detail track
    final detailTrack = find.byKey(const Key('param-track-sharpenDetail'));
    expect(detailTrack, findsOneWidget);
    await tester.drag(detailTrack, const Offset(60, 0));
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.sharpenDetail,
      greaterThan(0.25),
    );

    // Drag masking track
    final maskingTrack = find.byKey(const Key('param-track-sharpenMasking'));
    expect(maskingTrack, findsOneWidget);
    await tester.drag(maskingTrack, const Offset(60, 0));
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.sharpenMasking,
      greaterThan(0.0),
    );
  });
}
