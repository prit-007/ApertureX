import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'activity_log.dart';
import 'log_file_store.dart';
import 'native_log_bridge.dart';

/// The single shared activity log.
///
/// Created once as a global (the top-level equivalent of nook's `talker`) so
/// any call site can record an activity without plumbing a `ref`, and the UI
/// can still watch it through [activityLogProvider].
final ActivityLog activityLog = ActivityLog();

/// Records an activity tagged with a [LogDomain] so it is colour-coded and
/// filterable in the in-app log viewer. Failures pass [error]/[stack] (ADR
/// 0012 schema v2).
void axLog(
  String domain,
  String message, {
  LogLevel level = LogLevel.debug,
  String? error,
  String? stack,
  Map<String, Object?>? meta,
}) => activityLog.add(
  domain,
  message,
  level: level,
  error: error,
  stack: stack,
  meta: meta,
);

/// Riverpod access to the shared [activityLog]. Watch it and rebuild with a
/// `ListenableBuilder` to render the live feed / count.
final activityLogProvider = Provider<ActivityLog>((ref) => activityLog);

/// Loads every on-device stream into one chronological feed at startup:
/// local `activity.log`, Kotlin's `native.log` (over the channel) and Rust's
/// `rust_panic.log` — so **every layer's** errors are visible in the log page
/// (ADR 0012 §4). Each stream degrades independently; failures never block
/// startup. Pass [target] (tests) to hydrate a specific log instead of the
/// shared global.
Future<void> hydrateActivityLog(
  Directory dir, {
  ActivityLog? target,
  NativeLogBridge? bridge,
}) async {
  final log = target ?? activityLog;
  final local = await LogFileStore(File('${dir.path}/activity.log')).read();
  final rust = await LogFileStore(File('${dir.path}/rust_panic.log')).read();
  final native = await (bridge ?? NativeLogBridge()).readEntries();
  log.hydrate(mergeLogEntries(local, mergeLogEntries(rust, native)));
}
