import 'package:flutter/services.dart';

/// The haptic a value change should fire (ADR 0011, "zero-gravity haptics").
enum HapticTick { none, neutralCross, limit }

/// Decides the haptic for a value move from [previous] to [next] over
/// `[min, max]`. Pure and unit-testable.
///
/// * reaching/leaving an end-stop → [HapticTick.limit] (heavy thud)
/// * passing through — or landing exactly on — neutral → [HapticTick.neutralCross]
HapticTick hapticFor(double previous, double next, double min, double max) {
  if (next != previous && (next <= min || next >= max)) {
    return HapticTick.limit;
  }
  if (next == 0.0 && previous != 0.0) {
    return HapticTick.neutralCross;
  }
  if (previous != 0.0 && next != 0.0 && previous.sign != next.sign) {
    return HapticTick.neutralCross;
  }
  return HapticTick.none;
}

/// Fires the platform haptic for a [HapticTick].
void fireHaptic(HapticTick tick) {
  switch (tick) {
    case HapticTick.neutralCross:
      HapticFeedback.mediumImpact();
    case HapticTick.limit:
      HapticFeedback.heavyImpact();
    case HapticTick.none:
      break;
  }
}
