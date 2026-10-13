import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tessera/ui/snapseed/snapseed_shell.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  testWidgets('starts on Exposure with no radial menu visible', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SnapseedShell())),
      ),
    );

    expect(find.text('Exposure'), findsOneWidget);
    expect(find.byKey(const Key('radial-exposure')), findsNothing);
  });
}
