import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/core/log/activity_log.dart';
import 'package:aperturex/core/log/lifecycle_observer.dart';
import 'package:aperturex/core/log/nav_observer.dart';

void main() {
  group('NavObserver', () {
    late ActivityLog log;
    late NavObserver observer;

    setUp(() {
      log = ActivityLog();
      observer = NavObserver(log: log);
    });

    Route<void> route(String? name) => MaterialPageRoute<void>(
      builder: (_) => const SizedBox(),
      settings: RouteSettings(name: name),
    );

    test('logs pushes with the route name in the nav domain', () {
      observer.didPush(route('/logs'), null);
      final entry = log.entries.single;
      expect(entry.domain, LogDomain.nav);
      expect(entry.message, contains('push'));
      expect(entry.message, contains('/logs'));
    });

    test('logs pops and removes', () {
      observer.didPop(route('/logs'), null);
      observer.didRemove(route('/settings'), null);
      expect(log, hasLength(2));
      expect(log.entries[0].message, contains('pop'));
      expect(log.entries[1].message, contains('remove'));
      expect(log.entries.every((e) => e.domain == LogDomain.nav), isTrue);
    });

    test('logs route replacement', () {
      observer.didReplace(newRoute: route('/editor'), oldRoute: route('/'));
      final entry = log.entries.single;
      expect(entry.message, contains('replace'));
      expect(entry.message, contains('/editor'));
    });

    test('falls back to the route type when no name is set', () {
      observer.didPush(route(null), null);
      expect(log.entries.single.message, contains('MaterialPageRoute'));
    });

    testWidgets('a real push through MaterialApp is captured', (tester) async {
      final testLog = ActivityLog();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [NavObserver(log: testLog)],
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SizedBox(),
                  settings: const RouteSettings(name: '/detail'),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(
        testLog.entries.any((e) => e.domain == LogDomain.nav && e.message.contains('/detail')),
        isTrue,
      );
    });
  });

  group('LifecycleObserver', () {
    late ActivityLog log;
    late LifecycleObserver observer;

    setUp(() {
      log = ActivityLog();
      observer = LifecycleObserver(log: log);
    });

    test('logs every lifecycle transition to the app domain', () {
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      observer.didChangeAppLifecycleState(AppLifecycleState.detached);

      expect(log, hasLength(3));
      expect(log.entries.map((e) => e.message), [
        'lifecycle resumed',
        'lifecycle paused',
        'lifecycle detached',
      ]);
      expect(log.entries.every((e) => e.domain == LogDomain.app), isTrue);
    });

    test('attach/detach is idempotent and tracks its own state', () {
      expect(observer.isAttached, isFalse);

      observer.attach();
      expect(observer.isAttached, isTrue);

      observer.attach(); // second call must not double-register
      expect(observer.isAttached, isTrue);

      observer.detach();
      expect(observer.isAttached, isFalse);

      observer.detach(); // harmless
      expect(observer.isAttached, isFalse);
    });
  });
}
