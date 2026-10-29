import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/xmp_sidecar.dart';
import 'package:aperturex/features/editor/editor_screen.dart';
import 'package:aperturex/gallery/gallery_asset.dart';
import 'package:aperturex/gallery/gallery_controller.dart';
import 'package:aperturex/gallery/gallery_source.dart';
import 'package:aperturex/platform/file_saver.dart';
import 'package:aperturex/platform/photo_saver.dart';
import 'package:aperturex/settings/export_branding_settings.dart';
import 'package:aperturex/src/rust/api/color.dart' as rust_color;
import 'package:aperturex/src/rust/api/decode.dart';
import 'package:aperturex/src/rust/api/export.dart' as rust_export;
import 'package:aperturex/src/rust/api/mask.dart';
import 'package:aperturex/src/rust/api/retouch.dart';
import 'package:aperturex/src/rust/frb_generated.dart';

const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

/// End-to-end save branch (#104): the editor's "Save to Photos" must route
/// through [photoSaverProvider] — desktop opens the dialog seam, mobile hits
/// the gal seam, and a *direct* `Gal.` call in the screen fails this test
/// (gal's plugin is absent on the host, so the export would die with
/// "Export failed" instead of the success snackbar).
///
/// The Rust export is faked at the bridge ([_ExportApi]) so the whole
/// pipeline runs without a native library — CI's `flutter test` runs before
/// `cargo build`, so a real dylib can't be assumed here.
class _ExportApi extends Fake implements RustLibApi {
  /// What the fake engine "renders" — the bytes the saver must receive.
  static final exportedJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

  @override
  Future<RgbaImage> crateApiDecodeDecodeJpegRgba({required List<int> jpeg}) async =>
      RgbaImage(width: 1, height: 1, rgba: Uint8List.fromList([1, 2, 3, 255]));

  @override
  Future<Uint8List> crateApiExifExtractExif({required List<int> jpeg}) async =>
      Uint8List(0);

  @override
  Future<BigInt> crateApiExportExportCancelNew() async => BigInt.one;

  @override
  Future<void> crateApiExportExportCancelSet({required BigInt token}) async {}

  @override
  Future<void> crateApiExportExportCancelDrop({required BigInt token}) async {}

  @override
  Future<int> crateApiExportExportProgressGet({required BigInt token}) async => 0;

  @override
  Future<rust_export.ExportResult> crateApiExportExportFull({
    required List<int> rgba,
    required int width,
    required int height,
    required rust_export.ExportSpec spec,
    required List<MaskLayer> layers,
    required List<ApiRetouchPatch> retouchPatches,
    required rust_color.ColorParams params,
    required rust_color.CurveParams curves,
    required List<double> hsl,
    required List<int> exif,
  }) async =>
      rust_export.ExportResult(cancelled: false, jpeg: exportedJpeg);

  @override
  Future<rust_export.ExportResult> crateApiExportExportFullWithBranding({
    required List<int> rgba,
    required int width,
    required int height,
    required rust_export.ExportSpec spec,
    required List<MaskLayer> layers,
    required List<ApiRetouchPatch> retouchPatches,
    required rust_color.ColorParams params,
    required rust_color.CurveParams curves,
    required List<double> hsl,
    required List<int> exif,
    required rust_export.ExportBrandingSpec branding,
    required rust_export.C2paExportSpec c2Pa,
  }) async =>
      rust_export.ExportResult(cancelled: false, jpeg: exportedJpeg);
}

class _RecordingDialog {
  int calls = 0;
  Uint8List? lastBytes;
  String? lastSuggested;
  String? nextPath;

  Future<String?> call(Uint8List bytes, String suggestedName) async {
    calls++;
    lastBytes = bytes;
    lastSuggested = suggestedName;
    return nextPath;
  }
}

class _RecordingSink implements GallerySink {
  int hasAccessCalls = 0;
  int requestAccessCalls = 0;
  final List<(Uint8List bytes, String name)> byteSaves = [];
  final List<String> pathSaves = [];

  @override
  Future<bool> hasAccess() async {
    hasAccessCalls++;
    return true;
  }

  @override
  Future<bool> requestAccess() async {
    requestAccessCalls++;
    return true;
  }

  @override
  Future<void> putImageBytes(Uint8List bytes, {required String name}) async {
    byteSaves.add((bytes, name));
  }

  @override
  Future<void> putImage(String path) async {
    pathSaves.add(path);
  }
}

/// In-memory sidecar: the production sink writes a real .xmp file, and real
/// IO never completes under fake async — it would hang pumpAndSettle.
class _MemorySidecarSink implements XmpSidecarSink {
  final written = <String>[];

  @override
  Future<void> write(String imageName, EditRecipe recipe) async {
    written.add(imageName);
  }
}

/// A valid 1×1 PNG (same fixture as editor_screen_test).
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late _RecordingDialog dialog;
  late _RecordingSink sink;
  late _MemorySidecarSink sidecar;

  setUpAll(() {
    RustLib.initMock(api: _ExportApi());
  });

  setUp(() async {
    // C2PA must stay off: the real path generates a device key through Rust
    // and shared prefs — orthogonal to the save branch under test.
    SharedPreferences.setMockInitialValues({'branding_c2pa_enabled': false});
    tmp = await Directory.systemTemp.createTemp('editor_save_test_');
    dialog = _RecordingDialog();
    sink = _RecordingSink();
    sidecar = _MemorySidecarSink();
    // The XMP sidecar resolves the app documents folder through path_provider;
    // an unmocked platform message never completes under fake async (it
    // silently hangs pumpAndSettle), so pin it to this test's sandbox.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async => tmp.path);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<ProviderContainer> pumpEditor(
    WidgetTester tester, {
    required bool isDesktop,
  }) async {
    final container = ProviderContainer(
      overrides: [
        gallerySourceProvider.overrideWithValue(
          FakeGallerySource(images: {'a': _png}),
        ),
        isDesktopPlatformProvider.overrideWithValue(isDesktop),
        savePathDialogProvider.overrideWithValue(dialog.call),
        gallerySinkProvider.overrideWithValue(sink),
        exportSidecarSinkProvider.overrideWithValue(sidecar),
      ],
    );
    addTearDown(container.dispose);

    // Start the async prefs load now: without this the export could read the
    // notifier's synchronous default (enableC2pa: true) and race into C2PA
    // device-key generation, which this test deliberately doesn't mock.
    container.read(exportBrandingProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: EditorScreen(
            asset: GalleryAsset(id: 'a', width: 1, height: 1),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(exportBrandingProvider).enableC2pa, isFalse,
        reason: 'branding prefs must finish loading before the export runs');
    return container;
  }

  Future<void> tapSaveToPhotos(WidgetTester tester) async {
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to Photos'));
    // The desktop branch performs a real File.writeAsBytes; real IO only
    // completes on real event-loop turns, which fake-async pumps never
    // deliver — interleave runAsync until a terminal snackbar appears, then
    // let the snackbar entrance settle in fake time.
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 25));
      final done = find.textContaining('Saved').evaluate().isNotEmpty ||
          find.text('Save cancelled').evaluate().isNotEmpty ||
          find.textContaining('failed').evaluate().isNotEmpty;
      if (done) break;
    }
    await tester.pumpAndSettle();
  }

  testWidgets('desktop save → dialog seam, gal sink untouched, path snackbar', (
    tester,
  ) async {
    final chosen = '${tmp.path}/aperturex_out.jpg';
    dialog.nextPath = chosen;
    await pumpEditor(tester, isDesktop: true);

    await tapSaveToPhotos(tester);

    expect(dialog.calls, 1, reason: 'exactly one save dialog');
    expect(dialog.lastSuggested, startsWith('aperturex_'));
    expect(dialog.lastSuggested, endsWith('.jpg'));
    expect(dialog.lastBytes, _ExportApi.exportedJpeg,
        reason: 'the saver must hand the dialog the rendered JPEG bytes');
    expect(
      File(chosen).readAsBytesSync(),
      _ExportApi.exportedJpeg,
      reason: 'the chosen path holds the export byte-identically',
    );
    expect(sink.hasAccessCalls, 0,
        reason: 'a desktop save reaching gal would throw MissingPluginException '
            'on this host — the sink must stay untouched');
    expect(sink.byteSaves, isEmpty);
    expect(sink.pathSaves, isEmpty);
    expect(find.text('Saved to $chosen'), findsOneWidget);
    expect(find.textContaining('Export failed'), findsNothing);
  });

  testWidgets('desktop dialog cancel → quiet abort, nothing written', (
    tester,
  ) async {
    dialog.nextPath = null;
    await pumpEditor(tester, isDesktop: true);

    await tapSaveToPhotos(tester);

    expect(find.text('Save cancelled'), findsOneWidget);
    expect(find.textContaining('Export failed'), findsNothing);
    expect(sink.hasAccessCalls, 0);
    expect(sink.byteSaves, isEmpty);
    expect(tmp.listSync(), isEmpty, reason: 'cancel writes nothing');
  });

  testWidgets('mobile save → gal seam, dialog never opened', (tester) async {
    await pumpEditor(tester, isDesktop: false);

    await tapSaveToPhotos(tester);

    expect(sink.hasAccessCalls, 1);
    expect(sink.byteSaves, hasLength(1));
    expect(sink.byteSaves.single.$2, startsWith('aperturex_'));
    expect(sink.byteSaves.single.$1, _ExportApi.exportedJpeg);
    expect(dialog.calls, 0, reason: 'mobile must never open a file dialog');
    expect(find.text('Saved to your photos'), findsOneWidget);
    expect(find.textContaining('Export failed'), findsNothing);
  });
}
