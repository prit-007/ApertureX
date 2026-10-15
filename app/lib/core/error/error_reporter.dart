import 'dart:async';

import '../log/activity_log.dart';
import '../log/log_providers.dart';
import 'crash_marker.dart';

/// The classification handed to the dialog presenter (W13.4 wires the popup).
class ReportedError {
  const ReportedError({
    required this.error,
    required this.stack,
    required this.fatal,
  });

  final Object error;
  final StackTrace stack;
  final bool fatal;
}

/// Single funnel for every boundary hit (ADR 0012): classifies, throttles,
/// logs with `error`/`stack`, records fatal markers, and drives the popup.
///
/// Never throws — a failing reporter must not become a second crash.
class ErrorReporter {
  ErrorReporter({
    this.presenter,
    ActivityLog? log,
    DateTime Function()? now,
    this.marker,
    this.maxStackChars = 8000,
    this.throttleWindow = const Duration(seconds: 10),
  }) : _log = log ?? activityLog,
       _now = now ?? DateTime.now;

  final ActivityLog _log;
  final DateTime Function() _now;

  /// Called when a dialog should be shown (first hit / window expired).
  final void Function(ReportedError)? presenter;

  /// Fatal-error marker written for the next-launch report (ADR 0012 §3).
  /// Attached in `main` once the app-support directory is known.
  CrashMarker? marker;

  /// Stack traces are truncated to this many characters in the log.
  final int maxStackChars;

  /// Same signature (type + top frame) inside this window logs but shows no
  /// second dialog — no dialog storms in a failure loop.
  final Duration throttleWindow;

  /// The most recent hit. `ErrorWidget.builder`'s callback carries no error,
  /// but the framework calls `FlutterError.onError` first — the fallback card
  /// shows this when tapped.
  ReportedError? lastError;

  final Map<String, DateTime> _seen = {};

  /// Records the error; returns true when a dialog should be presented
  /// (first hit or window expired).
  bool report(Object error, StackTrace stack, {bool fatal = false}) {
    final now = _now();
    final err = error.toString();
    var trace = stack.toString();
    if (trace.length > maxStackChars) trace = trace.substring(0, maxStackChars);

    final signature = '${error.runtimeType}|${_topFrame(stack)}';
    final last = _seen[signature];
    final throttled = last != null && now.difference(last) < throttleWindow;
    _seen[signature] = now;

    lastError = ReportedError(error: error, stack: stack, fatal: fatal);

    _log.add(
      fatal ? LogDomain.crash : LogDomain.error,
      '${fatal ? 'Fatal' : 'Unhandled'} ${error.runtimeType}',
      level: LogLevel.error,
      error: err,
      stack: trace,
      meta: throttled ? {'throttled': true} : null,
    );

    if (fatal) {
      unawaited(
        marker?.write(where: 'dart', error: err, stack: trace),
      );
    }

    if (throttled) return false;
    presenter?.call(lastError!);
    return true;
  }

  static String _topFrame(StackTrace stack) {
    final lines = stack.toString().split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#')) return trimmed;
    }
    return lines.isEmpty ? '' : lines.first.trim();
  }
}
