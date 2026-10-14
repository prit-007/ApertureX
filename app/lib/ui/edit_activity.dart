import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while the user is actively scrubbing an editing surface: a pointer is
/// down on the canvas, or a parameter slider is being dragged.
///
/// The editor fades its chrome (app bar, floating HUD, system bars) in
/// response — the "Active Mode" of issue #26, so the photo owns the screen
/// while the hand is on it.
class EditActivity extends Notifier<bool> {
  @override
  bool build() => false;

  void begin() {
    if (state) return;
    state = true;
  }

  void end() {
    if (!state) return;
    state = false;
  }
}

final editActivityProvider = NotifierProvider<EditActivity, bool>(
  EditActivity.new,
);
