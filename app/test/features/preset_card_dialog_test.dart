import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:aperturex/edit/tool_definition.dart';
import 'package:aperturex/features/presets/preset_card_dialog.dart';

void main() {
  group('PresetCardDialog', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    const testTool = ToolDefinition(
      name: 'Portra Warmth',
      description: 'Analog film warmth',
      params: {
        'exposure': 0.25,
        'temperature': 0.15,
        'contrast': 0.10,
      },
    );

    Future<void> pumpDialog(
      WidgetTester tester, {
      ToolDefinition tool = testTool,
    }) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showPresetCardDialog(
                    context,
                    tool: tool,
                    author: '@photographer',
                  ),
                  child: const Text('Open Card'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open Card'));
      await tester.pumpAndSettle();
    }

    testWidgets('renders preset title, author, watermark, and QR code', (tester) async {
      await pumpDialog(tester);

      expect(find.text('Share Preset Card'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Portra Warmth'), findsWidgets);
      expect(find.text('@photographer'), findsWidgets);
      expect(find.textContaining('ApertureX'), findsWidgets);

      expect(find.byKey(const Key('share-card-button')), findsOneWidget);
      expect(find.byKey(const Key('save-card-button')), findsOneWidget);
      expect(find.byKey(const Key('copy-qr-uri-button')), findsOneWidget);
    });

    testWidgets('toggles aspect ratio between 1:1 and 9:16', (tester) async {
      await pumpDialog(tester);

      expect(find.byKey(const Key('ratio-1-1')), findsOneWidget);
      expect(find.byKey(const Key('ratio-9-16')), findsOneWidget);

      await tester.tap(find.byKey(const Key('ratio-9-16')));
      await tester.pumpAndSettle();

      // Card rebuilds with 9:16 aspect
      expect(find.byType(QrImageView), findsOneWidget);
    });
  });
}
