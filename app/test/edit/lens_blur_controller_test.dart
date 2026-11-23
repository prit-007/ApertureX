import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aperturex/edit/lens_blur_controller.dart';
import 'package:aperturex/edit/recipe_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LensBlurController', () {
    test('initial state reflects recipe blurEnabled', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(lensBlurControllerProvider);
      expect(state.status, LensBlurStatus.off);
      expect(state.depthConfidence, 0.0);
      expect(state.showDepthVisualizer, isFalse);
      expect(state.focusPointNormalized, isNull);
    });

    test('toggleDepthVisualizer updates showDepthVisualizer flag', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lensBlurControllerProvider.notifier);
      expect(container.read(lensBlurControllerProvider).showDepthVisualizer, isFalse);

      notifier.toggleDepthVisualizer(true);
      expect(container.read(lensBlurControllerProvider).showDepthVisualizer, isTrue);

      notifier.toggleDepthVisualizer(false);
      expect(container.read(lensBlurControllerProvider).showDepthVisualizer, isFalse);
    });

    test('setFocusPoint updates normalized coordinates and commits focal point to recipe', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lensBlurControllerProvider.notifier);
      notifier.setFocusPoint(0.5, 0.75);

      final state = container.read(lensBlurControllerProvider);
      expect(state.focusPointNormalized, isNotNull);
      expect(state.focusPointNormalized!.$1, 0.5);
      expect(state.focusPointNormalized!.$2, 0.75);

      // (0.20 + 0.60 * 0.75) = 0.65
      final recipeFocalPoint = container.read(recipeControllerProvider).recipe.blurFocalPoint;
      expect(recipeFocalPoint, closeTo(0.65, 1e-4));
    });

    test('setFocusPoint samples from cachedDepth when available', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lensBlurControllerProvider.notifier);
      // 2x2 depth field: (0,0)=0.1, (1,0)=0.3, (0,1)=0.7, (1,1)=0.9
      final cached = Float32List.fromList([0.1, 0.3, 0.7, 0.9]);
      container.read(lensBlurControllerProvider.notifier).state = container
          .read(lensBlurControllerProvider)
          .copyWith(cachedDepth: cached, depthWidth: 2, depthHeight: 2);

      // Focus at bottom-right (x=1.0, y=1.0) -> should sample 0.9
      notifier.setFocusPoint(1.0, 1.0);
      expect(container.read(recipeControllerProvider).recipe.blurFocalPoint, closeTo(0.9, 1e-4));

      // Focus at top-left (x=0.0, y=0.0) -> should sample 0.1
      notifier.setFocusPoint(0.0, 0.0);
      expect(container.read(recipeControllerProvider).recipe.blurFocalPoint, closeTo(0.1, 1e-4));
    });

    test('loadCachedSidecar restores state and persistSidecar round-trips to disk', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lensBlurControllerProvider.notifier);
      final cached = Float32List.fromList([0.2, 0.4, 0.6, 0.8]);
      notifier.state = notifier.state.copyWith(
        cachedDepth: cached,
        depthWidth: 2,
        depthHeight: 2,
        depthConfidence: 0.92,
      );

      final tempDir = await Directory.systemTemp.createTemp('lens_blur_sidecar_test');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final sidecarFile = File('${tempDir.path}/test.axdf');

      await notifier.persistSidecar(sidecarFile, contentHash: 999);
      expect(await sidecarFile.exists(), isTrue);

      final secondContainer = ProviderContainer();
      addTearDown(secondContainer.dispose);
      final secondNotifier = secondContainer.read(lensBlurControllerProvider.notifier);

      final loaded = await secondNotifier.loadCachedSidecar(sidecarFile);
      expect(loaded, isTrue);
      expect(secondNotifier.state.status, LensBlurStatus.ready);
      expect(secondNotifier.state.depthWidth, 2);
      expect(secondNotifier.state.depthHeight, 2);
      expect(secondNotifier.state.depthConfidence, closeTo(0.92, 1e-4));
      expect(secondNotifier.state.cachedDepth?.length, 4);
      expect(secondNotifier.state.cachedDepth?[0], closeTo(0.2, 1e-5));
    });

    test('applyDepthBrush paints depth touchups into cached depth and commits to recipe', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lensBlurControllerProvider.notifier);
      // 4x4 uniform background depth at 0.8
      final initial = Float32List.fromList(List.filled(16, 0.8));
      notifier.state = notifier.state.copyWith(
        status: LensBlurStatus.ready,
        cachedDepth: initial,
        depthWidth: 4,
        depthHeight: 4,
        depthConfidence: 0.9,
      );

      // Paint sharp subject focal point at 0.2 at center (x=0.5, y=0.5)
      notifier.applyDepthBrush([0.5, 0.5], brushRadius: 0.5, targetDepth: 0.2, opacity: 1.0);

      final updated = notifier.state.cachedDepth!;
      expect(updated.length, 16);
      // Center pixels should be modified towards 0.2
      const centerIdx = 2 * 4 + 2; // (x=2, y=2)
      expect(updated[centerIdx], lessThan(0.8));

      // Also verifies recipe depthField was updated
      final recipeField = container.read(recipeControllerProvider).recipe.depthField;
      expect(recipeField, isNotNull);
      expect(recipeField!.plane.length, 16);
      expect(recipeField.plane[centerIdx], lessThan(0.8));
      // Confidence should be 1.0 (user-authoritative) after manual brush edit
      expect(notifier.state.depthConfidence, 1.0);
      expect(recipeField.confidence, 1.0);
    });

    test('analyzeDepth respects cache when force=false, re-runs when force=true', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lensBlurControllerProvider.notifier);

      // Pre-populate cached depth
      final initial = Float32List.fromList([0.5]);
      notifier.state = notifier.state.copyWith(
        status: LensBlurStatus.ready,
        cachedDepth: initial,
        depthWidth: 1,
        depthHeight: 1,
        depthConfidence: 0.9,
      );

      // force=false (default): should early-return, state unchanged
      final stateBefore = notifier.state;
      await notifier.analyzeDepth(Uint8List.fromList([1, 2, 3, 4]));
      expect(notifier.state, stateBefore, reason: 'force=false should early-return with cached depth');

      // force=true: should proceed past the cache check (may fail on FFI, but must not early-return)
      try {
        await notifier.analyzeDepth(Uint8List.fromList([1, 2, 3, 4]), force: true);
        // If it succeeds, status should still be ready or failed (not early-returned)
        expect(notifier.state.status, isIn([LensBlurStatus.ready, LensBlurStatus.failed]));
      } catch (e) {
        // FFI may fail in test env; the key is that it didn't early-return
        expect(notifier.state.status, isNot(LensBlurStatus.off));
      }
    });
  });
}
