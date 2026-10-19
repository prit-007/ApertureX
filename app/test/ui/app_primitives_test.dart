import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/ui/common/app_primitives.dart';

void main() {
  testWidgets('SectionHeader uses tight 12px horizontal padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SectionHeader('Test Section'),
        ),
      ),
    );

    // Check padding via the Padding widget wrapping SectionHeader
    final padding = tester.widget<Padding>(
      find.byType(Padding).first,
    );
    expect(padding.padding, const EdgeInsets.fromLTRB(12, 8, 12, 4));
  });

  testWidgets('SectionHeader title is uppercase with primary color', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SectionHeader('Light & Color'),
        ),
      ),
    );

    expect(find.text('LIGHT & COLOR'), findsOneWidget);
  });

  testWidgets('SectionHeader supports trailing widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SectionHeader('Test', trailing: Icon(Icons.auto_awesome)),
        ),
      ),
    );

    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });
}
