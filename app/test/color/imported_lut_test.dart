import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/color/imported_lut.dart';
import 'package:aperturex/color/lut_atlas.dart';
import 'package:aperturex/ui/common/lut_import_sheet.dart';

const _identity2 = '''
LUT_3D_SIZE 2
0 0 0
1 0 0
0 1 0
1 1 0
0 0 1
1 0 1
0 1 1
1 1 1
''';

void main() {
  test('importedLutProvider starts empty, apply/clear work', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(importedLutProvider), isNull);
    final atlas = LutAtlas(size: 2, rgba: Uint8List(2 * 2 * 2 * 4));
    container.read(importedLutProvider.notifier).apply(atlas);
    expect(container.read(importedLutProvider), same(atlas));
    container.read(importedLutProvider.notifier).clear();
    expect(container.read(importedLutProvider), isNull);
  });

  testWidgets('applying pasted .cube sets the imported LUT', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: LutImportSheet())),
      ),
    );

    await tester.enterText(find.byType(TextField), _identity2);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(container.read(importedLutProvider), isNotNull);
  });
}
