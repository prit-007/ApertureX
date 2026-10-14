import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-time onboarding flags, persisted on-device. `true` = already seen.
class Onboarding extends Notifier<bool> {
  static const _key = 'gesture_hint_seen';
  bool _userSet = false;

  @override
  bool build() {
    _restore();
    return false;
  }

  void markGestureHintSeen() {
    if (state) return;
    _userSet = true;
    state = true;
    _persist();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userSet) return;
      state = prefs.getBool(_key) ?? false;
    } catch (_) {
      // No storage (tests) — keep the default (hint unseen).
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
      // best effort
    }
  }
}

/// Whether the gesture-shell onboarding hint has been seen.
final gestureHintSeenProvider = NotifierProvider<Onboarding, bool>(
  Onboarding.new,
);
