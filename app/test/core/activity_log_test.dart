import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/core/log/activity_log.dart';

void main() {
  test('encode/decode round-trips an entry', () {
    final entry = LogEntry(
      time: DateTime.parse('2026-01-01T10:00:00.000'),
      domain: LogDomain.editor,
      level: LogLevel.warning,
      message: 'something happened',
    );
    final back = LogEntry.decode(entry.encode())!;
    expect(back.time, entry.time);
    expect(back.domain, LogDomain.editor);
    expect(back.level, LogLevel.warning);
    expect(back.message, 'something happened');
  });

  test('decode tolerates junk and blank lines', () {
    expect(LogEntry.decode('not json'), isNull);
    expect(LogEntry.decode('   '), isNull);
  });

  test('add trims to capacity and forwards to the sink', () {
    final log = ActivityLog(capacity: 3);
    final seen = <String>[];
    log.attachSink((e) => seen.add(e.message));

    for (var i = 0; i < 5; i++) {
      log.add(LogDomain.app, 'm$i');
    }

    expect(log.length, 3);
    expect(log.entries.map((e) => e.message), ['m2', 'm3', 'm4']);
    expect(seen, ['m0', 'm1', 'm2', 'm3', 'm4']);
  });

  test('clear empties and triggers the durable clear hook', () {
    final log = ActivityLog();
    var cleared = false;
    log.attachSink((_) {}, onClear: () => cleared = true);

    log.add(LogDomain.app, 'x');
    log.clear();

    expect(log.isEmpty, isTrue);
    expect(cleared, isTrue);
  });

  test('hydrate seeds the buffer', () {
    final log = ActivityLog();
    log.hydrate([
      LogEntry(
        time: DateTime.parse('2026-01-01T00:00:00.000'),
        domain: LogDomain.gallery,
        level: LogLevel.info,
        message: 'restored',
      ),
    ]);
    expect(log.length, 1);
    expect(log.entries.single.message, 'restored');
  });

  test('report renders a header and one line per entry', () {
    final log = ActivityLog();
    log.add(LogDomain.app, 'hello');
    log.add(LogDomain.export, 'bye', LogLevel.info);

    final report = activityLogReport(log.entries);
    expect(report, startsWith('ApertureX activity log\n'));
    expect(report, contains('[app/debug] hello'));
    expect(report, contains('[export/info] bye'));
  });
}
