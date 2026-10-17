import 'package:flutter/material.dart' as fm;
import 'package:flutter/services.dart' show MethodCall, SystemChannels;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/features/presets/qr_scanner_sheet.dart';
import 'package:aperturex/ui/common/looks_sheet.dart';
import 'package:aperturex/ui/common/paste_button.dart';

const _lookJson =
    '{"name":"Shared look","description":"","params":{"exposure":0.4}}';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: [
          DefaultMaterialLocalizations.delegate,
          fm.DefaultMaterialLocalizations.delegate,
          fm.DefaultWidgetsLocalizations.delegate,
        ],
        home: Scaffold(body: LooksSheet()),
      ),
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

    await tester.scrollUntilVisible(
      find.byType(PasteButton),
      80.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PasteButton));
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, _lookJson);
  });

  testWidgets('pasting then importing applies the shared look', (tester) async {
    mockClipboard(tester, _lookJson);
    await pump(tester);

    await tester.scrollUntilVisible(
      find.byType(PasteButton),
      80.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PasteButton));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Import look'),
      80.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import look'));
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.exposure,
      closeTo(0.4, 1e-9),
    );
  });

  testWidgets('tapping Scan QR Look opens QrScannerSheet', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('scan-qr-look-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('scan-qr-look-button')));
    await tester.pumpAndSettle();

    expect(find.byType(QrScannerSheet), findsOneWidget);
  });

  testWidgets('tapping Share on a look opens PresetCardDialog with QR', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('share-look-qr-Punch')), findsOneWidget);
    await tester.tap(find.byKey(const Key('share-look-qr-Punch')));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Punch'), findsWidgets);
  });

  testWidgets('switching to Community Hub shows community presets and filters', (tester) async {
    await pump(tester);

    // Switch to Community Hub tab
    expect(find.text('Community Hub'), findsOneWidget);
    await tester.tap(find.text('Community Hub'));
    await tester.pumpAndSettle();

    // Verify community presets are displayed
    expect(find.text('Kodak Ektar 100'), findsOneWidget);

    // Filter by Moody
    await tester.tap(find.byKey(const Key('filter-category-Moody')));
    await tester.pumpAndSettle();

    expect(find.text('Nordic Pines'), findsOneWidget);
    expect(find.text('Kodak Ektar 100'), findsNothing);

    // Tap Apply on Nordic Pines
    await tester.tap(find.byKey(const Key('apply-community-moody_nordic')));
    await tester.pumpAndSettle();

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.contrast, closeTo(0.22, 0.001));
    expect(recipe.shadows, closeTo(-0.15, 0.001));
  });

  testWidgets('saving community look marks it saved', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Community Hub'));
    await tester.pumpAndSettle();

    final saveButton = find.byKey(const Key('download-community-film_ektar_100'));
    expect(saveButton, findsOneWidget);

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsOneWidget);
  });
}

