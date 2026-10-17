import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';

/// Which UI shell is active (ADR 0008). Lightroom is the default; neither shell
/// owns edit state — both render the same recipe through the same canvas. The
/// choice is persisted on-device.
enum AppShellKind { lightroom, snapseed }

class ShellPreference extends Notifier<AppShellKind> {
  static const String _key = 'shell_kind';
  bool _userSet = false;

  @override
  AppShellKind build() {
    _restore();
    return AppShellKind.lightroom;
  }

  void select(AppShellKind kind) {
    _userSet = true;
    state = kind;
    _persist(kind);
    axLog(LogDomain.app, 'Shell preference set to ${kind.name}');
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userSet) return;
      final name = prefs.getString(_key);
      state = name == AppShellKind.snapseed.name
          ? AppShellKind.snapseed
          : AppShellKind.lightroom;
    } catch (_) {
      // No storage available (e.g. tests) — keep the default.
    }
  }

  Future<void> _persist(AppShellKind kind) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, kind.name);
    } catch (_) {
      // best effort
    }
  }
}

final shellPreferenceProvider =
    NotifierProvider<ShellPreference, AppShellKind>(ShellPreference.new);
