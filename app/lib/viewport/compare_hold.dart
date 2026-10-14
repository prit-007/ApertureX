import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while the "before/after" compare should be shown — either the user is
/// long-pressing the photo or holding the panel's Compare button (issue #28).
///
/// The canvas owns the animation; this flag is the shared, dismissable source
/// of truth so any surface can start/stop the compare.
class CompareHold extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state == value) return;
    state = value;
  }

  void hold() => set(true);

  void release() => set(false);
}

final compareHoldProvider = NotifierProvider<CompareHold, bool>(
  CompareHold.new,
);
