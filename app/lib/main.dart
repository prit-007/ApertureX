import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'engine/engine.dart';
import 'features/editor/editor_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TesseraEngine.init();
  runApp(const TesseraApp());
}

class TesseraApp extends StatelessWidget {
  const TesseraApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Material You on Android S+; seed fallback elsewhere (ADR 0006).
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
          title: 'Tessera',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(lightDynamic),
          darkTheme: AppTheme.dark(darkDynamic),
          localizationsDelegates: const [
            ...GlobalMaterialLocalizations.delegates,
            ...GlobalCupertinoLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en')],
          home: const EditorScreen(),
        );
      },
    );
  }
}
