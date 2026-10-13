import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'engine/engine.dart';
import 'gallery/gallery_controller.dart';
import 'gallery/gallery_screen.dart';
import 'gallery/photo_gallery_source.dart';
import 'settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TesseraEngine.init();
  runApp(
    ProviderScope(
      overrides: [
        gallerySourceProvider.overrideWithValue(PhotoGallerySource()),
      ],
      child: const ApertureXApp(),
    ),
  );
}

class ApertureXApp extends ConsumerWidget {
  const ApertureXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    // Material You on Android S+; seed fallback elsewhere (ADR 0006).
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
          title: 'ApertureX',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(lightDynamic),
          darkTheme: AppTheme.dark(darkDynamic),
          themeMode: themeMode,
          home: const GalleryScreen(),
        );
      },
    );
  }
}
