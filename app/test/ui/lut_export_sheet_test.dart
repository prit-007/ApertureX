import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/lut_export_sheet.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('LutExportSheet renders size options and exports .cube', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: LutExportSheet(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Export Grade as .CUBE'), findsOneWidget);
    expect(find.text('33³ (Video/Resolve)'), findsOneWidget);
    expect(find.text('65³ (Master)'), findsOneWidget);
    expect(find.text('Copy .CUBE to Clipboard'), findsOneWidget);

    // Adjust exposure to make grade non-neutral
    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.exposure, 0.8);
    await tester.pumpAndSettle();

    // Tap copy
    await tester.tap(find.text('Copy .CUBE to Clipboard'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Copied 33³ .CUBE LUT to clipboard'), findsOneWidget);
  });
}
