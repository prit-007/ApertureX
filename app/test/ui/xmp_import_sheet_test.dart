import 'package:flutter/services.dart' show MethodCall, SystemChannels;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/app_sheet.dart';
import 'package:aperturex/ui/common/xmp_import_sheet.dart';

const _xmp = '''
<rdf:Description xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/"
  crs:Exposure2012="+0.50" crs:Saturation="+15"/>
''';

void main() {
  testWidgets('applying a pasted .xmp loads the recipe', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmpImportSheet())),
      ),
    );

    await tester.enterText(find.byType(TextField), _xmp);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.exposure, 0.5);
    expect(recipe.saturation, closeTo(0.15, 1e-9));
  });

  testWidgets('the paste button fills the field from the clipboard', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, Object?>{'text': _xmp};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmpImportSheet())),
      ),
    );

    await tester.tap(find.byTooltip('Paste from clipboard'));
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, _xmp);
  });

  testWidgets('the compatibility report is a bottom sheet, not a dialog', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmpImportSheet())),
      ),
    );

    await tester.enterText(find.byType(TextField), _xmp);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    // Import sheet + report sheet (thumb-zone stack), never a dialog.
    expect(find.byType(AppSheet), findsNWidgets(2));
    expect(find.text('Preset compatibility'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Preset compatibility'), findsNothing);
  });

  testWidgets('applying a pasted .lrtemplate loads the recipe and shows compatibility report', (
    tester,
  ) async {
    const lrtemplate = '''
s = {
	value = {
		settings = {
			Exposure2012 = 0.8,
			Contrast2012 = -20,
		},
	},
}
''';
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: XmpImportSheet())),
      ),
    );

    await tester.enterText(find.byType(TextField), lrtemplate);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.exposure, 0.8);
    expect(recipe.contrast, closeTo(-0.20, 1e-6));
    expect(find.text('Preset compatibility'), findsOneWidget);
  });
}
