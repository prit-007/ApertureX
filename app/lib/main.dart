import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'core/error/boundaries.dart';
import 'core/error/crash_marker.dart';
import 'core/error/crash_report_dialog.dart';
import 'core/error/error_dialog.dart';
import 'core/error/error_reporter.dart';

import 'core/log/activity_log.dart';
import 'core/log/log_file_store.dart';
import 'core/log/lifecycle_observer.dart';
import 'core/log/log_providers.dart';
import 'core/log/nav_observer.dart';
import 'core/log/native_log_bridge.dart';
import 'core/theme/app_theme.dart';
import 'engine/engine.dart';
import 'gallery/gallery_controller.dart';
import 'gallery/gallery_screen.dart';
import 'gallery/photo_gallery_source.dart';
import 'settings/app_settings.dart';
import 'ui/precision_gear.dart';
import 'viewport/shader_warmup.dart';

/// The whole app runs inside the error boundary (ADR 0012): the framework
/// hooks are installed first, then bootstrap + UI are guarded by a zone so
/// no error — not even one during init — can kill the process. Fatal hits are
/// logged, marked for the next-launch report, and the app keeps living.
void main() {
  final reporter = ErrorReporter(presenter: showErrorDialog);
  installBoundaryHooks(reporter: reporter);

  runGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      lifecycleObserver.attach();
      try {
        await AxEngine.init();
        await _initActivityLog(reporter);
      } catch (error, stack) {
        // Degrade, don't die: every later engine call re-hits the boundary.
        reporter.report(error, stack, fatal: true);
      }
      runApp(
        bootstrapApp(
          overrides: [
            gallerySourceProvider.overrideWithValue(PhotoGallerySource()),
          ],
          child: PrecisionListener(child: const ApertureXApp()),
        ),
      );
    },
    (error, stack) => reporter.report(error, stack, fatal: true),
  );
}

/// Restores the durable, on-device activity log and starts appending to it.
/// Also attaches the crash marker once the app-support directory is known.
Future<void> _initActivityLog(ErrorReporter reporter) async {
  try {
    final dir = await getApplicationSupportDirectory();
    reporter.marker = CrashMarker(File('${dir.path}/crash_marker.json'));
    // Rust keeps its own panic evidence beside the log (ADR 0012 §7).
    await AxEngine.initPanicHook(dir: dir.path);
    // activity.log + native.log + rust_panic.log → one feed the UI shows.
    await hydrateActivityLog(dir);
    final store = LogFileStore(File('${dir.path}/activity.log'));
    activityLog.attachSink(store.append, onClear: store.clear);
    // One-time next-launch offer when the last session left a marker from
    // either layer (ADR 0012 §3); the dialog lands on the log page.
    await showCrashReport(marker: reporter.marker, bridge: NativeLogBridge());
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
          navigatorKey: rootNavigatorKey,
          navigatorObservers: [navObserver],
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
