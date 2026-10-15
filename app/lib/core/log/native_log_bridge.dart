import 'dart:convert';

import 'package:flutter/services.dart';

import 'activity_log.dart';

/// Reads the platform side's own evidence — `native.log` and the crash marker
/// written by Kotlin (ADR 0012 §4/§6) — over a method channel. Every call is
/// best-effort and degrades to an empty result off-Android: logging must never
/// throw or block startup.
class NativeLogBridge {
  NativeLogBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('aperturex/native_log');

  final MethodChannel _channel;

  /// The newest [limit] native records (oldest first), junk skipped.
  Future<List<LogEntry>> readEntries({int limit = 100}) async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>(
        'readEntries',
        {'limit': limit},
      );
      if (raw == null) return const [];
      return [for (final item in raw) if (item is Map) ?_decode(item)];
    } catch (_) {
      return const [];
    }
  }

  /// The pending crash record from any layer (native writes `where: native`),
  /// or null when nothing crashed / the channel is unavailable.
  Future<Map<String, Object?>?> readCrashMarker() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'readCrashMarker',
      );
      return raw?.cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCrashMarker() async {
    try {
      await _channel.invokeMethod<void>('clearCrashMarker');
    } catch (_) {
      // best effort
    }
  }

  static LogEntry? _decode(Map<Object?, Object?> item) =>
      LogEntry.decode(jsonEncode(item));
}
