import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/core/error/crash_marker.dart';
import 'package:aperturex/core/error/boundaries.dart';
import 'package:aperturex/core/error/error_reporter.dart';
import 'package:aperturex/core/log/activity_log.dart';

void main() {
  late ActivityLog log;
  late List<ReportedError> presented;
  late ErrorReporter reporter;

  setUp(() {
    log = ActivityLog();
    presented = [];
    reporter = ErrorReporter(log: log, presenter: presented.add);
  });

  FlutterErrorDetails details(Object error, [StackTrace? stack]) =>
      FlutterErrorDetails(exception: error, stack: stack);

  StackTrace stack(String top) =>
      StackTrace.fromString('#0      $top\n#1      next');

  group('BoundaryHooks', () {
    test('onFlutterError reports a non-fatal framework error', () {
      final hooks = BoundaryHooks(reporter: reporter, presentInDebug: false);
      hooks.onFlutterError(details(StateError('build failed'), stack('build()')));

      expect(presented.single.fatal, isFalse);
      final entry = log.entries.single;
      expect(entry.domain, LogDomain.error);
      expect(entry.error, 'Bad state: build failed');
      expect(entry.stack, contains('#0      build()'));
    });

    test('onDispatcherError reports fatal and returns true (app lives)', () {
      final hooks = BoundaryHooks(reporter: reporter);
      final handled = hooks.onDispatcherError(
        ArgumentError('escaped'),
        stack('tick()'),
      );

      expect(handled, isTrue); // engine keeps running (ADR 0012 §1)
      expect(presented.single.fatal, isTrue);
      expect(log.entries.single.domain, LogDomain.crash);
    });

    test('onZoneError is fatal like the dispatcher', () {
      final hooks = BoundaryHooks(reporter: reporter);
      hooks.onZoneError(StateError('async'), stack('future'));

      expect(presented.single.fatal, isTrue);
      expect(log.entries.single.domain, LogDomain.crash);
    });

    test('fatal reports write the crash marker for the next launch', () async {
      final dir = await Directory.systemTemp.createTemp('ax_hooks_');
      addTearDown(() => dir.delete(recursive: true));
      reporter.marker = CrashMarker(File('${dir.path}/crash_marker.json'));
      final hooks = BoundaryHooks(reporter: reporter);

      hooks.onZoneError(StateError('died'), stack('main'));

      // Fire-and-forget write: poll briefly for the file.
      Map<String, Object?>? peek;
      for (var i = 0; i < 100 && peek == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        peek = await reporter.marker!.peek();
      }
      expect(peek, isNotNull);
      expect(peek!['where'], 'dart');
    });
  });

  group('installBoundaryHooks', () {
    late FlutterExceptionHandler? oldOnError;
    late bool Function(Object, StackTrace)? oldDispatcher;

    setUp(() {
      oldOnError = FlutterError.onError;
      oldDispatcher = PlatformDispatcher.instance.onError;
    });

    tearDown(() {
      FlutterError.onError = oldOnError;
      PlatformDispatcher.instance.onError = oldDispatcher;
    });

    test('routes FlutterError.onError and PlatformDispatcher.onError', () {
      final hooks = installBoundaryHooks(
        reporter: reporter,
        presentInDebug: false,
      );
      expect(FlutterError.onError, isNotNull);

      FlutterError.onError!(details(const FormatException('layout'), stack('layout()')));
      expect(presented.single.fatal, isFalse);
      expect(log.entries.single.domain, LogDomain.error);

      final handled = PlatformDispatcher.instance.onError!(
        StateError('escaped'),
        stack('dispatch()'),
      );
      expect(handled, isTrue);
      expect(presented, hasLength(2));
      expect(log.entries.last.domain, LogDomain.crash);
      expect(hooks.reporter, same(reporter));
    });
  });

  group('runGuarded', () {
    test('forwards uncaught async errors from the body to the handler', () async {
      Object? caught;
      StackTrace? caughtStack;
      runGuarded(
        () {
          Future<void>.delayed(Duration.zero, () => throw StateError('zone'));
        },
        (error, stack) {
          caught = error;
          caughtStack = stack;
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(caught, isA<StateError>());
      expect(caughtStack, isNotNull);
    });
  });
}
