import 'package:aperturex/ui/common/parameter_slider_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ParameterSliderRow renders label, slider, and formatted value', (tester) async {
    double currentValue = 0.5;
    var resetCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: ParameterSliderRow(
                label: 'Clarity',
                value: currentValue,
                defaultValue: 0.0,
                min: -1.0,
                max: 1.0,
                sliderKey: const Key('test-slider'),
                onChanged: (val) => currentValue = val,
                onReset: () => resetCalled = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Clarity'), findsOneWidget);
    expect(find.byKey(const Key('test-slider')), findsOneWidget);
    expect(find.text('+0.50'), findsOneWidget);

    // Double-tap label triggers reset
    await tester.tap(find.text('Clarity'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Clarity'));
    await tester.pumpAndSettle();

    expect(resetCalled, isTrue);
  });

  testWidgets('ParameterSliderRow fits 320dp viewport without overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: ParameterSliderRow(
              label: 'Very Long Label Name',
              value: 0.75,
              defaultValue: 0.0,
              min: 0.0,
              max: 1.0,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
