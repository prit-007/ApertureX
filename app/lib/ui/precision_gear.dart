import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../edit/parameter.dart';

/// Drag sensitivity divisor while the precision gear is engaged (issue #71):
/// a finger held anywhere on screen turns every slider into a 0.1x fine-coarse
/// so `+15` lands exactly instead of bouncing between `+14` and `+16`.
const double kPrecisionDivisor = 10.0;

/// Whether [pointersDown] engages the gear. Two or more fingers = the left
/// hand is holding the screen while the right hand scrubs.
bool precisionEngaged(int pointersDown) => pointersDown >= 2;

/// Live count of pointers currently down anywhere under the app.
///
/// Counts globally rather than per-widget (issue #71): the precision gesture
/// is "tap and hold *anywhere* with the other hand", so a finger resting on
/// the canvas, the panel background, or even another slider must all read as
/// the same gear state.
class PrecisionGear extends Notifier<int> {
  @override
  int build() => 0;

  void begin() => state = state + 1;

  /// A stray up (missed down) must never drive the count negative — a
  /// negative count would wedge the gear on forever.
  void end() {
    if (state > 0) state = state - 1;
  }
}

final precisionGearProvider = NotifierProvider<PrecisionGear, int>(
  PrecisionGear.new,
);

/// The single parameter track allowed to scrub right now (issue #71).
///
/// The multi-touch state machine breaks if two tracks accept drags at once
/// (second finger lands on a neighbouring slider mid-scrub → two values jump).
/// The lease makes drag starts mutually exclusive: first track to start wins,
/// everyone else is rejected until the winner ends or cancels.
class ActiveTrack extends Notifier<Parameter?> {
  @override
  Parameter? build() => null;

  /// Attempts to take the lease for [parameter]; `false` when another track
  /// holds it (re-entrant claims by the current holder succeed).
  bool claim(Parameter parameter) {
    if (state != null && state != parameter) return false;
    state = parameter;
    return true;
  }

  /// Returns the lease; a no-op when [parameter] is not the holder, so a
  /// rejected gesture can never release someone else's scrub.
  void release(Parameter parameter) {
    if (state == parameter) state = null;
  }
}

final activeTrackProvider = NotifierProvider<ActiveTrack, Parameter?>(
  ActiveTrack.new,
);

/// Counts every pointer down/up across the whole app so [precisionGearProvider]
/// reflects "fingers on screen" regardless of what they touch.
///
/// Sits above `MaterialApp` (see `main.dart`) with translucent hit-testing so
/// modal routes, dialogs, and empty scaffold gaps still report their pointers.
class PrecisionListener extends ConsumerWidget {
  const PrecisionListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gear = ref.read(precisionGearProvider.notifier);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => gear.begin(),
      onPointerUp: (_) => gear.end(),
      onPointerCancel: (_) => gear.end(),
      child: child,
    );
  }
}
