import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tessera/core/log/activity_log.dart';
import 'package:tessera/core/log/log_providers.dart';
import 'package:tessera/features/logs/logs_screen.dart';

void main() {
  setUp(activityLog.clear);
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
}
