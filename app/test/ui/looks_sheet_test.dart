import 'package:flutter/services.dart' show MethodCall, SystemChannels;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/looks_sheet.dart';

const _lookJson =
    '{"name":"Shared look","description":"","params":{"exposure":0.4}}';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: LooksSheet())),
    ),
  );

  void mockClipboard(WidgetTester tester, String text) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.getData') return <String, Object?>{'text': text};
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  testWidgets('the paste button fills the look field from the clipboard', (
    tester,
  ) async {
    mockClipboard(tester, _lookJson);
    await pump(tester);

    await tester.tap(find.byTooltip('Paste from clipboard'));
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, _lookJson);
  });

  testWidgets('pasting then importing applies the shared look', (tester) async {
    mockClipboard(tester, _lookJson);
    await pump(tester);

    await tester.tap(find.byTooltip('Paste from clipboard'));
    await tester.pumpAndSettle();
    // The import button sits below the fold — the sheet's list scrolls.
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import look'));
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.exposure,
      closeTo(0.4, 1e-9),
    );
  });
}
