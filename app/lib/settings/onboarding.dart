import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';

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
    } catch (e, st) {
      axLog(LogDomain.app, 'Onboarding hint restore fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (e, st) {
      axLog(LogDomain.app, 'Onboarding hint persist failed: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
    }
  }
}

/// Whether the gesture-shell onboarding hint has been seen.
final gestureHintSeenProvider = NotifierProvider<Onboarding, bool>(
  Onboarding.new,
);

/// Comprehensive app onboarding completion status, persisted across sessions.
class HasCompletedOnboarding extends Notifier<bool> {
  static const _key = 'has_completed_onboarding';
  bool _userSet = false;

  @override
  bool build() {
    _restore();
    return false;
  }

  /// Marks the onboarding tour as completed.
  void complete() {
    if (state) return;
    _userSet = true;
    state = true;
    _persist(true);
  }

  /// Resets onboarding status so the user can re-trigger the first-run tour.
  void reset() {
    _userSet = true;
    state = false;
    _persist(false);
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userSet) return;
      state = prefs.getBool(_key) ?? false;
    } catch (e, st) {
      axLog(LogDomain.app, 'Onboarding completion restore fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
    }
  }

  Future<void> _persist(bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, val);
    } catch (e, st) {
      axLog(LogDomain.app, 'Onboarding completion persist failed: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
    }
  }
}

/// Provider for overall app onboarding completion status.
final hasCompletedOnboardingProvider =
    NotifierProvider<HasCompletedOnboarding, bool>(
  HasCompletedOnboarding.new,
);
