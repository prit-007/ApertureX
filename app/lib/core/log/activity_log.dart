import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Severity of an [LogEntry].
enum LogLevel { debug, info, warning, error }

/// Domain "keys" for app activity logs. Each maps to its own colour in the
/// in-app log viewer so buckets (gallery / editor / export / permission) can be
/// filtered independently — the same shape as the nook project's logs.
abstract final class LogDomain {
  static const app = 'app';
  static const gallery = 'gallery';
  static const editor = 'editor';
  static const export = 'export';
  static const permission = 'permission';
  static const preset = 'preset';

  static const all = [app, gallery, editor, export, permission, preset];
}

/// A single, immutable local activity record.
@immutable
class LogEntry {
  const LogEntry({
    required this.time,
    required this.domain,
    required this.level,
    required this.message,
  });

  final DateTime time;
  final String domain;
  final LogLevel level;
  final String message;

  Map<String, Object?> toJson() => {
    't': time.toIso8601String(),
    'd': domain,
    'l': level.name,
    'm': message,
  };

  /// One JSON object per line — the on-disk format.
  String encode() => jsonEncode(toJson());

  static LogEntry? decode(String line) {
    if (line.trim().isEmpty) return null;
    try {
      final map = jsonDecode(line) as Map<String, Object?>;
      return LogEntry(
        time: DateTime.parse(map['t'] as String),
        domain: map['d'] as String,
        level: LogLevel.values.firstWhere(
          (l) => l.name == map['l'],
          orElse: () => LogLevel.debug,
        ),
        message: map['m'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

/// An in-memory, bounded, append-only activity log with an optional durable
/// sink. It is the single source of truth the in-app viewer renders, and it
/// works fully offline.
class ActivityLog extends ChangeNotifier {
  ActivityLog({this.capacity = 500});

  final int capacity;
  final List<LogEntry> _entries = [];
  void Function(LogEntry)? _sink;
  void Function()? _onClear;

  /// Newest last (chronological).
  List<LogEntry> get entries => List.unmodifiable(_entries);
  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;

  /// Registers a durable sink (e.g. a file append) for every future entry, and
  /// an optional [onClear] hook so clearing also truncates the durable sink.
  void attachSink(void Function(LogEntry) sink, {void Function()? onClear}) {
    _sink = sink;
    _onClear = onClear;
  }

  /// Seeds the buffer from persisted entries (oldest first).
  void hydrate(Iterable<LogEntry> entries) {
    _entries
      ..clear()
      ..addAll(entries);
    _trim();
    notifyListeners();
  }

  void add(
    String domain,
    String message, [
    LogLevel level = LogLevel.debug,
  ]) {
    final entry = LogEntry(
      time: DateTime.now(),
      domain: domain,
      level: level,
      message: message,
    );
    _entries.add(entry);
    _trim();
    _sink?.call(entry);
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    _onClear?.call();
    notifyListeners();
  }

  void _trim() {
    while (_entries.length > capacity) {
      _entries.removeAt(0);
    }
  }
}

/// Renders [entries] (oldest first) as a plain-text report for copy/export.
String activityLogReport(Iterable<LogEntry> entries) {
  final buffer = StringBuffer('ApertureX activity log\n');
  for (final e in entries) {
    buffer.writeln(
      '${e.time.toIso8601String()} [${e.domain}/${e.level.name}] ${e.message}',
    );
  }
  return buffer.toString();
}
