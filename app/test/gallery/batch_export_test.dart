import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:aperturex/edit/library_catalog.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/recipe_store.dart';
import 'package:aperturex/edit/settings_clipboard.dart';
import 'package:aperturex/gallery/gallery_asset.dart';
import 'package:aperturex/gallery/gallery_controller.dart';
import 'package:aperturex/gallery/gallery_export.dart';
import 'package:aperturex/gallery/gallery_screen.dart';
import 'package:aperturex/gallery/gallery_source.dart';
import 'package:aperturex/platform/photo_saver.dart';
import 'package:aperturex/settings/export_settings.dart';
import 'package:aperturex/src/rust/frb_generated.dart';

/// A valid 1×1 PNG so `Image.memory` decodes in tests.
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

FakeGallerySource _twoPhotos() => FakeGallerySource(
  images: {'a': _png, 'b': _png},
  thumbnails: {'a': _png, 'b': _png},
  assets: const [
    GalleryAsset(id: 'a', width: 1, height: 1),
    GalleryAsset(id: 'b', width: 1, height: 1),
  ],
);

/// Records gal-seam traffic (#104): desktop batches must leave it untouched.
class _RecordingSink implements GallerySink {
  int hasAccessCalls = 0;
  final List<(Uint8List bytes, String name)> byteSaves = [];
  final List<String> pathSaves = [];

  @override
  Future<bool> hasAccess() async {
    hasAccessCalls++;
    return true;
  }

  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<void> putImageBytes(Uint8List bytes, {required String name}) async {
    byteSaves.add((bytes, name));
  }

  @override
  Future<void> putImage(String path) async {
    pathSaves.add(path);
  }
}

void main() {
  group('bounded batch pool', () {
    test('never runs more than maxConcurrent items at once', () async {
      var inFlight = 0;
      var maxInFlight = 0;
      final barrier = Completer<void>();
      final exporter = GalleryExporter(
        FakeGallerySource(),
        maxConcurrent: 2,
        item: (id, recipe) async {
          inFlight++;
          if (inFlight > maxInFlight) maxInFlight = inFlight;
          if (inFlight == 2 && !barrier.isCompleted) barrier.complete();
          await barrier.future;
          inFlight--;
          return true;
        },
      );

      final result = await exporter.exportBatch(
        const ['a', 'b', 'c', 'd', 'e'],
        (_) => EditRecipe.neutral,
      );

      expect(maxInFlight, 2);
      expect(result.exported, 5);
      expect(result.failed, isEmpty);
    });

    test('reports monotonic progress and a final count', () async {
      final progress = <BatchExportProgress>[];
      final exporter = GalleryExporter(
        FakeGallerySource(),
        item: (id, recipe) async => true,
      );

      final result = await exporter.exportBatch(
        const ['a', 'b', 'c'],
        (_) => EditRecipe.neutral,
        onProgress: progress.add,
      );

      expect(result.exported, 3);
      final dones = [for (final p in progress) p.done];
      expect(dones, List<int>.of(dones)..sort(), reason: 'done regressed');
      expect(dones.last, 3);
      expect(progress.last.label, '3/3');
    });

    test('cancel mid-batch stops dequeuing further items', () async {
      final ran = <String>[];
      final cancel = BatchCancel();
      final exporter = GalleryExporter(
        FakeGallerySource(),
        maxConcurrent: 1,
        item: (id, recipe) async {
          ran.add(id);
          if (ran.length == 3) cancel.request();
          return true;
        },
      );

      final result = await exporter.exportBatch(
        const ['a', 'b', 'c', 'd', 'e'],
        (_) => EditRecipe.neutral,
        cancel: cancel,
      );

      expect(ran, const ['a', 'b', 'c']);
      expect(result.exported, 3);
      expect(result.cancelled, isTrue);
    });

    test('a failing item is collected without aborting the batch', () async {
      final exporter = GalleryExporter(
        FakeGallerySource(),
        item: (id, recipe) async => id != 'c',
      );

      final result = await exporter.exportBatch(
        const ['a', 'b', 'c', 'd'],
        (_) => EditRecipe.neutral,
      );

      expect(result.exported, 3);
      expect(result.failed, const ['c']);
    });
  });

  group('export settings', () {
    test('fullExportOptions maps ExportSettings onto engine options', () {
      const settings = ExportSettings(
        quality: 71,
        maxDim: 0,
        colorSpace: 1,
        ultraHdr: true,
        hdrHeadroom: 3.0,
      );

      final opts = fullExportOptions(settings);

      expect(opts.quality, 71);
      expect(opts.maxDim, isNull, reason: 'maxDim 0 = original resolution');
      expect(opts.colorSpace, 1);
      expect(opts.ultraHdr, isTrue);
      expect(opts.hdrHeadroom, 3.0);
    });

    test('fullExportOptions passes a non-zero maxDim through', () {
      final opts = fullExportOptions(
        const ExportSettings(quality: 85, maxDim: 2048),
      );

      expect(opts.quality, 85);
      expect(opts.maxDim, 2048);
    });

    test('a bare GalleryExporter carries the default settings', () {
      final exporter = GalleryExporter(FakeGallerySource());

      expect(exporter.settings, const ExportSettings());
    });

    test('galleryExporterProvider restores persisted settings', () async {
      SharedPreferences.setMockInitialValues({
        'export_quality': 71,
        'export_max_dim': 2048,
        'export_color_space': 1,
        'export_ultra_hdr': true,
        'export_hdr_headroom': 3.5,
      });
      final container = ProviderContainer(
        overrides: [gallerySourceProvider.overrideWithValue(_twoPhotos())],
      );
      addTearDown(container.dispose);

      container.read(galleryExporterProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final settings = container.read(galleryExporterProvider).settings;
      expect(settings.quality, 71);
      expect(settings.maxDim, 2048);
      expect(settings.colorSpace, 1);
      expect(settings.ultraHdr, isTrue);
      expect(settings.hdrHeadroom, 3.5);
    });
  });

  group('export specs', () {
    test('carry adjustment layers and optics into the full pipeline', () {
      const layer = AdjustmentLayer(maskKind: MaskKind.radial, exposure: 0.4);
      final recipe = EditRecipe.neutral.copyWith(
        layers: const [layer],
        clarity: 0.3,
        defringePurpleAmount: 0.6,
        straighten: 2.5,
      );

      final specs = specsFor(recipe);

      expect(specs.layers, recipe.layers);
      expect(specs.layers.single.exposure, 0.4);
      // Optics/geometry ride the same call the batch uses (specs have no ==).
      expect(specs.optics.defringePurpleAmount, 0.6);
      expect(specs.geometry.straighten, 2.5);
      expect(specs.spatial.clarity, 0.3);
    });
  });

  group('gallery selection bar', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [gallerySourceProvider.overrideWithValue(_twoPhotos())],
      );
    });
    tearDown(() => container.dispose());

    Future<void> pumpGallery(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GalleryScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Copy edits is enabled only for exactly one selection', (
      tester,
    ) async {
      container.read(recipeStoreProvider.notifier).put(
        originalEntryId('a'),
        EditRecipe.neutral.copyWith(exposure: 1.5),
      );

      await pumpGallery(tester);
      await tester.longPress(find.byType(Image).at(0));
      await tester.pumpAndSettle();

      TextButton copyButton() =>
          tester.widget<TextButton>(find.byKey(const Key('copy-edits-action')));
      // Exactly one photo selected -> enabled.
      expect(copyButton().onPressed, isNotNull);

      // Two selected -> disabled.
      await tester.tap(find.byType(Image).at(1));
      await tester.pumpAndSettle();
      expect(copyButton().onPressed, isNull);

      // Back to one -> enabled, and tapping copies that photo's recipe.
      await tester.tap(find.byType(Image).at(1));
      await tester.pumpAndSettle();
      expect(copyButton().onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('copy-edits-action')));
      await tester.pumpAndSettle();

      expect(container.read(settingsClipboardProvider)!.exposure, 1.5);
      // Selection survives the copy so Paste can follow immediately.
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('Sync edits is enabled for 2+ selections and syncs master recipe to targets', (
      tester,
    ) async {
      container.read(recipeStoreProvider.notifier).put(
        originalEntryId('a'),
        EditRecipe.neutral.copyWith(exposure: 1.5, contrast: 0.5),
      );

      await pumpGallery(tester);
      await tester.longPress(find.byType(Image).at(0));
      await tester.pumpAndSettle();

      TextButton syncButton() =>
          tester.widget<TextButton>(find.byKey(const Key('sync-edits-action')));
      expect(syncButton().onPressed, isNull);

      await tester.tap(find.byType(Image).at(1));
      await tester.pumpAndSettle();
      expect(syncButton().onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('sync-edits-action')));
      await tester.pumpAndSettle();

      expect(container.read(recipeStoreProvider)[originalEntryId('b')]!.exposure, 1.5);
      expect(container.read(recipeStoreProvider)[originalEntryId('b')]!.contrast, 0.5);
    });

    testWidgets('batch export shows rings, a running count and completes', (
      tester,
    ) async {
      final gate = Completer<void>();
      container = ProviderContainer(
        overrides: [
          gallerySourceProvider.overrideWithValue(_twoPhotos()),
          galleryExporterProvider.overrideWithValue(
            GalleryExporter(
              FakeGallerySource(),
              maxConcurrent: 1,
              item: (id, recipe) async {
                await gate.future;
                return true;
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await pumpGallery(tester);
      await tester.longPress(find.byType(Image).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Image).at(1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export'));
      // Indeterminate rings animate forever — never pumpAndSettle while they
      // are on screen.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.byKey(const Key('export-ring-a')), findsOneWidget);
      expect(find.text('0/2'), findsOneWidget);
      expect(find.byKey(const Key('export-cancel')), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('export-done-a')), findsOneWidget);
      expect(find.byKey(const Key('export-done-b')), findsOneWidget);
      expect(find.byKey(const Key('export-ring-a')), findsNothing);
      expect(find.text('Exported 2 photo(s) to your gallery'), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget); // selection cleared
    });

    testWidgets('cancel stops the remaining queue', (tester) async {
      final gate = Completer<void>();
      container = ProviderContainer(
        overrides: [
          gallerySourceProvider.overrideWithValue(_twoPhotos()),
          galleryExporterProvider.overrideWithValue(
            GalleryExporter(
              FakeGallerySource(),
              maxConcurrent: 1,
              item: (id, recipe) async {
                await gate.future;
                return true;
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await pumpGallery(tester);
      await tester.longPress(find.byType(Image).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Image).at(1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      await tester.tap(find.byKey(const Key('export-cancel')));
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('export-cancel')), findsNothing);
      expect(find.textContaining('Export cancelled'), findsOneWidget);
      expect(find.byKey(const Key('export-done-a')), findsOneWidget);
      expect(find.byKey(const Key('export-done-b')), findsNothing);
    });
  });

  group('desktop batch destination (#104)', () {
    // Real-pipeline tests need the host debug dylib; CI runs `flutter test`
    // before `cargo build`, so the dylib may be absent (fresh runner, cold
    // rust-cache) — those tests skip with a visible reason instead of
    // failing, same spirit as c2pa_service_test's mock fallback.
    final rustDylib =
        '${Directory.current.path}/rust/target/debug/librust_lib_aperturex.so';
    final rustAvailable = File(rustDylib).existsSync();

    setUpAll(() async {
      try {
        if (rustAvailable) {
          await RustLib.init(externalLibrary: ExternalLibrary.open(rustDylib));
        }
      } catch (_) {
        // Rust not available in this environment; tests requiring it skip individually.
      }
    });

    /// A real 8×6 JPEG — the real pipeline decodes JPEG, not the PNG fixture.
    Uint8List realJpeg() {
      final image = img.Image(width: 8, height: 6);
      for (var y = 0; y < 6; y++) {
        for (var x = 0; x < 8; x++) {
          image.setPixelRgb(x, y, x * 30 % 256, y * 40 % 256, (x + y) * 25 % 256);
        }
      }
      return img.encodeJpg(image, quality: 85);
    }

    test('picks the destination folder exactly once for the whole batch', () async {
      var picks = 0;
      var items = 0;
      final exporter = GalleryExporter(
        FakeGallerySource(),
        maxConcurrent: 1,
        isDesktop: true,
        pickDirectory: () async {
          picks++;
          return '/tmp/never-written-because-item-seam';
        },
        item: (id, recipe) async {
          items++;
          return true;
        },
      );

      final result = await exporter.exportBatch(
        const ['a', 'b', 'c'],
        (_) => EditRecipe.neutral,
      );

      expect(picks, 1,
          reason: 'the folder dialog belongs to the batch, not per item');
      expect(items, 3);
      expect(result.exported, 3);
      expect(result.cancelled, isFalse);
    });

    test('a cancelled folder picker aborts before any item runs', () async {
      var picks = 0;
      var items = 0;
      final exporter = GalleryExporter(
        FakeGallerySource(),
        isDesktop: true,
        pickDirectory: () async {
          picks++;
          return null; // user hit Cancel
        },
        item: (id, recipe) async {
          items++;
          return true;
        },
      );

      final result = await exporter.exportBatch(
        const ['a', 'b'],
        (_) => EditRecipe.neutral,
      );

      expect(picks, 1);
      expect(items, 0, reason: 'no decode/render work after a cancel');
      expect(result.exported, 0);
      expect(result.failed, isEmpty, reason: 'a cancel is not a failure');
      expect(result.cancelled, isTrue);
    });

    test('mobile batches never open the folder picker', () async {
      var picks = 0;
      final exporter = GalleryExporter(
        FakeGallerySource(),
        isDesktop: false,
        pickDirectory: () async {
          picks++;
          return '/tmp/should-not-be-asked';
        },
        item: (id, recipe) async => true,
      );

      final result = await exporter.exportBatch(
        const ['a'],
        (_) => EditRecipe.neutral,
      );

      expect(picks, 0, reason: 'mobile keeps the Photos/DCIM destination');
      expect(result.exported, 1);
    });

    test('desktop batch writes aperturex_<id>.jpg into the picked folder', () async {
      final dest = await Directory.systemTemp.createTemp('batch_dest_');
      addTearDown(() => dest.delete(recursive: true));
      final sink = _RecordingSink();

      final exporter = GalleryExporter(
        FakeGallerySource(
          images: {'a': realJpeg(), 'b': realJpeg()},
          assets: const [
            GalleryAsset(id: 'a', width: 8, height: 6),
            GalleryAsset(id: 'b', width: 8, height: 6),
          ],
        ),
        isDesktop: true,
        pickDirectory: () async => dest.path,
        sink: sink,
      );

      final progress = <BatchExportProgress>[];
      final result = await exporter.exportBatch(
        const ['a', 'b'],
        (_) => EditRecipe.neutral,
        onProgress: progress.add,
      );

      expect(result.exported, 2, reason: 'real Rust pipeline must succeed');
      expect(result.failed, isEmpty);
      expect(sink.hasAccessCalls, 0,
          reason: 'desktop writes files — reaching gal would throw here');
      expect(sink.byteSaves, isEmpty);

      for (final id in ['a', 'b']) {
        final file = File('${dest.path}${Platform.pathSeparator}aperturex_$id.jpg');
        expect(file.existsSync(), isTrue, reason: 'missing $id output');
        final bytes = file.readAsBytesSync();
        expect(bytes.length, greaterThan(100));
        expect([bytes[0], bytes[1]], [0xFF, 0xD8], reason: 'JPEG magic');
      }
      expect(dest.listSync(), hasLength(2), reason: 'exactly the two exports');
      expect(progress.where((p) => p.started).length, 2);
      expect(progress.where((p) => !p.started).length, 2);
    }, skip: rustAvailable
        ? false
        : 'rust/target/debug dylib not built in this environment');

    test('mobile batch routes real exports through the gallery sink', () async {
      final sink = _RecordingSink();
      final exporter = GalleryExporter(
        FakeGallerySource(
          images: {'a': realJpeg()},
          assets: const [GalleryAsset(id: 'a', width: 8, height: 6)],
        ),
        isDesktop: false,
        sink: sink,
      );

      final result = await exporter.exportBatch(
        const ['a'],
        (_) => EditRecipe.neutral,
      );

      expect(result.exported, 1);
      expect(sink.byteSaves, hasLength(1),
          reason: 'mobile keeps gallery_export\'s original gal flow '
              '(no per-item access check — that lives in the editor)');
      expect(sink.byteSaves.single.$2, 'aperturex_a',
          reason: 'gal name without extension (gal doc contract)');
      expect(sink.byteSaves.single.$1[0], 0xFF);
      expect(sink.byteSaves.single.$1[1], 0xD8);
    }, skip: rustAvailable
        ? false
        : 'rust/target/debug dylib not built in this environment');
  });
}
