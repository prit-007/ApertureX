import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/look_qr_codec.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/edit/tool_definition.dart';
import 'package:aperturex/features/presets/qr_scanner_sheet.dart';

void main() {
  group('QrScannerSheet', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    const sampleTool = ToolDefinition(
      name: 'Cinestill Glow',
      description: 'Halation and cool tones',
      params: {
        'exposure': 0.30,
        'filmHalation': 0.40,
        'temperature': -0.15,
      },
    );

    Future<void> pumpSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const QrScannerSheet(),
                  ),
                  child: const Text('Open Scanner'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open Scanner'));
      await tester.pumpAndSettle();
    }

    testWidgets('renders scan options (Image Picker and Direct URI input)', (tester) async {
      await pumpSheet(tester);

      expect(find.text('Scan / Import Look'), findsOneWidget);
      expect(find.byKey(const Key('pick-image-qr-button')), findsOneWidget);
      expect(find.byKey(const Key('qr-text-input')), findsOneWidget);
      expect(find.byKey(const Key('parse-qr-text-button')), findsOneWidget);
    });

    testWidgets('pasting a valid apx:// URI decodes and applies look to recipe', (tester) async {
      await pumpSheet(tester);

      final uri = LookQrCodec.encodeToUri(sampleTool, author: '@cinematographer');

      await tester.enterText(find.byKey(const Key('qr-text-input')), uri);
      await tester.pump();
      await tester.tap(find.byKey(const Key('parse-qr-text-button')));
      await tester.pumpAndSettle();

      // Look preview card is shown with name, author, and parameter preview
      expect(find.text('Cinestill Glow'), findsOneWidget);
      expect(find.textContaining('@cinematographer'), findsOneWidget);
      expect(find.textContaining('exposure: +0.3'), findsOneWidget);
      expect(find.byKey(const Key('apply-decoded-look-button')), findsOneWidget);

      // Tap apply
      await tester.ensureVisible(find.byKey(const Key('apply-decoded-look-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('apply-decoded-look-button')));
      await tester.pumpAndSettle();

      final currentRecipe = container.read(recipeControllerProvider).recipe;
      expect(currentRecipe.exposure, closeTo(0.30, 1e-4));
      expect(currentRecipe.filmHalation, closeTo(0.40, 1e-4));
      expect(currentRecipe.temperature, closeTo(-0.15, 1e-4));
    });

    testWidgets('shows error message on invalid QR string', (tester) async {
      await pumpSheet(tester);

      await tester.enterText(find.byKey(const Key('qr-text-input')), 'invalid-garbage');
      await tester.pump();
      await tester.tap(find.byKey(const Key('parse-qr-text-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not find a valid look'), findsOneWidget);
    });
  });
}
