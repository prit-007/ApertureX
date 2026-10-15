import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'boundary_fallback.dart';
import 'error_reporter.dart';

/// The global boundary hooks of the pure error boundary (ADR 0012 §1), kept
/// as an object so tests can invoke each hook directly.
class BoundaryHooks {
  BoundaryHooks({required this.reporter, this.presentInDebug = true});

  final ErrorReporter reporter;

  /// Debug builds keep the framework's console exception dump.
  final bool presentInDebug;

  /// `FlutterError.onError` — build/layout/paint/gesture failures are
  /// non-fatal: the failing subtree renders as `ErrorWidget` (the W13.4
  /// fallback card), and the hit is logged + popped up.
  void onFlutterError(FlutterErrorDetails details) {
    reporter.report(
      details.exception,
      details.stack ?? StackTrace.empty,
      fatal: false,
    );
    if (presentInDebug && kDebugMode) {
      FlutterError.presentError(details);
    }
  }

  /// `PlatformDispatcher.instance.onError` — returning `true` tells the
  /// framework the error is handled: **the engine keeps running**.
  bool onDispatcherError(Object error, StackTrace stack) =>
      reporter.report(error, stack, fatal: true);

  /// Root-zone handler for [runGuarded] (uncaught async errors).
  void onZoneError(Object error, StackTrace stack) =>
      onDispatcherError(error, stack);
}

/// Installs the framework-facing hooks. The zone leg is installed separately
/// by [runGuarded] in `main` (it needs the handler during bootstrap).
BoundaryHooks installBoundaryHooks({
  required ErrorReporter reporter,
  bool presentInDebug = true,
}) {
  final hooks = BoundaryHooks(
    reporter: reporter,
    presentInDebug: presentInDebug,
  );
  FlutterError.onError = hooks.onFlutterError;
  PlatformDispatcher.instance.onError = hooks.onDispatcherError;
  // Subtree leg: a failed build paints the tappable card, never a dead end.
  ErrorWidget.builder = (details) => BoundaryFallback(details: details);
  return hooks;
}

/// Runs [body] in a guarded zone: every uncaught async error inside it goes
/// to [onError] instead of killing the app (ADR 0012 §1, zone row).
void runGuarded(
  void Function() body,
  void Function(Object, StackTrace) onError,
) => runZonedGuarded(body, onError);
