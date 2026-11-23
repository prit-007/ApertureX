import 'dart:typed_data';

import 'package:aperturex/color/blur_spec.dart';
import 'package:aperturex/edit/active_image.dart';
import 'package:aperturex/edit/lens_blur_controller.dart';
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
    // 3 ParameterControls visible (blurAmount, blurFocalPoint, blurFocalRange)
    // blurBokehBoost is inside collapsed Bokeh tile
    expect(find.byType(ParameterControl), findsNWidgets(3));

    // Expand Bokeh tile to reveal blurBokehBoost
    await tester.tap(find.byType(ExpansionTile).last);
    await tester.pumpAndSettle();
    expect(find.byType(ParameterControl), findsNWidgets(4));
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

  testWidgets('BlurControls uses ExpansionTile accordion grouping', (
    tester,
  ) async {
    await pumpBlurControls(tester);

    // At least one ExpansionTile should exist (Lens Blur section)
    expect(find.byType(ExpansionTile), findsAtLeastNWidgets(1));

    // Lens Blur tile starts expanded
    final lensBlurTile = tester.widget<ExpansionTile>(
      find.byType(ExpansionTile).first,
    );
    expect(lensBlurTile.initiallyExpanded, isTrue);
  });

  testWidgets('Subject Focus chip is present and handles empty photo', (
    tester,
  ) async {
    container.read(recipeControllerProvider.notifier).setBlurEnabled(true);
    await pumpBlurControls(tester);

    final aiDepthChip = find.byKey(const Key('blur-subject-focus'));
    expect(aiDepthChip, findsOneWidget);

    // Tap with no photo
    await tester.tap(aiDepthChip);
    await tester.pumpAndSettle();

    expect(find.text('No photo loaded to place focus'), findsOneWidget);
  });

  testWidgets('Subject Focus chip places the focal plane when image is present and consent granted', (tester) async {
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

    final aiDepthChip = find.byKey(const Key('blur-subject-focus'));
    expect(aiDepthChip, findsOneWidget);

    await tester.tap(aiDepthChip);
    await tester.pumpAndSettle();

    final recipe = customContainer.read(recipeControllerProvider).recipe;
    // cy is 0.4, focalPoint is 0.25 + 0.40 * 0.4 = 0.41
    expect(recipe.blurFocalPoint, closeTo(0.41, 0.01));
    // ry is 0.3, focalRange is 0.3 * 0.9 = 0.27
    expect(recipe.blurFocalRange, closeTo(0.27, 0.01));
    expect(recipe.blurAmount, 0.45);
    expect(find.textContaining('Subject focus placed'), findsOneWidget);
  });

  testWidgets('analyzeDepth completes before focal point is committed (no fire-and-forget race)', (
    tester,
  ) async {
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
        lensBlurControllerProvider.overrideWith(() => _MockLensBlurController()),
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

    final aiDepthChip = find.byKey(const Key('blur-subject-focus'));
    expect(aiDepthChip, findsOneWidget);

    await tester.tap(aiDepthChip);
    await tester.pumpAndSettle();

    // Depth confidence must be set by analyzeDepth (not 0.0 from synthetic fallback)
    final notifier = customContainer.read(lensBlurControllerProvider.notifier) as _MockLensBlurController;
    expect(notifier.analyzeDepthCompleted, isTrue);
    final state = customContainer.read(lensBlurControllerProvider);
    expect(state.depthConfidence, closeTo(0.95, 1e-4));
    expect(state.status, LensBlurStatus.ready);
    expect(state.cachedDepth, isNotNull);
  });

  testWidgets('BlurControls bokeh chips use VisualDensity.compact', (
    tester,
  ) async {
    container.read(recipeControllerProvider.notifier).setBlurEnabled(true);
    await pumpBlurControls(tester);

    // Expand the Bokeh tile to reveal chips
    await tester.tap(find.byType(ExpansionTile).last);
    await tester.pumpAndSettle();

    // BokehShape choice chips should be compact
    for (final shape in BokehShape.values) {
      final chip = tester.widget<ChoiceChip>(
        find.byWidgetPredicate(
          (widget) {
            if (widget is ChoiceChip) {
              final label = widget.label;
              return label is Text && label.data == shape.label;
            }
            return false;
          },
        ),
      );
      expect(chip.visualDensity, VisualDensity.compact);
    }
  });

  testWidgets('low-confidence depth banner renders when confidence < 0.35 and switches to gradient', (
    tester,
  ) async {
    container.read(recipeControllerProvider.notifier).setBlurEnabled(true);
    // Simulate low depth confidence < 0.35
    container.read(lensBlurControllerProvider.notifier).state =
        container.read(lensBlurControllerProvider).copyWith(depthConfidence: 0.20);

    await pumpBlurControls(tester);

    expect(find.byKey(const Key('low-confidence-banner')), findsOneWidget);
    expect(find.text('Switch to Gradient'), findsOneWidget);

    // Tap Switch to Gradient
    await tester.tap(find.text('Switch to Gradient'));
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.blurEnabled, isFalse);
  });

  testWidgets('FocusRingWidget pan gesture modulates blurFocalRange', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: FocusRingWidget(size: 200.0),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(FocusRingWidget), findsOneWidget);
    await tester.drag(find.byType(FocusRingWidget), const Offset(40, 0));
    await tester.pumpAndSettle();

    final range = container.read(recipeControllerProvider).recipe.blurFocalRange;
    expect(range, greaterThan(0.0));
  });
  testWidgets('FocusRingWidget pan gesture modulates both blurFocalPoint and blurFocalRange', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: FocusRingWidget(size: 200.0),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(FocusRingWidget), findsOneWidget);

    // Initial focal point is neutral (0.5)
    final initialPoint =
        container.read(recipeControllerProvider).recipe.blurFocalPoint;
    expect(initialPoint, closeTo(0.5, 1e-4));

    // Drag to top of ring (angle -pi/2): should change focalPoint from neutral
    await tester.drag(
      find.byType(FocusRingWidget),
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();

    final point =
        container.read(recipeControllerProvider).recipe.blurFocalPoint;
    final range =
        container.read(recipeControllerProvider).recipe.blurFocalRange;
    // Both focal point and focal range should have changed from neutral
    expect(point, isNot(closeTo(0.5, 0.01)),
        reason: 'dragging at an angle should change focalPoint from neutral');
    expect(range, greaterThan(0.0));
  });
}

class _MockLensBlurController extends LensBlurController {
  bool analyzeDepthCompleted = false;

  @override
  Future<void> analyzeDepth(
    Uint8List imageBytes, {
    int? handle,
    bool force = false,
  }) async {
    await Future.delayed(Duration.zero);
    state = state.copyWith(
      depthConfidence: 0.95,
      status: LensBlurStatus.ready,
      cachedDepth: Float32List.fromList([0.5]),
      depthWidth: 1,
      depthHeight: 1,
    );
    analyzeDepthCompleted = true;
  }
}

class _AlwaysGrantedConsentNotifier extends AiConsentNotifier {
  @override
  AiConsentStatus build() => AiConsentStatus.granted;

  @override
  Future<bool> requestConsentDialog(BuildContext context) async => true;
}
