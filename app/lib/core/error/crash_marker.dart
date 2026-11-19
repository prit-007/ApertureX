import 'dart:convert';
import 'dart:io';

import '../log/activity_log.dart';
import '../log/log_providers.dart';

/// Best-effort persistence of the last fatal error (`crash_marker.json`) so
/// the **next** launch can offer "see what happened last session" (ADR 0012).
/// One JSON object; a crash is not concurrent, so a single writer holds.
class CrashMarker {
  CrashMarker(this.file);

  final File file;

  Future<void> write({
    required String where,
    required String error,
    required String stack,
  }) async {
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          't': DateTime.now().toIso8601String(),
          'where': where,
          'error': error,
          'stack': stack,
        }),
        flush: true,
      );
    } catch (e, st) {
      axLog(LogDomain.crash, 'CrashMarker write error: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
      // best effort — never throw from the crash path
    }
  }

  /// The pending crash record, or null when absent/corrupt.
  Future<Map<String, Object?>?> peek() async {
    try {
      if (!await file.exists()) return null;
      final map = jsonDecode(await file.readAsString());
      if (map is! Map) return null;
      return map.cast<String, Object?>();
    } catch (e, st) {
      axLog(LogDomain.crash, 'CrashMarker peek decode error: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
      return null;
    }
  }

  Future<void> clear() async {
    try {
      if (await file.exists()) await file.delete();
    } catch (e, st) {
      axLog(LogDomain.crash, 'CrashMarker clear delete error: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
      // best effort
    }
  }
}
