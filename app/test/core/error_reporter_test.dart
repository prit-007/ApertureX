import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/core/error/crash_marker.dart';
import 'package:aperturex/core/error/error_reporter.dart';
import 'package:aperturex/core/log/activity_log.dart';

void main() {
  late DateTime t;
  DateTime now() => t;
  late ActivityLog log;
  late List<ReportedError> presented;

  setUp(() {
    t = DateTime.parse('2026-10-15T12:00:00.000');
    log = ActivityLog();
    presented = [];
  });

  ErrorReporter reporter({CrashMarker? marker, int maxStackChars = 8000}) =>
      ErrorReporter(
        log: log,
        now: now,
        presenter: presented.add,
        marker: marker,
        maxStackChars: maxStackChars,
      );

  StackTrace stack(String top) => StackTrace.fromString(
    '#0      $top\n#1      another frame',
  );

  /// The marker write is fire-and-forget (report is synchronous, as every
  /// boundary handler is) — wait briefly for the file to land.
  Future<Map<String, Object?>?> settledMarker(CrashMarker marker) async {
    for (var i = 0; i < 100; i++) {
      final peek = await marker.peek();
      if (peek != null) return peek;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return null;
  }

  group('classification & logging', () {
    test('non-fatal reports log to the error domain and present once', () {
      final r = reporter();
      final ok = r.report(StateError('bad LUT'), stack('bake()'), fatal: false);

      expect(ok, isTrue);
      expect(presented, hasLength(1));
      expect(presented.single.fatal, isFalse);
      final e = log.entries.single;
      expect(e.domain, LogDomain.error);
      expect(e.level, LogLevel.error);
      expect(e.error, 'Bad state: bad LUT');
      expect(e.stack, contains('#0      bake()'));
      expect(e.message, contains('StateError'));
    });

    test('fatal reports log to the crash domain and write the marker', () async {
      final dir = await Directory.systemTemp.createTemp('ax_marker_');
      addTearDown(() => dir.delete(recursive: true));
      final marker = CrashMarker(File('${dir.path}/crash_marker.json'));

      final r = reporter(marker: marker);
      final ok = r.report(StateError('boom'), stack('main()'), fatal: true);

      expect(ok, isTrue);
      expect(presented.single.fatal, isTrue);
      expect(log.entries.single.domain, LogDomain.crash);
      final peek = await settledMarker(marker);
      expect(peek, isNotNull);
      expect(peek!['where'], 'dart');
      expect(peek['error'], contains('boom'));
      expect(peek['stack'], contains('#0      main()'));
    });

    test('lastError tracks every report, throttled or not', () {
      final r = reporter();
      r.report(StateError('a'), stack('one()'));
      r.report(FormatException('b'), stack('two()'), fatal: true);

      expect(r.lastError, isNotNull);
      expect(r.lastError!.fatal, isTrue);
      expect(r.lastError!.error, isA<FormatException>());
    });

    test('truncates stacks past maxStackChars', () {
      final r = reporter(maxStackChars: 40);
      final long = StackTrace.fromString('#0      ${'x' * 200}');
      r.report(StateError('s'), long);
      expect(log.entries.single.stack!.length, lessThanOrEqualTo(40));
    });
  });

  group('dedupe & throttle (10 s window)', () {
    test('same error + top frame inside the window logs but no dialog', () {
      final r = reporter();
      expect(r.report(StateError('dup'), stack('paint()')), isTrue);

      t = t.add(const Duration(seconds: 5));
      final second = r.report(StateError('dup'), stack('paint()'));

      expect(second, isFalse);
      expect(presented, hasLength(1)); // no dialog storm
      expect(log, hasLength(2)); // both hits stay in the log
      expect(log.entries.last.meta, {'throttled': true});
    });

    test('after the window the same error presents again', () {
      final r = reporter();
      r.report(StateError('dup'), stack('paint()'));

      t = t.add(const Duration(seconds: 11));
      expect(r.report(StateError('dup'), stack('paint()')), isTrue);
      expect(presented, hasLength(2));
      expect(log.entries.last.meta, isNull);
    });

    test('a different top frame is a new signature and presents', () {
      final r = reporter();
      r.report(StateError('dup'), stack('paint()'));
      expect(r.report(StateError('dup'), stack('layout()')), isTrue);
      expect(presented, hasLength(2));
    });
  });

  group('CrashMarker', () {
    late Directory dir;
    late CrashMarker marker;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('ax_crash_marker_');
      marker = CrashMarker(File('${dir.path}/crash_marker.json'));
    });
    tearDown(() async {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    test('peek is null before anything is written', () async {
      expect(await marker.peek(), isNull);
    });

    test('write then peek round-trips the record', () async {
      await marker.write(
        where: 'native',
        error: 'RuntimeException: ui',
        stack: '#0 activity.onCreate',
      );
      final peek = await marker.peek();
      expect(peek!['where'], 'native');
      expect(peek['error'], contains('RuntimeException'));
      expect(peek['stack'], contains('onCreate'));
      expect(DateTime.parse(peek['t'] as String), isNotNull);
    });

    test('peek tolerates a corrupt file and clear removes it', () async {
      final file = File('${dir.path}/crash_marker.json');
      await file.writeAsString('not json at all');
      expect(await marker.peek(), isNull);

      await marker.write(where: 'dart', error: 'e', stack: 's');
      expect(await marker.peek(), isNotNull);
      await marker.clear();
      expect(await marker.peek(), isNull);
      expect(await file.exists(), isFalse);
    });

    test('write never throws on an unwritable path', () async {
      final bad = CrashMarker(
        File('/this/path/is/not/writable/ever/crash_marker.json'),
      );
      // Best-effort: must not throw (logging never crashes the app).
      await bad.write(where: 'dart', error: 'e', stack: 's');
    });
  });
}
