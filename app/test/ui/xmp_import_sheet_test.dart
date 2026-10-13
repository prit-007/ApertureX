import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tessera/edit/recipe_controller.dart';
import 'package:tessera/ui/common/xmp_import_sheet.dart';

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
}
