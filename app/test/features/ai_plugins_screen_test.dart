import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aperturex/features/ai_plugins/ai_plugins_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AiPluginsScreen renders tabs and allows adding custom model', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AiPluginsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Models & Plugins'), findsOneWidget);
    expect(find.text('Installed'), findsOneWidget);
    expect(find.text('Community Hub'), findsOneWidget);
    expect(find.text('ApertureX Neural Forge'), findsOneWidget);
    expect(find.text('ApertureX On-Device Saliency'), findsOneWidget);

    // Switch to Community Hub
    await tester.tap(find.text('Community Hub'));
    await tester.pumpAndSettle();

    expect(find.text('Verified Open-Source Models'), findsOneWidget);
    expect(find.text('Depth Anything V2 (Small)'), findsOneWidget);
    expect(find.text('RMBG 1.4 High-Res Matting'), findsOneWidget);

    // Tap Add via GitHub / Link
    await tester.tap(find.text('Add via GitHub / Link'));
    await tester.pumpAndSettle();

    expect(find.text('Add Custom AI Plugin'), findsOneWidget);
    expect(find.text('Model Name'), findsOneWidget);
    expect(find.text('GitHub / HuggingFace Model URL'), findsOneWidget);
    expect(find.text('Install & Activate Plugin'), findsOneWidget);
  });
}
