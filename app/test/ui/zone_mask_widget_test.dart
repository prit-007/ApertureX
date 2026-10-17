import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/gesture/zone_mask.dart';
import 'package:aperturex/settings/shell_preference.dart';
import 'package:aperturex/ui/app_shell.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    container
        .read(shellPreferenceProvider.notifier)
        .select(AppShellKind.snapseed);
  });

  tearDown(() => container.dispose());

  Future<void> pumpSnapseed(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: AppShell())),
    ),
  );

  testWidgets('displays targeting overlay when zone targeting is active', (
    tester,
  ) async {
    await pumpSnapseed(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Luminosity Mask'), findsNothing);

    container.read(zoneMaskProvider.notifier).beginTargeting(initialZone: 8);
    await tester.pump();

    expect(find.text('Zone 8 (80%) · Luminosity Mask'), findsOneWidget);

    container.read(zoneMaskProvider.notifier).updateDelta(35); // step down
    await tester.pump();

    expect(find.text('Zone 7 (70%) · Luminosity Mask'), findsOneWidget);
  });

  testWidgets('displays locked pill and removes locked mask on (×) button tap', (
    tester,
  ) async {
    await pumpSnapseed(tester);
    await tester.pump(const Duration(milliseconds: 300));

    container.read(zoneMaskProvider.notifier).beginTargeting(initialZone: 6);
    container.read(zoneMaskProvider.notifier).lockMask(container);
    await tester.pump();

    expect(find.textContaining('Zone 6 Mask Locked'), findsOneWidget);
    expect(find.byTooltip('Remove Zone Mask'), findsOneWidget);

    final layers = container.read(recipeControllerProvider).recipe.layers;
    expect(layers.length, 1);
    expect(layers.first.maskKind, MaskKind.luminance);

    await tester.tap(find.byTooltip('Remove Zone Mask'));
    await tester.pump();

    expect(find.textContaining('Zone 6 Mask Locked'), findsNothing);
    expect(container.read(recipeControllerProvider).recipe.layers, isEmpty);
  });
}
