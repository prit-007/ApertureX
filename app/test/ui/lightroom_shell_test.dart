import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aperturex/edit/active_image.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/blur_controls.dart';
import 'package:aperturex/ui/common/color_grading_editor.dart';
import 'package:aperturex/ui/common/film_controls.dart';
import 'package:aperturex/ui/common/hsl_mixer.dart';
import 'package:aperturex/ui/common/lab_controls.dart';
import 'package:aperturex/ui/common/mask_controls.dart';
import 'package:aperturex/ui/common/optics_controls.dart';
import 'package:aperturex/ui/common/retouch_controls.dart';
import 'package:aperturex/ui/common/tone_curve_editor.dart';
import 'package:aperturex/ui/lightroom/lightroom_shell.dart';

import '../helpers/viewport_harness.dart';

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

  testWidgets('the top chip row covers the 6 Master Tabs', (
    tester,
  ) async {
    await pump(tester);

    for (final label in const [
      'Light & Color',
      'Effects & Detail',
      'Crop & Geometry',
      'Pro Tools',
      'Masks',
      'Plugins',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'missing $label Master Tab');
    }
  });

  testWidgets('Auto Tone applies white balance suggestions', (tester) async {
    container = ProviderContainer(
      overrides: [
        autoToneProvider.overrideWithValue(
          (_) async => {
            'exposure': 0.4,
            'contrast': 0.2,
            'highlights': -0.3,
            'shadows': 0.3,
            'whites': 0.1,
            'blacks': -0.1,
            'temperature': 0.25,
            'tint': -0.15,
          },
        ),
      ],
    );
    container.read(activeImageBytesProvider.notifier).setBytes(Uint8List(1));
    await pump(tester);

    await tester.tap(
      find.byTooltip('Auto Tone: analyze image and apply balanced adjustments'),
    );
    await tester.pumpAndSettle();

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.exposure, closeTo(0.4, 1e-6));
    expect(recipe.temperature, closeTo(0.25, 1e-6));
    expect(recipe.tint, closeTo(-0.15, 1e-6));
  });

  testWidgets('Light & Color sub-tabs switch between Light, Color, Curve, Mix, and Grade', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Color'), findsOneWidget);
    expect(find.text('Curve'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);
    expect(find.text('Grade'), findsOneWidget);

    // Default is Light -> verify Light parameters are present
    expect(find.byKey(const Key('param-track-exposure')), findsOneWidget);
    expect(find.byKey(const Key('param-track-contrast')), findsOneWidget);

    // Tap Color -> verify Color parameters are present
    await tester.tap(find.text('Color'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('param-track-temperature')), findsOneWidget);
    expect(find.byKey(const Key('param-track-tint')), findsOneWidget);

    await tester.tap(find.text('Curve'));
    await tester.pumpAndSettle();
    expect(find.byType(ToneCurveEditor), findsOneWidget);

    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();
    expect(find.byType(HslMixer), findsOneWidget);

    await tester.tap(find.text('Grade'));
    await tester.pumpAndSettle();
    expect(find.byType(ColorGradingEditor), findsOneWidget);
  });

  testWidgets('Effects & Detail tab displays sub-tabs and controls', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Effects & Detail'));
    await tester.pumpAndSettle();

    expect(find.text('Effects'), findsOneWidget);
    expect(find.text('Detail'), findsOneWidget);
    expect(find.text('Blur'), findsOneWidget);
    expect(find.text('Film'), findsOneWidget);

    // Default is Effects -> verify Clarity
    expect(find.byKey(const Key('param-track-clarity')), findsOneWidget);

    // Tap Detail -> verify Sharpening
    await tester.tap(find.text('Detail'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('param-track-sharpen')), findsOneWidget);

    await tester.tap(find.text('Blur'));
    await tester.pumpAndSettle();
    expect(find.byType(BlurControls), findsOneWidget);

    await tester.tap(find.text('Film'));
    await tester.pumpAndSettle();
    expect(find.byType(FilmControls), findsOneWidget);
  });

  testWidgets('Crop & Geometry tab displays Straighten, Transform, and Perspective sub-tabs', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Crop & Geometry'));
    await tester.pumpAndSettle();

    expect(find.text('Straighten'), findsOneWidget);
    expect(find.text('Transform'), findsOneWidget);
    expect(find.text('Perspective'), findsOneWidget);

    // Default Straighten has auto-straighten & rotation dial ruler
    expect(find.byKey(const Key('geometry-auto-straighten')), findsOneWidget);
    expect(find.byKey(const Key('rotation-dial-ruler')), findsOneWidget);

    // Tap Transform has Rotate Left/Right & Flip H/V
    await tester.tap(find.text('Transform'));
    await tester.pumpAndSettle();
    expect(find.text('Left'), findsOneWidget);
    expect(find.text('Right'), findsOneWidget);
    expect(find.text('Flip H'), findsOneWidget);
    expect(find.text('Flip V'), findsOneWidget);

    // Tap Perspective has Perspective X and Skew X
    await tester.tap(find.text('Perspective'));
    await tester.pumpAndSettle();
    expect(find.text('Perspective X'), findsOneWidget);
    expect(find.text('Skew X'), findsOneWidget);
  });

  testWidgets('Pro Tools tab displays Retouch, Optics, and Shader Lab', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Pro Tools'));
    await tester.pumpAndSettle();

    expect(find.text('Retouch'), findsOneWidget);
    expect(find.text('Optics'), findsOneWidget);
    expect(find.text('Shader Lab'), findsOneWidget);

    await tester.tap(find.text('Retouch'));
    await tester.pumpAndSettle();
    expect(find.byType(RetouchControls), findsOneWidget);

    await tester.tap(find.text('Optics'));
    await tester.pumpAndSettle();
    expect(find.byType(OpticsControls), findsOneWidget);

    await tester.tap(find.text('Shader Lab'));
    await tester.pumpAndSettle();
    expect(find.byType(LabControls), findsOneWidget);
  });

  testWidgets('Masks tab displays MaskControls', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Masks'));
    await tester.pumpAndSettle();
    expect(find.byType(MaskControls), findsOneWidget);
  });

  testWidgets(
    'LightroomShell renders safely without RenderFlex overflow under small height constraints (h=63.9)',
    (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 426.7,
                height: 63.9,
                child: LightroomShell(),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'LightroomShell renders safely in a 240dp sidebar and the Curve tab stays tappable',
    (tester) async {
      for (final viewport in const [Size(360, 800), Size(320, 640)]) {
        for (final textScale in const [1.0, 1.3]) {
          setViewport(tester, viewport, textScale);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 240,
                    height: 520,
                    child: LightroomShell(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final curveTab = find.text('Curve');
          expect(
            curveTab,
            findsOneWidget,
            reason: 'Curve tab missing at $viewport / textScale $textScale',
          );
          // The sub-tab chip bar is a horizontal scroll view; reveal the chip
          // in the 240dp sidebar before tapping.
          await tester.ensureVisible(curveTab);
          await tester.pumpAndSettle();
          await tester.tap(curveTab);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'overflow at $viewport / textScale $textScale',
          );
        }
      }
    },
  );

  testWidgets(
    'applied dot indicator appears when section has adjustments and disappears when neutral',
    (tester) async {
      await pump(tester);
      // Neutral initially - no dot
      expect(find.byKey(const Key('applied-dot-light')), findsNothing);

      // Apply light adjustment
      container.read(recipeControllerProvider.notifier).loadRecipe(
            EditRecipe.neutral.copyWith(exposure: 1.2),
          );
      await tester.pumpAndSettle();

      // Dot appears
      expect(find.byKey(const Key('applied-dot-light')), findsOneWidget);
    },
  );

  testWidgets(
    'Cancel button reverts slider changes made in the editing session',
    (tester) async {
      await pump(tester);

      // Initially no changes, cancel is disabled
      final cancelBtnFinder = find.byKey(const Key('tray-cancel'));
      expect(cancelBtnFinder, findsOneWidget);
      expect(tester.widget<IconButton>(cancelBtnFinder).onPressed, isNull);

      // User modifies exposure slider in Light section
      container.read(recipeControllerProvider.notifier).update(
            Parameter.exposure,
            1.5,
          );
      await tester.pumpAndSettle();

      // Cancel button is now enabled
      expect(tester.widget<IconButton>(cancelBtnFinder).onPressed, isNotNull);

      // Tap Cancel
      await tester.tap(cancelBtnFinder);
      await tester.pumpAndSettle();

      // Exposure is reverted to baseline 0.0
      expect(container.read(recipeControllerProvider).recipe.exposure, 0.0);
    },
  );

  testWidgets(
    'Apply button commits session changes to history',
    (tester) async {
      await pump(tester);

      final applyBtn = find.byKey(const Key('tray-apply'));
      expect(applyBtn, findsOneWidget);
      expect(tester.widget<IconButton>(applyBtn).onPressed, isNull);

      // User modifies contrast
      container.read(recipeControllerProvider.notifier).update(
            Parameter.contrast,
            0.8,
          );
      await tester.pumpAndSettle();

      expect(tester.widget<IconButton>(applyBtn).onPressed, isNotNull);

      // Tap Apply
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      // Changes committed, cancel is disabled for committed state
      expect(container.read(recipeControllerProvider).recipe.contrast, 0.8);
      expect(cancelBtn(tester).onPressed, isNull);
    },
  );

  testWidgets(
    'sub-master tabs display individual applied dots and subtab cancel/apply actions',
    (tester) async {
      await pump(tester);

      // Initially neutral - no dot on Light or Color subtab or Master Tab
      expect(find.byKey(const Key('applied-dot-light')), findsNothing);
      expect(find.byKey(const Key('applied-dot-color')), findsNothing);
      expect(find.byKey(const Key('applied-dot-lightColor')), findsNothing);
      expect(find.byKey(const Key('subtab-cancel')), findsNothing);
      expect(find.byKey(const Key('subtab-apply')), findsNothing);

      // Modify Exposure in Light sub-tab
      container.read(recipeControllerProvider.notifier).update(
            Parameter.exposure,
            1.2,
          );
      await tester.pumpAndSettle();

      // Dot appears on Light sub-tab and on Master Tab
      expect(find.byKey(const Key('applied-dot-light')), findsOneWidget);
      expect(find.byKey(const Key('applied-dot-color')), findsNothing);
      expect(find.byKey(const Key('applied-dot-lightColor')), findsOneWidget);

      // Sub-tab Cancel and Apply buttons appear
      expect(find.byKey(const Key('subtab-cancel')), findsOneWidget);
      expect(find.byKey(const Key('subtab-apply')), findsOneWidget);

      // Tap subtab-cancel reverts changes
      await tester.tap(find.byKey(const Key('subtab-cancel')));
      await tester.pumpAndSettle();
      expect(container.read(recipeControllerProvider).recipe.exposure, 0.0);
      expect(find.byKey(const Key('applied-dot-light')), findsNothing);
      expect(find.byKey(const Key('applied-dot-lightColor')), findsNothing);
      expect(find.byKey(const Key('subtab-cancel')), findsNothing);

      // Now modify temperature in Color sub-tab
      await tester.tap(find.text('Color'));
      await tester.pumpAndSettle();
      container.read(recipeControllerProvider.notifier).update(
            Parameter.temperature,
            0.5,
          );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('applied-dot-color')), findsOneWidget);
      expect(find.byKey(const Key('applied-dot-lightColor')), findsOneWidget);
      expect(find.byKey(const Key('subtab-apply')), findsOneWidget);

      // Tap subtab-apply commits changes
      await tester.tap(find.byKey(const Key('subtab-apply')));
      await tester.pumpAndSettle();
      expect(container.read(recipeControllerProvider).recipe.temperature, 0.5);
      expect(find.byKey(const Key('subtab-apply')), findsNothing);
      expect(find.byKey(const Key('applied-dot-lightColor')), findsOneWidget);
    },
  );

  testWidgets(
    'master tab switch is blocked while the active tab has uncommitted changes',
    (tester) async {
      await pump(tester);

      // Switch to Effects & Detail first
      await tester.tap(find.text('Effects & Detail'));
      await tester.pumpAndSettle();

      // Modify exposure in Light & Color sub-tab (while on Effects tab)
      container.read(recipeControllerProvider.notifier).update(
            Parameter.exposure,
            1.5,
          );
      await tester.pumpAndSettle();

      // Light & Color chip should show modified dot and switching back should be blocked
      final lightColorChip = find.text('Light & Color');
      expect(lightColorChip, findsOneWidget);

      // Tap Light & Color while changes are uncommitted -> blocked, no tab switch
      await tester.tap(lightColorChip);
      await tester.pumpAndSettle();

      // Still on Effects & Detail (no switch)
      expect(find.byType(BlurControls), findsNothing);
      expect(container.read(recipeControllerProvider).recipe.exposure, 1.5);
    },
  );

  testWidgets(
    'apply commits and unlocks master tab navigation after blocked switch',
    (tester) async {
      await pump(tester);

      // Switch to Effects & Detail first
      await tester.tap(find.text('Effects & Detail'));
      await tester.pumpAndSettle();

      // Modify temperature in Color sub-tab
      await tester.tap(find.text('Light & Color'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Color'));
      await tester.pumpAndSettle();
      container.read(recipeControllerProvider.notifier).update(
            Parameter.temperature,
            0.5,
          );
      await tester.pumpAndSettle();

      // Try to switch to Effects & Detail while uncommitted -> dialog appears
      await tester.tap(find.text('Effects & Detail'));
      await tester.pumpAndSettle();
      expect(container.read(recipeControllerProvider).recipe.temperature, 0.5);

      // Apply via dialog
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(container.read(recipeControllerProvider).recipe.temperature, 0.5);

      // Now switching tabs is allowed
      await tester.tap(find.text('Effects & Detail'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'discard reverts and unlocks master tab navigation after blocked switch',
    (tester) async {
      await pump(tester);

      // Modify exposure in Light & Color
      container.read(recipeControllerProvider.notifier).update(
            Parameter.exposure,
            1.5,
          );
      await tester.pumpAndSettle();

      // Try to switch to Effects & Detail while uncommitted -> dialog appears
      await tester.tap(find.text('Effects & Detail'));
      await tester.pumpAndSettle();
      expect(container.read(recipeControllerProvider).recipe.exposure, 1.5);

      // Discard via dialog
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(container.read(recipeControllerProvider).recipe.exposure, 0.0);

      // Now switching tabs is allowed
      await tester.tap(find.text('Effects & Detail'));
      await tester.pumpAndSettle();
    },
  );
}

IconButton cancelBtn(WidgetTester tester) =>
    tester.widget<IconButton>(find.byKey(const Key('tray-cancel')));

