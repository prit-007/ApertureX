import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:aperturex/edit/node_editor.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/mask_controls.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> pumpMaskControls(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 1000,
              child: MaskControls(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('handles multiple masks in the mask stack and allows selecting between them', (
    tester,
  ) async {
    final notifier = container.read(recipeControllerProvider.notifier);
    notifier.addLayer(
      const AdjustmentLayer(
        maskKind: MaskKind.linear,
        exposure: 0.5,
      ),
    );
    notifier.addLayer(
      const AdjustmentLayer(
        maskKind: MaskKind.radial,
        exposure: -0.7,
      ),
    );

    await pumpMaskControls(tester);

    // Both layers rendered in the stack
    expect(find.textContaining('LINEAR', findRichText: true), findsOneWidget);
    expect(find.textContaining('RADIAL', findRichText: true), findsOneWidget);

    // Select second layer (Radial)
    await tester.tap(find.textContaining('RADIAL', findRichText: true));
    await tester.pumpAndSettle();

    expect(container.read(nodeEditorProvider).selected, 1);
  });

  testWidgets('Invert / reverse toggle updates layer inverted status', (tester) async {
    final notifier = container.read(recipeControllerProvider.notifier);
    notifier.addLayer(
      const AdjustmentLayer(
        maskKind: MaskKind.radial,
        inverted: false,
      ),
    );
    container.read(nodeEditorProvider.notifier).enable();
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpMaskControls(tester);

    final invertChip = find.byKey(const Key('mask-inline-invert'));
    expect(invertChip, findsOneWidget);

    await tester.tap(invertChip);
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.layers.first.inverted, isTrue);
  });

  testWidgets('Duplicate mask adds a clone to the mask stack', (tester) async {
    final notifier = container.read(recipeControllerProvider.notifier);
    notifier.addLayer(
      const AdjustmentLayer(
        maskKind: MaskKind.radial,
        exposure: 0.8,
        contrast: 0.3,
      ),
    );
    container.read(nodeEditorProvider.notifier).enable();
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpMaskControls(tester);

    final dupBtn = find.byKey(const Key('mask-duplicate-0'));
    expect(dupBtn, findsOneWidget);

    await tester.tap(dupBtn);
    await tester.pumpAndSettle();

    final layers = container.read(recipeControllerProvider).recipe.layers;
    expect(layers.length, 2);
    expect(layers[1].maskKind, MaskKind.radial);
    expect(layers[1].exposure, 0.8);
    expect(layers[1].contrast, 0.3);
  });

  testWidgets('Light controls (Exposure, Contrast, Highlights, Shadows) update selected mask', (
    tester,
  ) async {
    final notifier = container.read(recipeControllerProvider.notifier);
    notifier.addLayer(
      const AdjustmentLayer(
        maskKind: MaskKind.radial,
      ),
    );
    container.read(nodeEditorProvider.notifier).enable();
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpMaskControls(tester);

    expect(find.byKey(const Key('mask-inline-exposure-slider')), findsOneWidget);
    expect(find.byKey(const Key('mask-inline-contrast-slider')), findsOneWidget);
    expect(find.byKey(const Key('mask-inline-highlights-slider')), findsOneWidget);
    expect(find.byKey(const Key('mask-inline-shadows-slider')), findsOneWidget);

    // Drag highlights
    await tester.drag(
      find.byKey(const Key('mask-inline-highlights-slider')),
      const Offset(80, 0),
    );
    await tester.pumpAndSettle();

    final layer = container.read(recipeControllerProvider).recipe.layers.first;
    expect(layer.highlights, greaterThan(0.0));
  });

  testWidgets('Color controls (Temperature, Tint, Saturation) update selected mask', (
    tester,
  ) async {
    final notifier = container.read(recipeControllerProvider.notifier);
    notifier.addLayer(
      const AdjustmentLayer(
        maskKind: MaskKind.radial,
      ),
    );
    container.read(nodeEditorProvider.notifier).enable();
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpMaskControls(tester);

    expect(find.byKey(const Key('mask-inline-temp-slider')), findsOneWidget);
    expect(find.byKey(const Key('mask-inline-tint-slider')), findsOneWidget);
    expect(find.byKey(const Key('mask-inline-saturation-slider')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('mask-inline-temp-slider')));
    await tester.pumpAndSettle();

    // Drag temperature
    await tester.drag(
      find.byKey(const Key('mask-inline-temp-slider')),
      const Offset(80, 0),
    );
    await tester.pumpAndSettle();

    final layer = container.read(recipeControllerProvider).recipe.layers.first;
    expect(layer.temperature, greaterThan(0.0));
  });

  testWidgets('Delete button removes layer from mask stack', (tester) async {
    final notifier = container.read(recipeControllerProvider.notifier);
    notifier.addLayer(
      const AdjustmentLayer(
        maskKind: MaskKind.radial,
      ),
    );

    await pumpMaskControls(tester);

    final delBtn = find.byKey(const Key('mask-delete-0'));
    expect(delBtn, findsOneWidget);

    await tester.tap(delBtn);
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.layers, isEmpty);
  });

  testWidgets('Depth + button is present in the mask creation tray', (tester) async {
    await pumpMaskControls(tester);

    final depthBtn = find.byKey(const Key('mask-add-depth'));
    expect(depthBtn, findsOneWidget);

    await tester.tap(depthBtn);
    await tester.pumpAndSettle();

    // No photo loaded shows snackbar
    expect(find.text('No photo loaded for depth extraction'), findsOneWidget);
  });

  testWidgets('Background + button adds an inverted subject mask to the stack', (tester) async {
    await pumpMaskControls(tester);

    final bgBtn = find.byKey(const Key('mask-add-background'));
    expect(bgBtn, findsOneWidget);

    await tester.tap(bgBtn);
    await tester.pumpAndSettle();

    final layers = container.read(recipeControllerProvider).recipe.layers;
    expect(layers.length, 1);
    expect(layers.first.maskKind, MaskKind.subject);
    expect(layers.first.inverted, isTrue);
  });

  testWidgets('Amount slider displays 100% and updates layer amount', (tester) async {
    final notifier = container.read(recipeControllerProvider.notifier);
    notifier.addLayer(
      const AdjustmentLayer(
        maskKind: MaskKind.radial,
        exposure: 0.5,
      ),
    );
    container.read(nodeEditorProvider.notifier).enable();
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpMaskControls(tester);

    // Initial value is 100%
    expect(find.text('100%'), findsOneWidget);

    final amountSlider = find.byKey(const Key('mask-inline-amount-slider'));
    expect(amountSlider, findsOneWidget);

    // Drag slider to ~50%
    await tester.drag(amountSlider, const Offset(-50, 0));
    await tester.pumpAndSettle();

    final updatedLayer = container.read(recipeControllerProvider).recipe.layers.first;
    expect(updatedLayer.amount, isNot(1.0));
  });

  testWidgets('New Group + button creates a new MaskGroup in recipe', (tester) async {
    await pumpMaskControls(tester);

    final newGroupBtn = find.byKey(const Key('mask-new-group'));
    expect(newGroupBtn, findsOneWidget);

    await tester.tap(newGroupBtn);
    await tester.pumpAndSettle();

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.maskGroups.length, 1);
    expect(recipe.maskGroups.first.name, 'Mask 1');
  });

  testWidgets('MaskGroup card displays group controls and updates group amount and invert', (tester) async {
    final notifier = container.read(recipeControllerProvider.notifier);
    const group = MaskGroup(id: 'g_test', name: 'Mask 1', amount: 1.0);
    notifier.addMaskGroup(group);
    notifier.addLayerToGroup(
      groupId: 'g_test',
      layer: const AdjustmentLayer(maskKind: MaskKind.radial, exposure: 0.6),
      joinOp: MaskJoinOp.add,
    );

    await pumpMaskControls(tester);

    // Group header rendered
    expect(find.byKey(const Key('group-title-g_test')), findsOneWidget);
    expect(find.text('Mask 1'), findsOneWidget);

    // Group Invert toggle
    final invertBtn = find.byKey(const Key('group-invert-g_test'));
    expect(invertBtn, findsOneWidget);
    await tester.tap(invertBtn);
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.maskGroups.first.inverted, isTrue);

    // Group Amount slider
    final amtSlider = find.byKey(const Key('group-amount-g_test'));
    expect(amtSlider, findsOneWidget);
    await tester.drag(amtSlider, const Offset(60, 0));
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.maskGroups.first.amount, greaterThan(1.0));

    // Member layer join operation chips (Add, Subtract, Intersect)
    final addChip = find.byKey(const Key('mask-join-add-0'));
    final subChip = find.byKey(const Key('mask-join-subtract-0'));
    final intChip = find.byKey(const Key('mask-join-intersect-0'));
    expect(addChip, findsOneWidget);
    expect(subChip, findsOneWidget);
    expect(intChip, findsOneWidget);

    // Switch joinOp to Subtract
    await tester.scrollUntilVisible(subChip, 100);
    await tester.pumpAndSettle();
    await tester.tap(subChip);
    await tester.pumpAndSettle();
    expect(container.read(recipeControllerProvider).recipe.layers.first.joinOp, MaskJoinOp.subtract);

    // Switch joinOp to Intersect
    await tester.scrollUntilVisible(intChip, 100);
    await tester.pumpAndSettle();
    await tester.tap(intChip);
    await tester.pumpAndSettle();
    expect(container.read(recipeControllerProvider).recipe.layers.first.joinOp, MaskJoinOp.intersect);

    // Group Delete removes group and member layer
    final delBtn = find.byKey(const Key('group-delete-g_test'));
    expect(delBtn, findsOneWidget);
    await tester.scrollUntilVisible(delBtn, 100);
    await tester.pumpAndSettle();
    await tester.tap(delBtn);
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.maskGroups, isEmpty);
    expect(container.read(recipeControllerProvider).recipe.layers, isEmpty);
  });

  testWidgets('Zone System controls render for luminance mask and tapping zone updates band', (tester) async {
    final notifier = container.read(recipeControllerProvider.notifier);
    notifier.addLayer(
      const AdjustmentLayer(
        maskKind: MaskKind.luminance,
        maskParams: [0.0, 0.4],
      ),
    );
    container.read(nodeEditorProvider.notifier).enable();
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpMaskControls(tester);

    // Zone chips 0 through 10
    for (var z = 0; z <= 10; z++) {
      expect(find.byKey(Key('mask-zone-chip-$z')), findsOneWidget);
    }

    // Sliders for Min Luma, Max Luma, Feather
    expect(find.byKey(const Key('mask-inline-luma-min-slider')), findsOneWidget);
    expect(find.byKey(const Key('mask-inline-luma-max-slider')), findsOneWidget);
    expect(find.byKey(const Key('mask-inline-luma-feather-slider')), findsOneWidget);
    expect(find.byKey(const Key('mask-luma-eyedropper')), findsOneWidget);

    // Initial zone is Zone 2 (midpoint of 0.0 and 0.4 is 0.2)
    final chip2 = tester.widget<ChoiceChip>(find.byKey(const Key('mask-zone-chip-2')));
    expect(chip2.selected, isTrue);

    // Tap Zone V (Zone 5)
    await tester.tap(find.byKey(const Key('mask-zone-chip-5')));
    await tester.pumpAndSettle();

    final updated = container.read(recipeControllerProvider).recipe.layers.first;
    expect(updated.lumaZone, 5);
    expect((updated.lumaMin - 0.45).abs(), lessThan(1e-3));
    expect((updated.lumaMax - 0.55).abs(), lessThan(1e-3));
  });

  testWidgets('renders per-mask color wheels and highlights/shadows on layer', (tester) async {
    final notifier = container.read(recipeControllerProvider.notifier);
    notifier.addLayer(
      const AdjustmentLayer(
        maskKind: MaskKind.radial,
        highlights: 0.2,
        shadows: -0.1,
      ),
    );
    container.read(nodeEditorProvider.notifier).enable();
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpMaskControls(tester);

    // Highlights and Shadows sliders exist
    expect(find.byKey(const Key('mask-inline-highlights-slider')), findsOneWidget);
    expect(find.byKey(const Key('mask-inline-shadows-slider')), findsOneWidget);

    // Color wheels controls exist
    expect(find.byKey(const Key('mask-grade-zone-segmented')), findsOneWidget);
    expect(find.byKey(const Key('mask-inline-grade-hue-slider')), findsOneWidget);
    expect(find.byKey(const Key('mask-inline-grade-sat-slider')), findsOneWidget);
    expect(find.byKey(const Key('mask-inline-grade-lum-slider')), findsOneWidget);
    expect(find.byKey(const Key('mask-inline-grade-blending-slider')), findsOneWidget);
    expect(find.byKey(const Key('mask-inline-grade-balance-slider')), findsOneWidget);

    // Adjust Highlights slider
    await tester.drag(find.byKey(const Key('mask-inline-highlights-slider')), const Offset(50, 0));
    await tester.pumpAndSettle();
    expect(container.read(recipeControllerProvider).recipe.layers.first.highlights, isNonZero);

    // Switch zone to Highlights on segmented button and adjust Hue
    final hiSegment = find.descendant(
      of: find.byKey(const Key('mask-grade-zone-segmented')),
      matching: find.text('Highlights'),
    );
    await tester.ensureVisible(hiSegment);
    await tester.tap(hiSegment);
    await tester.pumpAndSettle();
    final hueSlider = find.byKey(const Key('mask-inline-grade-hue-slider'));
    await tester.ensureVisible(hueSlider);
    await tester.drag(hueSlider, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(container.read(recipeControllerProvider).recipe.layers.first.gradeHighlightHue, greaterThan(0));
  });

  testWidgets('renders mask group color wheels and highlights/shadows', (tester) async {
    final notifier = container.read(recipeControllerProvider.notifier);
    const gid = 'group_ui_test';
    notifier.addMaskGroup(const MaskGroup(id: gid, name: 'Subject Group'));

    await pumpMaskControls(tester);

    // Group Highlights and Shadows sliders exist
    expect(find.byKey(const Key('group-highlights-group_ui_test')), findsOneWidget);
    expect(find.byKey(const Key('group-shadows-group_ui_test')), findsOneWidget);

    // Group Color Wheels controls exist
    expect(find.byKey(const Key('group-grade-zone-segmented-group_ui_test')), findsOneWidget);
    expect(find.byKey(const Key('group-grade-hue-group_ui_test')), findsOneWidget);
    expect(find.byKey(const Key('group-grade-blending-group_ui_test')), findsOneWidget);

    // Adjust group Highlights slider
    await tester.drag(find.byKey(const Key('group-highlights-group_ui_test')), const Offset(50, 0));
    await tester.pumpAndSettle();
    expect(container.read(recipeControllerProvider).recipe.maskGroups.first.highlights, isNonZero);
  });
}


