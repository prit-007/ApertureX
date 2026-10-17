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
    await tester.tap(subChip);
    await tester.pumpAndSettle();
    expect(container.read(recipeControllerProvider).recipe.layers.first.joinOp, MaskJoinOp.subtract);

    // Switch joinOp to Intersect
    await tester.tap(intChip);
    await tester.pumpAndSettle();
    expect(container.read(recipeControllerProvider).recipe.layers.first.joinOp, MaskJoinOp.intersect);

    // Group Delete removes group and member layer
    final delBtn = find.byKey(const Key('group-delete-g_test'));
    expect(delBtn, findsOneWidget);
    await tester.tap(delBtn);
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.maskGroups, isEmpty);
    expect(container.read(recipeControllerProvider).recipe.layers, isEmpty);
  });
}


