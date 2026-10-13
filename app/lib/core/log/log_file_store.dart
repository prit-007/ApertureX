import 'dart:io';

import 'activity_log.dart';

/// Durable, append-only, on-device log file (one JSON object per line). All
/// operations are best-effort: a logging failure must never crash the app.
class LogFileStore {
  LogFileStore(this.file);

  final File file;

  Future<void> append(LogEntry entry) async {
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '${entry.encode()}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // best effort
    }
  }

  /// Reads the most recent [limit] entries (oldest first).
  Future<List<LogEntry>> read({int limit = 500}) async {
    try {
      if (!await file.exists()) return const [];
      final lines = await file.readAsLines();
      final start = lines.length > limit ? lines.length - limit : 0;
      return [
        for (final line in lines.sublist(start)) ?LogEntry.decode(line),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> clear() async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // best effort
    }
  }
}
