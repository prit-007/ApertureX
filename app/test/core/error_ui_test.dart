import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aperturex/core/error/boundaries.dart';
import 'package:aperturex/core/error/boundary_fallback.dart';
import 'package:aperturex/core/error/error_dialog.dart';
import 'package:aperturex/core/error/error_reporter.dart';
import 'package:aperturex/core/log/activity_log.dart';
import 'package:aperturex/core/log/log_providers.dart';
import 'package:aperturex/features/logs/logs_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'logs_help_seen': true});
    activityLog.clear();
  });
  tearDown(activityLog.clear);

  final reported = ReportedError(
    error: StateError('layout blew'),
    stack: StackTrace.fromString('#0      build()'),
    fatal: false,
  );

  group('ErrorDialog', () {
    Future<void> pumpWithDialog(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ErrorDialog(reported: reported),
                ),
                child: const Text('trigger'),
              ),
            ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the error and offers View logs / Copy / Dismiss', (
      tester,
    ) async {
      await pumpWithDialog(tester);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.textContaining('Bad state: layout blew'), findsOneWidget);
      expect(find.text('View logs'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('"View logs" closes the dialog and opens the log page', (
      tester,
    ) async {
      await pumpWithDialog(tester);
      await tester.tap(find.text('View logs'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorDialog), findsNothing);
      expect(find.byType(LogsScreen), findsOneWidget);
      expect(find.text('Activity log'), findsOneWidget);
    });

    testWidgets('"Dismiss" closes the dialog without navigating', (
      tester,
    ) async {
      await pumpWithDialog(tester);
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorDialog), findsNothing);
      expect(find.byType(LogsScreen), findsNothing);
    });
  });

  group('showErrorDialog (root navigator presenter)', () {
    testWidgets('presents through the shared navigator key after the frame', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(navigatorKey: rootNavigatorKey, home: const Scaffold()),
      );
      expect(find.byType(ErrorDialog), findsNothing);

      showErrorDialog(reported);
      await tester.pumpAndSettle();

      expect(find.byType(ErrorDialog), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('is a no-op when the navigator is not attached yet', (
      tester,
    ) async {
      // Before runApp / after teardown there is no context: must not throw.
      showErrorDialog(reported);
      await tester.pump();
      expect(find.byType(ErrorDialog), findsNothing);
    });
  });

  group('BoundaryFallback (ErrorWidget.builder replacement)', () {
    final details = FlutterErrorDetails(
      exception: FormatException('bad json'),
      stack: StackTrace.fromString('#0      parse()'),
    );

    testWidgets('renders an in-place card instead of the raw error', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: BoundaryFallback(details: details)),
      );
      expect(find.text("This section couldn't render"), findsOneWidget);
      expect(find.text('Tap to see what happened'), findsOneWidget);
    });

    testWidgets('tapping the card opens the error popup with the exception', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: BoundaryFallback(details: details)),
      );
      await tester.tap(find.byType(BoundaryFallback));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorDialog), findsOneWidget);
      expect(find.textContaining('FormatException: bad json'), findsOneWidget);
    });
  });

  group('installBoundaryHooks', () {
    late ErrorWidgetBuilder oldBuilder;

    setUp(() => oldBuilder = ErrorWidget.builder);
    tearDown(() => ErrorWidget.builder = oldBuilder);

    test('installs the fallback as ErrorWidget.builder', () {
      final reporter = ErrorReporter(
        log: activityLog,
        presenter: (_) {},
      );
      installBoundaryHooks(reporter: reporter, presentInDebug: false);

      final widget = ErrorWidget.builder(
        FlutterErrorDetails(exception: StateError('x')),
      );
      expect(widget, isA<BoundaryFallback>());
    });
  });

  group('LogsScreen(initialDomain:)', () {
    testWidgets('starts filtered to the requested domain', (tester) async {
      activityLog.add(LogDomain.error, 'bake failed', level: LogLevel.error);
      activityLog.add(LogDomain.gallery, 'picked 3 photos');

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LogsScreen(initialDomain: LogDomain.error))),
      );

      expect(find.text('bake failed'), findsOneWidget);
      expect(find.text('picked 3 photos'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'All'));
      await tester.pumpAndSettle();
      expect(find.text('picked 3 photos'), findsOneWidget);
    });
  });
}
