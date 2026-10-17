import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/haptics.dart';
import '../edit/adjustment_layer.dart';
import '../edit/recipe_controller.dart';

/// Calculates min and max luminance thresholds (0..1) for Ansel Adams zones (0..10).
(double, double) zoneLumaBounds(int zone) {
  final z = zone.clamp(0, 10);
  if (z == 0) {
    return (0.0, 0.08);
  } else if (z == 10) {
    return (0.92, 1.0);
  } else {
    final c = z / 10.0;
    const width = 0.10;
    return (
      (c - width / 2).clamp(0.0, 1.0),
      (c + width / 2).clamp(0.0, 1.0),
    );
  }
}

/// Represents the active Ansel Adams Haptic Zone Masking state.
class ZoneMaskState {
  const ZoneMaskState({
    this.isTargeting = false,
    this.activeZone = 5,
    this.lockedLayerIndex,
  });

  /// True while two fingers are down and sliding in Mask Preview mode.
  final bool isTargeting;

  /// Active Ansel Adams tonal zone (0 = maximum black, 5 = 18% gray, 10 = pure white).
  final int activeZone;

  /// Index in [EditRecipe.layers] of the locked luminance mask layer, or null.
  final int? lockedLayerIndex;

  (double, double) get lumaBounds => zoneLumaBounds(activeZone);

  ZoneMaskState copyWith({
    bool? isTargeting,
    int? activeZone,
    Object? lockedLayerIndex = _sentinel,
  }) {
    return ZoneMaskState(
      isTargeting: isTargeting ?? this.isTargeting,
      activeZone: activeZone ?? this.activeZone,
      lockedLayerIndex: identical(lockedLayerIndex, _sentinel)
          ? this.lockedLayerIndex
          : lockedLayerIndex as int?,
    );
  }
}

const Object _sentinel = Object();

/// State machine controller for Ansel Adams Haptic Zone Masking.
class ZoneMaskController extends Notifier<ZoneMaskState> {
  double _accumulator = 0;
  static const double _zoneStepPx = 30.0;

  @override
  ZoneMaskState build() => const ZoneMaskState();

  /// Starts two-finger zone preview mode.
  void beginTargeting({int initialZone = 5}) {
    _accumulator = 0;
    state = state.copyWith(
      isTargeting: true,
      activeZone: initialZone.clamp(0, 10),
    );
  }

  /// Feeds vertical travel [dy] during two-finger hold/slide.
  /// Moving up (-dy) increases zone; moving down (+dy) decreases zone.
  /// Returns a [HapticTick] if a haptic feedback boundary was crossed, or null.
  HapticTick? updateDelta(double dy) {
    if (!state.isTargeting) return null;
    _accumulator += dy;
    final prevZone = state.activeZone;
    var nextZone = prevZone;

    while (_accumulator <= -_zoneStepPx) {
      _accumulator += _zoneStepPx;
      nextZone++;
    }
    while (_accumulator >= _zoneStepPx) {
      _accumulator -= _zoneStepPx;
      nextZone--;
    }

    nextZone = nextZone.clamp(0, 10);
    if (nextZone == prevZone) {
      if ((prevZone == 0 && dy > _zoneStepPx) || (prevZone == 10 && dy < -_zoneStepPx)) {
        return HapticTick.limit;
      }
      return null;
    }

    state = state.copyWith(activeZone: nextZone);

    if (nextZone == 0 || nextZone == 10) {
      return HapticTick.limit;
    } else if (nextZone == 5 || (prevZone < 5 && nextZone > 5) || (prevZone > 5 && nextZone < 5)) {
      return HapticTick.neutralCross;
    }
    return HapticTick.none;
  }

  void endTargeting() {
    state = state.copyWith(isTargeting: false);
  }

  /// Locks an AdjustmentLayer with luminance mask targeting [activeZone] into the recipe.
  void lockMask([dynamic context]) {
    final zone = state.activeZone;
    final controller = _getRecipeController(context);
    final layers = _getLayers(context);

    final layer = AdjustmentLayer(
      maskKind: MaskKind.luminance,
    ).withZone(zone);

    final int targetIndex;
    if (state.lockedLayerIndex != null &&
        state.lockedLayerIndex! < layers.length &&
        layers[state.lockedLayerIndex!].maskKind == MaskKind.luminance) {
      targetIndex = state.lockedLayerIndex!;
      controller.updateLayerAt(targetIndex, layer);
    } else {
      targetIndex = layers.length;
      controller.addLayer(layer);
    }

    state = state.copyWith(
      isTargeting: false,
      lockedLayerIndex: targetIndex,
    );
  }

  /// Unlocks the zone mask so subsequent edits apply globally.
  void unlockMask() {
    state = state.copyWith(lockedLayerIndex: null);
  }

  /// Removes the locked luminance mask layer from the recipe and resets lock state.
  void removeLockedMask([dynamic context]) {
    final idx = state.lockedLayerIndex;
    if (idx != null) {
      final layers = _getLayers(context);
      if (idx >= 0 && idx < layers.length && layers[idx].maskKind == MaskKind.luminance) {
        _getRecipeController(context).removeLayerAt(idx);
      }
    }
    state = state.copyWith(lockedLayerIndex: null);
  }

  RecipeController _getRecipeController(dynamic context) {
    if (context is ProviderContainer) {
      return context.read(recipeControllerProvider.notifier);
    } else if (context is WidgetRef) {
      return context.read(recipeControllerProvider.notifier);
    }
    return ref.read(recipeControllerProvider.notifier);
  }

  List<AdjustmentLayer> _getLayers(dynamic context) {
    if (context is ProviderContainer) {
      return context.read(recipeControllerProvider).recipe.layers;
    } else if (context is WidgetRef) {
      return context.read(recipeControllerProvider).recipe.layers;
    }
    return ref.read(recipeControllerProvider).recipe.layers;
  }
}

final zoneMaskProvider =
    NotifierProvider<ZoneMaskController, ZoneMaskState>(ZoneMaskController.new);
