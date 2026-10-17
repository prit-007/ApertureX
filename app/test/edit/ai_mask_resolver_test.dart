import 'dart:typed_data';

import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:aperturex/edit/ai_mask_resolver.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI Intent Mask Serialization (#96)', () {
    test('JSON roundtrip: aiIntent and originAssetId preserved when present', () {
      final layer = AdjustmentLayer.bitmap(
        width: 4,
        height: 4,
        alphas: List.filled(16, 0.5),
        exposure: 0.5,
      ).copyWith(
        aiIntent: 'subject',
        originAssetId: 'asset_alpha',
      );

      final json = layer.toJson();
      expect(json['aiIntent'], 'subject');
      expect(json['originAssetId'], 'asset_alpha');

      final restored = AdjustmentLayer.fromJson(json);
      expect(restored.aiIntent, 'subject');
      expect(restored.originAssetId, 'asset_alpha');
      expect(restored, equals(layer));
    });

    test('JSON roundtrip: legacy JSON without aiIntent deserializes with nulls', () {
      final legacyJson = <String, Object?>{
        'maskKind': MaskKind.radial.index,
        'maskParams': [0.5, 0.5, 0.2, 0.2, 0.1],
        'exposure': 0.3,
      };

      final layer = AdjustmentLayer.fromJson(legacyJson);
      expect(layer.aiIntent, isNull);
      expect(layer.originAssetId, isNull);
    });
  });

  group('AiMaskResolver smart paste and cache (#96)', () {
    test('Paste matrix: asset A (origin) makes 0 calls, B and C make 1 call each, second B is cache hit', () async {
      var callCount = 0;
      Future<Float32List?> fakeSegmenter(
        Uint8List bytes, {
        int targetWidth = 256,
        int targetHeight = 256,
      }) async {
        callCount++;
        return Float32List.fromList(List.filled(targetWidth * targetHeight, 0.7));
      }

      final resolver = AiMaskResolver();
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

      final sourceLayer = AdjustmentLayer.bitmap(
        width: 256,
        height: 256,
        alphas: List.filled(256 * 256, 0.5),
        exposure: 0.5,
      ).copyWith(
        aiIntent: 'subject',
        originAssetId: 'A',
      );

      // 1. Resolve on asset A (origin): 0 inference calls
      final resA = await resolver.resolveLayer(
        sourceLayer,
        targetAssetId: 'A',
        targetProxyBytes: dummyBytes,
        segmenter: fakeSegmenter,
      );
      expect(callCount, 0);
      expect(resA.originAssetId, 'A');

      // 2. Resolve on asset B (new target): 1 inference call
      final resB = await resolver.resolveLayer(
        sourceLayer,
        targetAssetId: 'B',
        targetProxyBytes: dummyBytes,
        segmenter: fakeSegmenter,
      );
      expect(callCount, 1);
      expect(resB.originAssetId, 'B');
      expect(resB.maskBlob, isNotNull);

      // 3. Resolve on asset C (new target): 1 inference call (total 2)
      final resC = await resolver.resolveLayer(
        sourceLayer,
        targetAssetId: 'C',
        targetProxyBytes: dummyBytes,
        segmenter: fakeSegmenter,
      );
      expect(callCount, 2);
      expect(resC.originAssetId, 'C');

      // 4. Second resolve on asset B: cache hit, 0 additional calls (total remains 2)
      final resB2 = await resolver.resolveLayer(
        sourceLayer,
        targetAssetId: 'B',
        targetProxyBytes: dummyBytes,
        segmenter: fakeSegmenter,
      );
      expect(callCount, 2);
      expect(resB2.originAssetId, 'B');
      expect(resB2.maskBlob, equals(resB.maskBlob));
    });

    test('Stale cache: same photo re-imported under new asset ID re-resolves (id-keyed)', () async {
      var callCount = 0;
      Future<Float32List?> fakeSegmenter(
        Uint8List bytes, {
        int targetWidth = 256,
        int targetHeight = 256,
      }) async {
        callCount++;
        return Float32List.fromList(List.filled(targetWidth * targetHeight, 0.8));
      }

      final resolver = AiMaskResolver();
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

      final sourceLayer = AdjustmentLayer.bitmap(
        width: 256,
        height: 256,
        alphas: List.filled(256 * 256, 0.5),
      ).copyWith(aiIntent: 'subject', originAssetId: 'origin');

      await resolver.resolveLayer(
        sourceLayer,
        targetAssetId: 'asset_1',
        targetProxyBytes: dummyBytes,
        segmenter: fakeSegmenter,
      );
      expect(callCount, 1);

      // Re-imported as asset_1_reimported -> triggers re-resolve
      await resolver.resolveLayer(
        sourceLayer,
        targetAssetId: 'asset_1_reimported',
        targetProxyBytes: dummyBytes,
        segmenter: fakeSegmenter,
      );
      expect(callCount, 2);
    });

    test('modelVersion bump invalidates cache and triggers full re-resolve', () async {
      var callCount = 0;
      Future<Float32List?> fakeSegmenter(
        Uint8List bytes, {
        int targetWidth = 256,
        int targetHeight = 256,
      }) async {
        callCount++;
        return Float32List.fromList(List.filled(targetWidth * targetHeight, 0.9));
      }

      final resolver = AiMaskResolver();
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

      final sourceLayer = AdjustmentLayer.bitmap(
        width: 256,
        height: 256,
        alphas: List.filled(256 * 256, 0.5),
      ).copyWith(aiIntent: 'subject', originAssetId: 'origin');

      await resolver.resolveLayer(
        sourceLayer,
        targetAssetId: 'asset_X',
        targetProxyBytes: dummyBytes,
        segmenter: fakeSegmenter,
        modelVersion: 1,
      );
      expect(callCount, 1);

      // Bumping modelVersion to 2
      await resolver.resolveLayer(
        sourceLayer,
        targetAssetId: 'asset_X',
        targetProxyBytes: dummyBytes,
        segmenter: fakeSegmenter,
        modelVersion: 2,
      );
      expect(callCount, 2);
    });

    test('Fallback: segmenter error falls back safely without throwing', () async {
      final resolver = AiMaskResolver();
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

      final sourceLayer = AdjustmentLayer.bitmap(
        width: 256,
        height: 256,
        alphas: List.filled(256 * 256, 0.5),
      ).copyWith(aiIntent: 'subject', originAssetId: 'origin');

      final resolved = await resolver.resolveLayer(
        sourceLayer,
        targetAssetId: 'asset_fail',
        targetProxyBytes: dummyBytes,
        segmenter: (bytes, {int targetWidth = 256, int targetHeight = 256}) async =>
            throw Exception('Inference failure'),
      );

      // Layer stays intact, does not crash
      expect(resolved.maskKind, isNotNull);
      expect(resolved.originAssetId, 'origin');
    });

    test('Shared-recipe lifetime: resolution does not mutate the shared EditRecipe', () async {
      final resolver = AiMaskResolver();
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

      final layer = AdjustmentLayer.bitmap(
        width: 256,
        height: 256,
        alphas: List.filled(256 * 256, 0.5),
        exposure: 0.6,
      ).copyWith(aiIntent: 'subject', originAssetId: 'A');

      final sharedRecipe = EditRecipe.neutral.copyWith(layers: [layer]);

      final resolvedRecipe = await resolver.resolveRecipe(
        sharedRecipe,
        targetAssetId: 'B',
        targetProxyBytes: dummyBytes,
        segmenter: (bytes, {int targetWidth = 256, int targetHeight = 256}) async =>
            Float32List.fromList(List.filled(256 * 256, 0.8)),
      );

      // Shared recipe unchanged
      expect(sharedRecipe.layers.first.originAssetId, 'A');
      // Resolved recipe points to target B
      expect(resolvedRecipe.layers.first.originAssetId, 'B');
    });
  });
}
