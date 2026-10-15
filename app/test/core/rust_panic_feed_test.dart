import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/core/log/activity_log.dart';
import 'package:aperturex/core/log/log_providers.dart';
import 'package:aperturex/core/log/native_log_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('aperturex/native_log');

  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('aperturex_feed_');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  void mockNative(List<Object?> records) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => records);
  }

  LogEntry entry(String iso, String message, {String domain = LogDomain.app}) =>
      LogEntry(
        time: DateTime.parse(iso),
        domain: domain,
        level: LogLevel.info,
        message: message,
      );

  test('hydrate merges local, native and rust panic streams by time',
      () async {
    File('${dir.path}/activity.log').writeAsStringSync(
      '${entry('2026-10-15T10:00:00.000', 'app started').encode()}\n',
    );
    // The Rust writer's LogEntry-compatible JSONL (ADR 0012 §7).
    File('${dir.path}/rust_panic.log').writeAsStringSync(
      '{"t":"2026-10-15T10:30:00.000Z","d":"crash","l":"error",'
      '"m":"Rust panic: index out of bounds","e":"index out of bounds",'
      '"s":"panicked at src/api/spatial.rs:12:3"}\n'
      'garbage line that must be skipped\n',
    );
    mockNative([
      {
        't': '2026-10-15T10:15:00.000',
        'd': 'native',
        'l': 'error',
        'm': 'ui thread jank',
      },
    ]);

    final target = ActivityLog();
    await hydrateActivityLog(dir, target: target, bridge: NativeLogBridge());

    final entries = target.entries;
    expect(entries.map((e) => e.message), [
      'app started',
      'ui thread jank',
      'Rust panic: index out of bounds',
    ]);
    final rust = entries.last;
    expect(rust.domain, LogDomain.crash);
    expect(rust.level, LogLevel.error);
    expect(rust.error, 'index out of bounds');
    expect(rust.stack, contains('spatial.rs'));
  });

  test('hydrate tolerates every stream missing or failing', () async {
    // No files, no channel mock → all three degrade to empty.
    final target = ActivityLog();
    await hydrateActivityLog(dir, target: target, bridge: NativeLogBridge());
    expect(target.entries, isEmpty);
  });

  test('without a target it hydrates the shared global log (replace)', () async {
    mockNative(const []);
    await hydrateActivityLog(dir, bridge: NativeLogBridge());
    // Replace semantics: empty streams leave exactly nothing behind.
    expect(activityLog.entries, isEmpty);
  });
}
