import 'package:universal_io/io.dart';

import 'activity_log.dart';
import 'log_providers.dart';

/// Durable, append-only, on-device log file (one JSON object per line). All
/// operations are best-effort: a logging failure must never crash the app.
///
/// Once the file exceeds [maxBytes] after an append it is rewritten holding
/// only the newest [keepLines] lines (ADR 0012) — bounded storage on a phone,
/// with a single writer so lines never tear.
class LogFileStore {
  LogFileStore(this.file, {this.maxBytes = 2 << 20, this.keepLines = 1000});

  final File file;

  /// Size ceiling that triggers a rotation rewrite.
  final int maxBytes;

  /// Newest lines kept when rotating.
  final int keepLines;

  Future<void> append(LogEntry entry) async {
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '${entry.encode()}\n',
        mode: FileMode.append,
        flush: true,
      );
      await _rotateIfNeeded();
    } catch (e, st) {
      axLog(LogDomain.error, 'Log file write failed', level: LogLevel.warning, error: e.toString(), stack: st.toString());
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
    } catch (e, st) {
      axLog(LogDomain.error, 'Log file read failed', level: LogLevel.warning, error: e.toString(), stack: st.toString());
      return const [];
    }
  }

  Future<void> clear() async {
    try {
      if (await file.exists()) await file.delete();
    } catch (e, st) {
      axLog(LogDomain.error, 'Log file clear failed', level: LogLevel.warning, error: e.toString(), stack: st.toString());
    }
  }

  Future<void> _rotateIfNeeded() async {
    try {
      if (await file.length() <= maxBytes) return;
      final lines = await file.readAsLines();
      if (lines.length <= keepLines) return;
      final kept = lines.sublist(lines.length - keepLines);
      await file.writeAsString('${kept.join('\n')}\n', flush: true);
    } catch (e, st) {
      axLog(LogDomain.error, 'Log rotation failed', level: LogLevel.warning, error: e.toString(), stack: st.toString());
    }
  }
}
