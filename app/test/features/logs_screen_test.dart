import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aperturex/core/log/activity_log.dart';
import 'package:aperturex/core/log/log_providers.dart';
import 'package:aperturex/features/logs/logs_screen.dart';

void main() {
  setUp(() {
    // Default: the first-run guide has already been seen.
    SharedPreferences.setMockInitialValues({'logs_help_seen': true});
    activityLog.clear();
  });
  tearDown(activityLog.clear);

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: LogsScreen())),
  );

  testWidgets('shows an empty state with no activity', (tester) async {
    await pump(tester);
    expect(find.text('No activity yet'), findsOneWidget);
  });

  testWidgets('lists entries and filters by domain', (tester) async {
    activityLog.add(LogDomain.gallery, 'loaded 3 photos');
    activityLog.add(LogDomain.editor, 'opened photo a');

    await pump(tester);
    expect(find.text('loaded 3 photos'), findsOneWidget);
    expect(find.text('opened photo a'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'editor'));
    await tester.pumpAndSettle();

    expect(find.text('loaded 3 photos'), findsNothing);
    expect(find.text('opened photo a'), findsOneWidget);
  });

  testWidgets('clearing empties the feed', (tester) async {
    activityLog.add(LogDomain.app, 'started');
    await pump(tester);
    expect(find.text('started'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('No activity yet'), findsOneWidget);
    expect(activityLog.isEmpty, isTrue);
  });

  testWidgets('shows the first-run guide once and dismisses it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('logs_help_seen'), isTrue);
  });

  testWidgets('the Guide action reopens the walkthrough', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Guide'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
  });

  test('maps every domain to a colour, including the resilience buckets', () {
    const scheme = ColorScheme.light();
    expect(domainColor(LogDomain.error, scheme), scheme.error);
    expect(domainColor(LogDomain.crash, scheme), const Color(0xFFB71C1C));
    expect(domainColor(LogDomain.nav, scheme), scheme.tertiary);
    expect(domainColor(LogDomain.native, scheme), scheme.secondary);
    expect(domainColor(LogDomain.engine, scheme), const Color(0xFF00ACC1));
    for (final domain in LogDomain.all) {
      expect(domainColor(domain, scheme), isNotNull);
    }
  });

  testWidgets('error entries expand to reveal the error and stack', (tester) async {
    activityLog.add(
      LogDomain.error,
      'bake failed',
      level: LogLevel.error,
      error: 'StateError: bad LUT',
      stack: '#0 bake()\n#1 main()',
    );
    activityLog.add(LogDomain.app, 'plain note');

    await pump(tester);
    expect(find.textContaining('StateError: bad LUT'), findsNothing);

    await tester.tap(find.text('bake failed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('StateError: bad LUT'), findsOneWidget);
    expect(find.textContaining('#0 bake()'), findsOneWidget);

    await tester.tap(find.text('bake failed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('StateError: bad LUT'), findsNothing);

    // Only the failed entry carries the expand affordance.
    expect(find.byIcon(Icons.unfold_more), findsOneWidget);
  });
}
