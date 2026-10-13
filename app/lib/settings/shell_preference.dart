import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which UI shell is active (ADR 0008). Lightroom is the default; neither shell
/// owns edit state — both render the same recipe through the same canvas.
enum AppShellKind { lightroom, snapseed }

class ShellPreference extends Notifier<AppShellKind> {
  @override
  AppShellKind build() => AppShellKind.lightroom;

  void select(AppShellKind kind) => state = kind;
}

final shellPreferenceProvider =
    NotifierProvider<ShellPreference, AppShellKind>(ShellPreference.new);
