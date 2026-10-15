import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/core/log/activity_log.dart';
import 'package:aperturex/core/log/log_file_store.dart';

void main() {
  group('LogEntry schema v2 (error/stack/meta)', () {
    test('round-trips error, stack and meta alongside the base fields', () {
      final entry = LogEntry(
        time: DateTime.parse('2026-01-01T10:00:00.000'),
        domain: LogDomain.error,
        level: LogLevel.error,
        message: 'bake failed',
        error: 'StateError: bad LUT',
        stack: '#0 main\n#1 run',
        meta: {'image': 'a.jpg', 'rows': 128},
      );
      final back = LogEntry.decode(entry.encode())!;
      expect(back.time, entry.time);
      expect(back.domain, LogDomain.error);
      expect(back.level, LogLevel.error);
      expect(back.message, 'bake failed');
      expect(back.error, 'StateError: bad LUT');
      expect(back.stack, '#0 main\n#1 run');
      expect(back.meta, {'image': 'a.jpg', 'rows': 128});
    });

    test('decodes legacy lines (t/d/l/m only) with null attachments', () {
      final legacy = '{"t":"2025-06-01T00:00:00.000","d":"app",'
          '"l":"info","m":"old line"}';
      final entry = LogEntry.decode(legacy)!;
      expect(entry.message, 'old line');
      expect(entry.error, isNull);
      expect(entry.stack, isNull);
      expect(entry.meta, isNull);
    });

    test('ignores unknown keys (forward compatible)', () {
      final future =
          '{"t":"2026-01-01T10:00:00.000","d":"nav","l":"debug",'
          '"m":"pushed","future_field":{"a":1}}';
      final entry = LogEntry.decode(future)!;
      expect(entry.domain, LogDomain.nav);
      expect(entry.error, isNull);
      expect(entry.meta, isNull);
    });
  });

  group('resilience domains', () {
    test('error/crash/nav/native/engine exist and are in LogDomain.all', () {
      expect(LogDomain.error, 'error');
      expect(LogDomain.crash, 'crash');
      expect(LogDomain.nav, 'nav');
      expect(LogDomain.native, 'native');
      expect(LogDomain.engine, 'engine');
      expect(LogDomain.all, containsAll(['error', 'crash', 'nav', 'native', 'engine']));
    });
  });

  group('activityLogReport', () {
    test('prints the error and indented stack when present', () {
      final log = ActivityLog();
      log.add(
        LogDomain.error,
        'bake failed',
        level: LogLevel.error,
        error: 'StateError: bad LUT',
        stack: 'frame one\nframe two',
      );
      final report = activityLogReport(log.entries);
      expect(report, contains('[error/error] bake failed'));
      expect(report, contains('error: StateError: bad LUT'));
      expect(report, contains('    frame one'));
      expect(report, contains('    frame two'));
    });
  });

  group('LogFileStore persistence + rotation', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('ax_log_test_');
    });

    tearDown(() async {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    test('appends JSONL and reads the newest entries back', () async {
      final store = LogFileStore(File('${dir.path}/activity.log'));
      await store.append(
        LogEntry(
          time: DateTime.parse('2026-01-01T00:00:00.000'),
          domain: LogDomain.app,
          level: LogLevel.info,
          message: 'first',
        ),
      );
      await store.append(
        LogEntry(
          time: DateTime.parse('2026-01-01T00:00:01.000'),
          domain: LogDomain.export,
          level: LogLevel.error,
          message: 'second',
          error: 'boom',
        ),
      );
      final read = await store.read();
      expect(read.map((e) => e.message), ['first', 'second']);
      expect(read.last.error, 'boom');
    });

    test('read tolerates a missing file', () async {
      final store = LogFileStore(File('${dir.path}/absent.log'));
      expect(await store.read(), isEmpty);
    });

    test('rotates once over maxBytes, keeping only the newest lines', () async {
      final store = LogFileStore(
        File('${dir.path}/activity.log'),
        maxBytes: 400,
        keepLines: 3,
      );
      for (var i = 0; i < 40; i++) {
        await store.append(
          LogEntry(
            time: DateTime.parse('2026-01-01T00:00:00.000'),
            domain: LogDomain.nav,
            level: LogLevel.debug,
            message: 'entry-$i-${'x' * 40}',
          ),
        );
      }
      final file = File('${dir.path}/activity.log');
      expect(await file.length(), lessThanOrEqualTo(400));
      final read = await store.read(limit: 50);
      expect(read, hasLength(3));
      expect(read.last.message, startsWith('entry-39-'));
    });

    test('clear deletes the file', () async {
      final file = File('${dir.path}/activity.log');
      final store = LogFileStore(file);
      await store.append(
        LogEntry(
          time: DateTime.parse('2026-01-01T00:00:00.000'),
          domain: LogDomain.app,
          level: LogLevel.info,
          message: 'x',
        ),
      );
      await store.clear();
      expect(await file.exists(), isFalse);
    });
  });
}
