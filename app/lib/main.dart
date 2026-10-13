import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'engine/engine.dart';
import 'gallery/gallery_controller.dart';
import 'gallery/photo_gallery_source.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TesseraEngine.init();
  runApp(
    ProviderScope(
      overrides: [
        gallerySourceProvider.overrideWithValue(PhotoGallerySource()),
      ],
      child: const TesseraApp(),
    ),
  );
}

class TesseraApp extends StatelessWidget {
  const TesseraApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Material You on Android S+; seed fallback elsewhere (ADR 0006).
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
          title: 'ApertureX',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(lightDynamic),
          darkTheme: AppTheme.dark(darkDynamic),
          // No localization-delegate override: material_ui's MaterialApp default
          // (DefaultMaterialLocalizations) is used. i18n is deferred to P5 (#22).
          home: const AppShell(),
        );
      },
    );
  }
}
