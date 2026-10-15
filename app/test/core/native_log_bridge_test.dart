import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/core/log/activity_log.dart';
import 'package:aperturex/core/log/native_log_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('aperturex/native_log');

  void mock(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  void unmock() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }

  tearDown(unmock);

  group('NativeLogBridge.readEntries', () {
    test('decodes the platform JSONL records into LogEntry objects', () async {
      mock((call) async {
        expect(call.method, 'readEntries');
        expect(call.arguments, {'limit': 50});
        return <Object?>[
          {'t': '2026-10-15T10:00:00.000', 'd': 'native', 'l': 'error', 'm': 'ui thread died', 's': '#0 onCreate'},
          {'t': '2026-10-15T10:00:01.000', 'd': 'native', 'l': 'info', 'm': 'started'},
        ];
      });

      final entries = await NativeLogBridge().readEntries(limit: 50);

      expect(entries, hasLength(2));
      expect(entries.first.message, 'ui thread died');
      expect(entries.first.domain, LogDomain.native);
      expect(entries.first.stack, '#0 onCreate');
      expect(entries.last.message, 'started');
    });

    test('skips junk records without failing the batch', () async {
      mock((call) async => <Object?>[
        'not a map at all',
        <Object?, Object?>{'bogus': true},
        {'t': '2026-10-15T10:00:00.000', 'd': 'native', 'l': 'error', 'm': 'good'},
      ]);

      final entries = await NativeLogBridge().readEntries();

      expect(entries, hasLength(1));
      expect(entries.single.message, 'good');
    });

    test('degrades to an empty list when the channel is missing (iOS/tests)', () async {
      // No mock handler → MissingPluginException → must never throw.
      final entries = await NativeLogBridge().readEntries();
      expect(entries, isEmpty);
    });

    test('degrades to an empty list when the channel errors', () async {
      mock((call) async => throw PlatformException(code: 'native_error'));
      expect(await NativeLogBridge().readEntries(), isEmpty);
    });
  });

  group('NativeLogBridge crash marker', () {
    test('reads the marker map', () async {
      mock((call) async {
        expect(call.method, 'readCrashMarker');
        return <Object?, Object?>{
          't': '2026-10-15T10:00:00.000',
          'where': 'native',
          'error': 'RuntimeException: boom',
          'stack': '#0 activity.onCreate',
        };
      });

      final marker = await NativeLogBridge().readCrashMarker();
      expect(marker, isNotNull);
      expect(marker!['where'], 'native');
      expect(marker['error'], contains('boom'));
    });

    test('null marker (nothing crashed) and missing channel both degrade', () async {
      mock((call) async => null);
      expect(await NativeLogBridge().readCrashMarker(), isNull);

      unmock();
      expect(await NativeLogBridge().readCrashMarker(), isNull);
    });

    test('clearCrashMarker never throws, even on channel failure', () async {
      mock((call) async => throw PlatformException(code: 'gone'));
      await NativeLogBridge().clearCrashMarker(); // no exception expected
    });
  });

  group('mergeLogEntries', () {
    test('interleaves local and native records by time', () {
      LogEntry at(String iso, String message, {String domain = LogDomain.app}) =>
          LogEntry(
            time: DateTime.parse(iso),
            domain: domain,
            level: LogLevel.info,
            message: message,
          );

      final merged = mergeLogEntries(
        [
          at('2026-10-15T10:00:02.000', 'local late'),
          at('2026-10-15T10:00:00.000', 'local early'),
        ],
        [at('2026-10-15T10:00:01.000', 'native mid', domain: LogDomain.native)],
      );

      expect(merged.map((e) => e.message), [
        'local early',
        'native mid',
        'local late',
      ]);
    });
  });
}
