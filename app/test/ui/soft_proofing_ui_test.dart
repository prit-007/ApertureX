import 'package:aperturex/edit/active_image.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/lightroom/lightroom_shell.dart';
import 'package:aperturex/viewport/soft_proofing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Soft Proofing tray button opens modal sheet and toggles proofing', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        activeImageBytesProvider.overrideWith(ActiveImageBytesNotifier.new),
        recipeControllerProvider.overrideWith(RecipeController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Material(
              child: LightroomShell(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final softProofButton = find.byKey(const Key('tray-soft-proofing'));
    expect(softProofButton, findsOneWidget);

    // Open the soft proofing sheet
    await tester.tap(softProofButton);
    await tester.pumpAndSettle();

    expect(find.text('Soft Proofing'), findsOneWidget);
    expect(find.byKey(const Key('soft-proofing-toggle')), findsOneWidget);
    expect(find.byKey(const Key('soft-proofing-profile-dropdown')), findsOneWidget);
    expect(find.byKey(const Key('soft-proofing-intent-dropdown')), findsOneWidget);

    // Toggle enabled
    await tester.tap(find.byKey(const Key('soft-proofing-toggle')));
    await tester.pumpAndSettle();

    expect(container.read(softProofingProvider).enabled, isTrue);

    // Toggle gamut warning
    await tester.tap(find.byKey(const Key('soft-proofing-gamut-warning')));
    await tester.pumpAndSettle();

    expect(container.read(softProofingProvider).gamutWarning, isTrue);
  });
}
