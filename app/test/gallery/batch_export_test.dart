import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:aperturex/settings/export_settings.dart';

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
      await tester.pump(const Duration(milliseconds: 50));

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
      await tester.pump(const Duration(milliseconds: 50));

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
}
