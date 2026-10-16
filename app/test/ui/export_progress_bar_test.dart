import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/features/editor/export_progress.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester, {double? value}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportProgressBar(
            key: const Key('export-progress'),
            label: value == null ? 'Decoding' : 'Rendering',
            value: value,
          ),
        ),
      ),
    );
  }

  testWidgets('shows the phase label and a determinate bar with a percent', (
    tester,
  ) async {
    await pumpBar(tester, value: 0.42);
    expect(find.byKey(const Key('export-progress')), findsOneWidget);
    expect(find.text('Rendering'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.42);
  });

  testWidgets('a null value renders an indeterminate bar', (tester) async {
    await pumpBar(tester);
    expect(find.text('Decoding'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, isNull);
  });

  testWidgets('the percent tracks the value as it advances', (tester) async {
    await pumpBar(tester, value: 0.1);
    expect(find.text('10%'), findsOneWidget);
    await pumpBar(tester, value: 0.75);
    expect(find.text('75%'), findsOneWidget);
  });
}
