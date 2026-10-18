import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/look_qr_codec.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/edit/tool_definition.dart';
import 'package:aperturex/features/presets/qr_scanner_sheet.dart';
import 'package:aperturex/ui/common/app_sheet.dart';

import '../helpers/viewport_harness.dart';

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

    testWidgets(
      'oversized name/author preview fits phone viewports and stays applyable',
      (tester) async {
        const hugeTool = ToolDefinition(
          name: 'Ultra Long Cinematic Film Emulation Preset Name v2 Ultimate',
          params: {'exposure': 0.30},
        );
        const author = '@an-extremely-long-photographer-handle-name';

        // At small scales the sheet content exceeds the viewport, so controls
        // below the fold aren't even built. Drag from the sheet's center (the
        // hit test lands on the ListView content whatever the scroll offset)
        // until the target is on screen.
        Future<void> dragSheetUntil(Finder target) async {
          final anchor = tester.getCenter(find.byType(AppSheet));
          var guard = 0;
          while (target.hitTestable().evaluate().isEmpty && guard < 8) {
            await tester.dragFrom(anchor, const Offset(0, -250));
            await tester.pumpAndSettle();
            guard++;
          }
        }

        for (final viewport in const [Size(360, 800), Size(320, 640)]) {
          for (final textScale in const [1.0, 1.3]) {
            setViewport(tester, viewport, textScale);
            await pumpSheet(tester);

            final input = find.byKey(const Key('qr-text-input'));
            final parseBtn = find.byKey(const Key('parse-qr-text-button'));
            await dragSheetUntil(parseBtn);
            expect(
              parseBtn.hitTestable(),
              findsOneWidget,
              reason: 'parse button unreachable at $viewport / textScale $textScale',
            );

            final uri = LookQrCodec.encodeToUri(hugeTool, author: author);
            await tester.enterText(input, uri);
            await tester.pump();
            await tester.tap(parseBtn);
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason: 'overflow at $viewport / textScale $textScale',
            );
            expect(
              find.text(
                'Ultra Long Cinematic Film Emulation Preset Name v2 Ultimate',
              ),
              findsOneWidget,
            );
            expect(find.text('by $author'), findsOneWidget);

            final apply = find.byKey(const Key('apply-decoded-look-button'));
            expect(apply, findsOneWidget);
            await dragSheetUntil(apply);
            await tester.ensureVisible(apply);
            await tester.pumpAndSettle();
            expect(apply.hitTestable(), findsOneWidget);
            await tester.tap(apply);
            await tester.pumpAndSettle();

            expect(
              container.read(recipeControllerProvider).recipe.exposure,
              closeTo(0.30, 1e-4),
              reason: 'apply tap failed at $viewport / textScale $textScale',
            );
          }
        }
      },
    );
  });
}
