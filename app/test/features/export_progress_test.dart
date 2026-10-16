import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/features/editor/export_progress.dart';
import 'package:aperturex/gallery/gallery_export.dart';
import 'package:aperturex/gallery/gallery_source.dart';

void main() {
  group('exportOverall', () {
    test('phase floors never jump backwards', () {
      final floors = ExportPhase.values
          .map((p) => exportOverall(p, 0))
          .toList();
      for (var i = 1; i < floors.length; i++) {
        expect(
          floors[i],
          greaterThanOrEqualTo(floors[i - 1]),
          reason:
              '${ExportPhase.values[i]} floor must not go below the previous',
        );
      }
    });

    test('rendering maps the engine fraction 0..1 into its band', () {
      expect(exportOverall(ExportPhase.rendering, 0), closeTo(0.15, 1e-9));
      expect(exportOverall(ExportPhase.rendering, 0.5), closeTo(0.55, 1e-9));
      expect(exportOverall(ExportPhase.rendering, 1), closeTo(0.95, 1e-9));
    });

    test('an out-of-range render fraction is clamped', () {
      expect(exportOverall(ExportPhase.rendering, -3), closeTo(0.15, 1e-9));
      expect(exportOverall(ExportPhase.rendering, 7), closeTo(0.95, 1e-9));
    });

    test('every phase has a human label', () {
      for (final phase in ExportPhase.values) {
        expect(phaseLabel(phase), isNotEmpty);
      }
    });
  });

  group('ExportProgressPoller', () {
    test('reads the token on an interval and forwards fractions', () {
      fakeAsync((async) {
        var reads = 0;
        final seen = <double>[];
        final poller = ExportProgressPoller(
          token: 7,
          read: (token) async {
            expect(token, 7);
            reads++;
            return reads * 0.25; // 0.25, 0.50, 0.75, 1.00
          },
          onValue: seen.add,
        )..start();

        async.elapse(const Duration(milliseconds: 80));
        expect(seen, [0.25]);
        async.elapse(const Duration(milliseconds: 160));
        expect(seen, [0.25, 0.5, 0.75]);

        poller.stop();
        async.elapse(const Duration(milliseconds: 400));
        expect(
          seen,
          [0.25, 0.5, 0.75],
          reason: 'stop() must halt further reads',
        );
        expect(reads, 3);
      });
    });

    test('a token of 0 never starts a timer', () {
      fakeAsync((async) {
        var reads = 0;
        final poller = ExportProgressPoller(
          token: 0,
          read: (token) async {
            reads++;
            return 1.0;
          },
          onValue: (_) {},
        )..start();
        async.elapse(const Duration(seconds: 5));
        expect(reads, 0, reason: 'token 0 has no progress cell to poll');
        poller.stop();
      });
    });

    test('values after stop() are dropped even if a read was in flight', () {
      fakeAsync((async) {
        final seen = <double>[];
        final pending = Completer<double>();
        final poller = ExportProgressPoller(
          token: 1,
          read: (token) => pending.future,
          onValue: seen.add,
        )..start();

        // The timer fires and kicks off a read that stays pending.
        async.elapse(const Duration(milliseconds: 80));
        poller.stop();
        // The read completes only after stop() — must be discarded.
        pending.complete(0.9);
        async.elapse(Duration.zero); // drain the pending microtask

        expect(seen, isEmpty, reason: 'a stopped poller must not deliver');
      });
    });
  });

  group('BatchProgressAggregator', () {
    BatchProgressAggregator two() => BatchProgressAggregator(total: 2);

    test('starts empty at zero', () {
      expect(two().overall, 0);
    });

    test('in-flight fractions move the bar between item boundaries', () {
      final agg = two()..start('a');
      expect(agg.overall, 0);
      agg.fraction('a', 0.5);
      expect(agg.overall, closeTo(0.25, 1e-9));
      agg.finish('a');
      expect(agg.overall, closeTo(0.5, 1e-9));
    });

    test('two concurrent items sum their fractions', () {
      final agg = two()
        ..start('a')
        ..start('b');
      agg
        ..fraction('a', 0.5)
        ..fraction('b', 0.5);
      expect(agg.overall, closeTo(0.5, 1e-9));
      agg
        ..finish('a')
        ..finish('b');
      expect(agg.overall, 1);
    });

    test('an unknown id finishing still counts toward done', () {
      final agg = two()..finish('ghost');
      expect(agg.done, 1);
      expect(agg.overall, closeTo(0.5, 1e-9));
    });

    test('an empty batch reports complete', () {
      expect(BatchProgressAggregator(total: 0).overall, 1);
    });

    test('fractions are clamped to 0..1', () {
      final agg = two()..start('a');
      agg.fraction('a', 5);
      expect(agg.overall, closeTo(0.5, 1e-9));
      agg.fraction('a', -2);
      expect(agg.overall, 0);
    });

    test('exportBatch is safe with no onItemProgress (item seam)', () async {
      final exporter = GalleryExporter(
        FakeGallerySource(),
        item: (id, recipe) async => true,
      );
      final result = await exporter.exportBatch(
        ['a', 'b'],
        (_) => EditRecipe.neutral,
      );
      expect(result.exported, 2);
      expect(result.failed, isEmpty);
    });
  });
}
