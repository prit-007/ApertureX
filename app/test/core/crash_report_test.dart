import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aperturex/core/error/crash_marker.dart';
import 'package:aperturex/core/error/crash_report_dialog.dart';
import 'package:aperturex/core/error/error_dialog.dart' show rootNavigatorKey;
import 'package:aperturex/core/log/native_log_bridge.dart';
import 'package:aperturex/features/logs/logs_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('aperturex/native_log');

  late Directory dir;
  late CrashMarker marker;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('aperturex_crash_report_');
    marker = CrashMarker(File('${dir.path}/crash_marker.json'));
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  void mockNativeMarker(Map<Object?, Object?>? record) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'readCrashMarker' ? record : null,
    );
  }

  group('peekPendingCrash', () {
    test('prefers the Dart-layer marker when present', () async {
      await marker.write(
        where: 'dart',
        error: 'Bad state: zone leak',
        stack: '#0 main',
      );
      mockNativeMarker({
        't': '2026-10-15T09:00:00.000',
        'where': 'native',
        'error': 'RuntimeException: native boom',
        'stack': '#0 onCreate',
      });

      final record = await peekPendingCrash(
        marker: marker,
        bridge: NativeLogBridge(),
      );
      expect(record, isNotNull);
      expect(record!['where'], 'dart');
      expect(record['error'], contains('zone leak'));
    });

    test('falls back to the platform marker', () async {
      mockNativeMarker({
        't': '2026-10-15T09:00:00.000',
        'where': 'native',
        'error': 'RuntimeException: native boom',
        'stack': '#0 onCreate',
      });

      final record = await peekPendingCrash(
        marker: marker,
        bridge: NativeLogBridge(),
      );
      expect(record!['where'], 'native');
    });

    test('null when neither layer recorded a crash', () async {
      mockNativeMarker(null);
      expect(
        await peekPendingCrash(marker: marker, bridge: NativeLogBridge()),
        isNull,
      );
    });
  });

  group('showCrashReport', () {
    Future<void> pumpShell(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const Scaffold(body: Text('home')),
          ),
        ),
      );
    }

    testWidgets('offers the log page once a marker exists, then clears it',
        (tester) async {
      await pumpShell(tester);
      // Real file I/O must escape the widget test's FakeAsync zone.
      await tester.runAsync(() async {
        await marker.write(
          where: 'dart',
          error: 'StateError: editor exploded',
          stack: '#0 build',
        );
        await showCrashReport(marker: marker, bridge: NativeLogBridge());
      });
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('ApertureX crashed last time'), findsOneWidget);
      expect(find.textContaining('StateError: editor exploded'), findsOneWidget);

      // Consumed at most once.
      expect(await tester.runAsync(marker.peek), isNull);

      await tester.tap(find.text('View logs'));
      await tester.pumpAndSettle();
      expect(find.byType(LogsScreen), findsOneWidget);
      expect(find.text('ApertureX crashed last time'), findsNothing);
    });

    testWidgets('no marker anywhere → no dialog', (tester) async {
      await pumpShell(tester);
      mockNativeMarker(null);

      await tester.runAsync(
        () => showCrashReport(marker: marker, bridge: NativeLogBridge()),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(CrashReportDialog), findsNothing);
    });

    testWidgets('native-layer crash still offers the log page',
        (tester) async {
      await pumpShell(tester);
      mockNativeMarker({
        't': '2026-10-15T09:00:00.000',
        'where': 'native',
        'error': 'RuntimeException: BitmapRegionDecoder died',
        'stack': '#0 decodeRegion',
      });

      await tester.runAsync(
        () => showCrashReport(marker: marker, bridge: NativeLogBridge()),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('ApertureX crashed last time'), findsOneWidget);
      expect(
        find.textContaining('BitmapRegionDecoder died'),
        findsOneWidget,
      );
      // Both layers cleared so next launch stays quiet.
      expect(await tester.runAsync(marker.peek), isNull);
    });
  });
}
