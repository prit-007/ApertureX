import 'dart:async';
import 'dart:typed_data';

import 'package:aperturex/edit/active_image.dart';
import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/settings/ai_consent.dart';
import 'package:aperturex/ui/common/mask_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Mask Segmentation & Conversion (#83, #89)', () {
    test('Conversion: segmenter f32 output (320x320) -> <=256^2 u8 blob layer and roundtrip', () {
      final f32Mask = List<double>.generate(320 * 320, (i) => (i % 320) / 320.0);
      final layer = AdjustmentLayer.bitmap(
        width: 320,
        height: 320,
        alphas: f32Mask,
        exposure: 0.5,
      );

      // Capped at 256
      expect(layer.bitmapWidth, 256);
      expect(layer.bitmapHeight, 256);
      expect(layer.maskBlob, isNotNull);
      expect(layer.maskBlob!.length, 256 * 256);

      // Bridge params conversion
      final bridgeParams = layer.toBridgeMaskParams();
      expect(bridgeParams[0], 256.0);
      expect(bridgeParams[1], 256.0);
      expect(bridgeParams.length, 2 + 256 * 256);

      // JSON roundtrip
      final json = layer.toJson();
      final roundtripped = AdjustmentLayer.fromJson(json);
      expect(roundtripped.maskKind, MaskKind.bitmap);
      expect(roundtripped.bitmapWidth, 256);
      expect(roundtripped.bitmapHeight, 256);
      expect(roundtripped.exposure, 0.5);
      expect(roundtripped.maskBlob, equals(layer.maskBlob));
    });

    testWidgets('Subject + with fake Segmenter creates a bitmap layer', (tester) async {
      final fakeAlphas = Float32List.fromList(List.filled(256 * 256, 0.8));
      final container = ProviderContainer(
        overrides: [
          subjectSegmenterProvider.overrideWithValue(
            (bytes, {int targetWidth = 256, int targetHeight = 256}) async => fakeAlphas,
          ),
          aiConsentProvider.overrideWith(
            _PreconsentedNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeImageBytesProvider.notifier).setBytes(Uint8List.fromList([1, 2, 3, 4]));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 500,
                height: 1000,
                child: MaskControls(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Subject +'));
      await tester.pumpAndSettle();

      final layers = container.read(recipeControllerProvider).recipe.layers;
      expect(layers, hasLength(1));
      expect(layers.first.maskKind, MaskKind.bitmap);
      expect(layers.first.bitmapWidth, 256);
      expect(layers.first.bitmapHeight, 256);
      expect(layers.first.exposure, 0.5);
      expect(layers.first.inverted, isFalse);
    });

    testWidgets('Background + with fake Segmenter creates the same layer with inverted: true', (tester) async {
      final fakeAlphas = Float32List.fromList(List.filled(256 * 256, 0.75));
      final container = ProviderContainer(
        overrides: [
          subjectSegmenterProvider.overrideWithValue(
            (bytes, {int targetWidth = 256, int targetHeight = 256}) async => fakeAlphas,
          ),
          aiConsentProvider.overrideWith(
            _PreconsentedNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeImageBytesProvider.notifier).setBytes(Uint8List.fromList([1, 2, 3, 4]));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 500,
                height: 1000,
                child: MaskControls(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mask-add-background')));
      await tester.pumpAndSettle();

      final layers = container.read(recipeControllerProvider).recipe.layers;
      expect(layers, hasLength(1));
      expect(layers.first.maskKind, MaskKind.bitmap);
      expect(layers.first.bitmapWidth, 256);
      expect(layers.first.bitmapHeight, 256);
      expect(layers.first.exposure, -0.4);
      expect(layers.first.inverted, isTrue);
    });

    testWidgets('Consent declined build: Subject + falls back to parametric ellipse', (tester) async {
      final container = ProviderContainer(
        overrides: [
          aiConsentProvider.overrideWith(
            _DeclinedConsentNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeImageBytesProvider.notifier).setBytes(Uint8List.fromList([1, 2, 3, 4]));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 500,
                height: 1000,
                child: MaskControls(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Subject +'));
      await tester.pumpAndSettle();

      final layers = container.read(recipeControllerProvider).recipe.layers;
      expect(layers, hasLength(1));
      expect(layers.first.maskKind, MaskKind.subject);
      expect(layers.first.maskParams, equals([0.5, 0.5, 0.28, 0.38, 0.25]));
    });

    testWidgets('Inference failure: falls back to parametric subject and shows SnackBar', (tester) async {
      final container = ProviderContainer(
        overrides: [
          subjectSegmenterProvider.overrideWithValue(
            (bytes, {int targetWidth = 256, int targetHeight = 256}) async =>
                throw Exception('Inference runtime error'),
          ),
          aiConsentProvider.overrideWith(
            _PreconsentedNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeImageBytesProvider.notifier).setBytes(Uint8List.fromList([1, 2, 3, 4]));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 500,
                height: 1000,
                child: MaskControls(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Subject +'));
      await tester.pumpAndSettle();

      expect(find.text('AI segmentation failed; using fallback subject mask'), findsOneWidget);

      final layers = container.read(recipeControllerProvider).recipe.layers;
      expect(layers, hasLength(1));
      expect(layers.first.maskKind, MaskKind.subject);
    });

    testWidgets('In-flight inference displays animated progress banner and disables buttons', (tester) async {
      final completer = Completer<Float32List?>();
      final container = ProviderContainer(
        overrides: [
          subjectSegmenterProvider.overrideWithValue(
            (bytes, {int targetWidth = 256, int targetHeight = 256}) => completer.future,
          ),
          aiConsentProvider.overrideWith(
            _PreconsentedNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeImageBytesProvider.notifier).setBytes(Uint8List.fromList([1, 2, 3, 4]));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 500,
                height: 1000,
                child: MaskControls(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger Subject +
      await tester.tap(find.text('Subject +'));
      await tester.pump(); // Start async call
      await tester.pump(const Duration(milliseconds: 300)); // AnimatedSize expansion

      // Banner should be visible with waiting message
      expect(find.byKey(const Key('ai-mask-progress-banner')), findsOneWidget);
      expect(find.textContaining('Please wait a moment'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Complete the inference
      completer.complete(Float32List.fromList(List.filled(256 * 256, 0.9)));
      await tester.pumpAndSettle();

      // Banner should disappear
      expect(find.byKey(const Key('ai-mask-progress-banner')), findsNothing);
      expect(container.read(recipeControllerProvider).recipe.layers, hasLength(1));
    });
  });
}

class _PreconsentedNotifier extends AiConsentNotifier {
  @override
  AiConsentStatus build() => AiConsentStatus.granted;
}

class _DeclinedConsentNotifier extends AiConsentNotifier {
  @override
  AiConsentStatus build() => AiConsentStatus.declined;
}
