import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aperturex/settings/shell_preference.dart';
import 'package:aperturex/ui/app_shell.dart';

void main() {
  testWidgets('the gesture shell shows a first-run hint that a touch dismisses', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(shellPreferenceProvider.notifier).select(AppShellKind.snapseed);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: AppShell())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Swipe up / down to pick a tool'), findsOneWidget);

    // Any touch dismisses it (the hint ignores pointers, events pass through).
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Swipe up / down to pick a tool'), findsNothing);
  });
}
