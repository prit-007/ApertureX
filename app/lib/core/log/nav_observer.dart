import 'package:flutter/widgets.dart';

import 'activity_log.dart';
import 'log_providers.dart';

/// Logs navigation activity (ADR 0012 §5) — every push/pop/remove/replace of
/// the root navigator, so "what screen was open when X happened" is always
/// answerable from the log.
class NavObserver extends NavigatorObserver {
  NavObserver({this.log});

  /// Injectable for tests; defaults to the shared [activityLog].
  final ActivityLog? log;

  ActivityLog get _store => log ?? activityLog;

  String _label(Route<dynamic>? route) {
    if (route == null) return 'none';
    final name = route.settings.name;
    return name ?? route.runtimeType.toString();
  }

  void _record(String verb, Route<dynamic>? route) =>
      _store.add(LogDomain.nav, '$verb ${_label(route)}');

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _record('push', route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _record('pop', route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _record('remove', route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _record('replace', newRoute);
}

/// Shared instance wired into `MaterialApp.navigatorObservers`.
final NavObserver navObserver = NavObserver();
