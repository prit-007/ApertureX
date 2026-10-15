import 'package:flutter/widgets.dart';

import 'activity_log.dart';
import 'log_providers.dart';

/// Logs app lifecycle transitions (ADR 0012 §5): resume/pause/hidden/detach
/// go to the `app` domain so "the app was backgrounded here" is in the feed.
class LifecycleObserver with WidgetsBindingObserver {
  LifecycleObserver({this.log});

  /// Injectable for tests; defaults to the shared [activityLog].
  final ActivityLog? log;

  bool _attached = false;

  /// Whether the observer is currently registered with the binding.
  bool get isAttached => _attached;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    (log ?? activityLog).add(LogDomain.app, 'lifecycle ${state.name}');
  }

  /// Registers with the binding once (idempotent).
  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    WidgetsBinding.instance.removeObserver(this);
  }
}

/// Shared instance attached in `main()` — held at top level so the binding
/// never observes a garbage-collected listener.
final LifecycleObserver lifecycleObserver = LifecycleObserver();
