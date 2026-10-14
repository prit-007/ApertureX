import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while the user is actively scrubbing an editing surface: a pointer is
/// down on the canvas, or a parameter slider is being dragged.
///
/// The editor fades its chrome (app bar, floating HUD, system bars) in
/// response — the "Active Mode" of issue #26, so the photo owns the screen
/// while the hand is on it.
///
/// Counts pointers rather than latching a flag (issue #43): with two fingers
/// down, lifting the first must not bring the chrome back while the second
/// is still panning/zooming.
class EditActivity extends Notifier<bool> {
  int _pointers = 0;

  @override
  bool build() {
    // A provider invalidate/rebuild must never wedge Active Mode on a stale
    // count from a missed pointer-up.
    _pointers = 0;
    return false;
  }

  void begin() {
    _pointers++;
    state = true;
  }

  void end() {
    if (_pointers == 0) return;
    _pointers--;
    if (_pointers == 0) state = false;
  }
}

final editActivityProvider = NotifierProvider<EditActivity, bool>(
  EditActivity.new,
);
