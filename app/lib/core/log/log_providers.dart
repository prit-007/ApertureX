import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'activity_log.dart';

/// The single shared activity log.
///
/// Created once as a global (the top-level equivalent of nook's `talker`) so
/// any call site can record an activity without plumbing a `ref`, and the UI
/// can still watch it through [activityLogProvider].
final ActivityLog activityLog = ActivityLog();

/// Records an activity tagged with a [LogDomain] so it is colour-coded and
/// filterable in the in-app log viewer.
void axLog(String domain, String message, [LogLevel level = LogLevel.debug]) =>
    activityLog.add(domain, message, level);

/// Riverpod access to the shared [activityLog]. Watch it and rebuild with a
/// `ListenableBuilder` to render the live feed / count.
final activityLogProvider = Provider<ActivityLog>((ref) => activityLog);
