import 'dart:typed_data';

import 'package:aperturex/color/blur_spec.dart';
import 'package:aperturex/edit/active_image.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/settings/ai_consent.dart';
import 'package:aperturex/src/rust/api/mask.dart' as rust_mask;
import 'package:aperturex/ui/common/blur_controls.dart';
import 'package:aperturex/ui/common/parameter_control.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> pumpBlurControls(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: BlurControls(),
          ),
        ),
      ),
    );
  }

  testWidgets('BlurControls toggle enables and disables lens blur controls', (
    tester,
  ) async {
    await pumpBlurControls(tester);

    // Initially disabled, so parameter controls for blur should not be rendered
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.byType(ParameterControl), findsNothing);
    expect(container.read(recipeControllerProvider).recipe.blurEnabled, isFalse);

    // Toggle switch on
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.blurEnabled, isTrue);
    expect(find.byType(ParameterControl), findsNWidgets(4));

    // Verify all BokehShape chips are present
    for (final shape in BokehShape.values) {
      expect(find.text(shape.label), findsOneWidget);
    }

    // Tap Hexagon shape chip
    await tester.tap(find.text('6 Blade'));
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.blurBokehShape,
      BokehShape.hexagon.index,
    );
  });

  testWidgets('Calibrate Embedded Depth chip is present when blur is enabled', (tester) async {
    container.read(recipeControllerProvider.notifier).setBlurEnabled(true);
    await pumpBlurControls(tester);

    final depthChip = find.byKey(const Key('blur-detect-depth'));
    expect(depthChip, findsOneWidget);

    await tester.tap(depthChip);
    await tester.pumpAndSettle();

    expect(find.text('No photo loaded to read depth metadata'), findsOneWidget);
  });

  testWidgets('AI Depth Estimation chip is present and handles empty photo and active calibration', (tester) async {
    container.read(recipeControllerProvider.notifier).setBlurEnabled(true);
    await pumpBlurControls(tester);

    final aiDepthChip = find.byKey(const Key('blur-ai-depth'));
    expect(aiDepthChip, findsOneWidget);

    // Tap with no photo
    await tester.tap(aiDepthChip);
    await tester.pumpAndSettle();

    expect(find.text('No photo loaded to analyze depth'), findsOneWidget);
  });

  testWidgets('AI Depth Estimation chip calibrates focal plane when image is present and consent granted', (tester) async {
    const fakeSubject = rust_mask.DetectedSubject(
      cx: 0.5,
      cy: 0.4,
      rx: 0.2,
      ry: 0.3,
      feather: 0.1,
    );
    final customContainer = ProviderContainer(
      overrides: [
        aiConsentProvider.overrideWith(_AlwaysGrantedConsentNotifier.new),
        subjectDetectorProvider.overrideWithValue((bytes) async => fakeSubject),
      ],
    );
    addTearDown(customContainer.dispose);
    customContainer.read(recipeControllerProvider.notifier).setBlurEnabled(true);
    customContainer.read(activeImageBytesProvider.notifier).setBytes(Uint8List.fromList([1, 2, 3, 4]));

    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: customContainer,
        child: const MaterialApp(
          home: Scaffold(
            body: BlurControls(),
          ),
        ),
      ),
    );

    final aiDepthChip = find.byKey(const Key('blur-ai-depth'));
    expect(aiDepthChip, findsOneWidget);

    await tester.tap(aiDepthChip);
    await tester.pumpAndSettle();

    final recipe = customContainer.read(recipeControllerProvider).recipe;
    // cy is 0.4, focalPoint is 0.25 + 0.40 * 0.4 = 0.41
    expect(recipe.blurFocalPoint, closeTo(0.41, 0.01));
    // ry is 0.3, focalRange is 0.3 * 0.9 = 0.27
    expect(recipe.blurFocalRange, closeTo(0.27, 0.01));
    expect(recipe.blurAmount, 0.45);
    expect(find.textContaining('AI Depth calibrated'), findsOneWidget);
  });
}

class _AlwaysGrantedConsentNotifier extends AiConsentNotifier {
  @override
  AiConsentStatus build() => AiConsentStatus.granted;

  @override
  Future<bool> requestConsentDialog(BuildContext context) async => true;
}
