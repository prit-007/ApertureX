import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/color/histogram_view.dart';
import 'package:aperturex/engine/engine.dart';
import 'package:aperturex/viewport/exposure_assist.dart';

Histogram _histogram() => Histogram(
  r: Uint32List(256)..[200] = 10,
  g: Uint32List(256)..[128] = 20,
  b: Uint32List(256)..[40] = 7,
  luma: Uint32List(256)..[100] = 15,
);

void main() {
  test('histogramProvider starts empty', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(histogramProvider), isNull);
    container.read(histogramProvider.notifier).publish(_histogram());
    expect(container.read(histogramProvider), isNotNull);
  });

  testWidgets('HistogramView renders and toggles clipping warnings', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: HistogramView(histogram: _histogram())),
        ),
      ),
    );
    expect(find.byType(HistogramView), findsOneWidget);
    expect(find.byTooltip('Shadow Clipping Warning (Blue)'), findsOneWidget);
    expect(find.byTooltip('Highlight Clipping Warning (Red)'), findsOneWidget);

    await tester.tap(find.byTooltip('Highlight Clipping Warning (Red)'));
    await tester.pumpAndSettle();
    expect(container.read(exposureAssistProvider).mode, ExposureAssistMode.zebras);
  });
}
