import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'core/log/activity_log.dart';
import 'core/log/log_file_store.dart';
import 'core/log/log_providers.dart';
import 'core/theme/app_theme.dart';
import 'engine/engine.dart';
import 'gallery/gallery_controller.dart';
import 'gallery/gallery_screen.dart';
import 'gallery/photo_gallery_source.dart';
import 'settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TesseraEngine.init();
  await _initActivityLog();
  runApp(
    ProviderScope(
      overrides: [
        gallerySourceProvider.overrideWithValue(PhotoGallerySource()),
      ],
      child: const ApertureXApp(),
    ),
  );
}

/// Restores the durable, on-device activity log and starts appending to it.
Future<void> _initActivityLog() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final store = LogFileStore(File('${dir.path}/activity.log'));
    activityLog.hydrate(await store.read());
    activityLog.attachSink(store.append, onClear: store.clear);
  } catch (_) {
    // Logging must never block startup.
  }
  axLog(LogDomain.app, 'ApertureX started');
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
