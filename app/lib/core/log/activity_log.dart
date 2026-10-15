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

  // Resilience domains (ADR 0012): boundaries, crashes, navigation,
  // platform-native and engine events.
  static const error = 'error';
  static const crash = 'crash';
  static const nav = 'nav';
  static const native = 'native';
  static const engine = 'engine';

  static const all = [
    app,
    gallery,
    editor,
    export,
    permission,
    preset,
    error,
    crash,
    nav,
    native,
    engine,
  ];
}

/// A single, immutable local activity record.
@immutable
class LogEntry {
  const LogEntry({
    required this.time,
    required this.domain,
    required this.level,
    required this.message,
    this.error,
    this.stack,
    this.meta,
  });

  final DateTime time;
  final String domain;
  final LogLevel level;
  final String message;

  /// Short error description (`Object.toString()`), when the entry records a
  /// failure (ADR 0012).
  final String? error;

  /// Stack trace text, truncated by the reporter before it reaches the log.
  final String? stack;

  /// Small structured extras (counts, keys) — values must be JSON-safe.
  final Map<String, Object?>? meta;

  Map<String, Object?> toJson() => {
    't': time.toIso8601String(),
    'd': domain,
    'l': level.name,
    'm': message,
    if (error != null) 'e': error,
    if (stack != null) 's': stack,
    if (meta != null) 'x': meta,
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
        error: map['e'] as String?,
        stack: map['s'] as String?,
        meta: (map['x'] as Map?)?.cast<String, Object?>(),
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
    String message, {
    LogLevel level = LogLevel.debug,
    String? error,
    String? stack,
    Map<String, Object?>? meta,
  }) {
    final entry = LogEntry(
      time: DateTime.now(),
      domain: domain,
      level: level,
      message: message,
      error: error,
      stack: stack,
      meta: meta,
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

/// Time-merges the local stream with the platform-native stream for
/// hydration (ADR 0012 §4): one chronological feed across both writers.
List<LogEntry> mergeLogEntries(
  Iterable<LogEntry> local,
  Iterable<LogEntry> native,
) => [...local, ...native]..sort((a, b) => a.time.compareTo(b.time));

/// Renders [entries] (oldest first) as a plain-text report for copy/export.
String activityLogReport(Iterable<LogEntry> entries) {
  final buffer = StringBuffer('ApertureX activity log\n');
  for (final e in entries) {
    buffer.writeln(
      '${e.time.toIso8601String()} [${e.domain}/${e.level.name}] ${e.message}',
    );
    if (e.error != null) buffer.writeln('    error: ${e.error}');
    if (e.stack != null) {
      for (final line in e.stack!.split('\n')) {
        buffer.writeln('    $line');
      }
    }
  }
  return buffer.toString();
}
