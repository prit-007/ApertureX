import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aperturex/core/haptics.dart';
import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/gesture/zone_mask.dart';

void main() {
  group('ZoneMaskController', () {
    late ProviderContainer container;
    late ZoneMaskController controller;

    setUp(() {
      container = ProviderContainer();
      controller = container.read(zoneMaskProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is idle at Zone 5 with no locked layer', () {
      final state = container.read(zoneMaskProvider);
      expect(state.isTargeting, isFalse);
      expect(state.activeZone, 5);
      expect(state.lockedLayerIndex, isNull);
    });

    test('beginTargeting activates targeting mode at specified initial zone', () {
      controller.beginTargeting(initialZone: 3);
      final state = container.read(zoneMaskProvider);
      expect(state.isTargeting, isTrue);
      expect(state.activeZone, 3);
    });

    test('sliding up increases zone, sliding down decreases zone', () {
      controller.beginTargeting(initialZone: 5);

      // Drag up by -90px (step is ~30px per zone) -> should step up ~3 zones to 8
      final tick1 = controller.updateDelta(-90);
      expect(container.read(zoneMaskProvider).activeZone, 8);
      expect(tick1, isNotNull);

      // Drag down by +150px -> should step down to Zone 3
      final tick2 = controller.updateDelta(150);
      expect(container.read(zoneMaskProvider).activeZone, 3);
      expect(tick2, isNotNull);
    });

    test('zone steps clamp strictly between 0 and 10', () {
      controller.beginTargeting(initialZone: 9);
      controller.updateDelta(-300); // extreme upward drag
      expect(container.read(zoneMaskProvider).activeZone, 10);

      controller.updateDelta(600); // extreme downward drag
      expect(container.read(zoneMaskProvider).activeZone, 0);
    });

    test('crossing Zone 5 fires neutralCross tick and limits fire limit ticks', () {
      controller.beginTargeting(initialZone: 4);

      // Step from 4 to 5: crosses middle gray (neutral)
      final tick5 = controller.updateDelta(-35);
      expect(container.read(zoneMaskProvider).activeZone, 5);
      expect(tick5, HapticTick.neutralCross);

      // Drag to limit 10
      controller.updateDelta(-250);
      expect(container.read(zoneMaskProvider).activeZone, 10);
      final tickLimit = controller.updateDelta(-50);
      expect(tickLimit, HapticTick.limit);
    });

    test('lockMask creates a luminance AdjustmentLayer in recipeController and locks it', () {
      controller.beginTargeting(initialZone: 7);
      controller.lockMask(container);

      final state = container.read(zoneMaskProvider);
      expect(state.isTargeting, isFalse);
      expect(state.lockedLayerIndex, isNotNull);

      final recipe = container.read(recipeControllerProvider).recipe;
      expect(recipe.layers.length, 1);
      final layer = recipe.layers[state.lockedLayerIndex!];
      expect(layer.maskKind, MaskKind.luminance);
      expect(layer.lumaZone, 7);
    });

    test('unlockMask leaves layer intact in recipe but unlocks targeting', () {
      controller.beginTargeting(initialZone: 7);
      controller.lockMask(container);
      expect(container.read(zoneMaskProvider).lockedLayerIndex, 0);

      controller.unlockMask();
      expect(container.read(zoneMaskProvider).lockedLayerIndex, isNull);
      // Layer still exists in recipe
      expect(container.read(recipeControllerProvider).recipe.layers.length, 1);
    });

    test('removeLockedMask deletes the locked layer from recipe', () {
      controller.beginTargeting(initialZone: 7);
      controller.lockMask(container);
      expect(container.read(recipeControllerProvider).recipe.layers.length, 1);

      controller.removeLockedMask(container);
      expect(container.read(zoneMaskProvider).lockedLayerIndex, isNull);
      expect(container.read(recipeControllerProvider).recipe.layers.length, 0);
    });

    test('zoneLumaBounds returns proper min/max luminance for shader', () {
      final (lo0, hi0) = zoneLumaBounds(0);
      expect(lo0, 0.0);
      expect(hi0, closeTo(0.08, 1e-3));

      final (lo5, hi5) = zoneLumaBounds(5);
      expect(lo5, closeTo(0.45, 1e-3));
      expect(hi5, closeTo(0.55, 1e-3));

      final (lo10, hi10) = zoneLumaBounds(10);
      expect(lo10, closeTo(0.92, 1e-3));
      expect(hi10, 1.0);
    });

    test('removeLockedMask does not crash or delete invalid layer', () {
      final container = ProviderContainer();
      final notifier = container.read(zoneMaskProvider.notifier);
      notifier.state = notifier.state.copyWith(lockedLayerIndex: 99);
      expect(() => notifier.removeLockedMask(container), returnsNormally);
      expect(notifier.state.lockedLayerIndex, isNull);
    });
  });
}
