import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/ui/common/parameter_control.dart';
import 'package:aperturex/viewport/mask_peek.dart';

Widget _harness(ProviderContainer container, Parameter parameter) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(body: ParameterControl(parameter: parameter)),
      ),
    );

void main() {
  test('only detail parameters auto-peek the mask view', () {
    expect(maskPeekParameters, contains(Parameter.sharpen));
    expect(maskPeekParameters, contains(Parameter.sharpenRadius));
    expect(maskPeekParameters, contains(Parameter.sharpenDetail));
    expect(maskPeekParameters, contains(Parameter.sharpenMasking));
    expect(maskPeekParameters, contains(Parameter.denoiseLuma));
    expect(maskPeekParameters, contains(Parameter.denoiseChroma));
    expect(maskPeekParameters, contains(Parameter.clarity));
    expect(maskPeekParameters, contains(Parameter.texture));
    expect(maskPeekParameters, contains(Parameter.dehaze));

    expect(maskPeekParameters, isNot(contains(Parameter.exposure)));
    expect(maskPeekParameters, isNot(contains(Parameter.saturation)));
  });

  group('lut.frag float uniforms', () {
    // The painter writes uniforms by index; these offsets are the contract.
    test('match the setFloat indices used by the canvas painter', () {
      final source = File('shaders/lut.frag').readAsStringSync();
      final pattern = RegExp(r'^uniform\s+(vec2|float|sampler2D)\s+(\w+)', multiLine: true);
      var floatIndex = 0;
      final offsets = <String, int>{};
      for (final match in pattern.allMatches(source)) {
        final (type, name) = (match.group(1)!, match.group(2)!);
        if (type == 'sampler2D') continue;
        offsets[name] = floatIndex;
        floatIndex += type == 'vec2' ? 2 : 1;
      }

      expect(offsets['uSize'], 0);
      expect(offsets['uLutSize'], 2);
      expect(offsets['uMaskBlend'], 3);
      expect(offsets['uSrcW'], 4);
      expect(offsets['uSrcH'], 5);
    });
  });

  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  testWidgets('dragging a detail slider peeks the mask and releases it', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(container, Parameter.sharpen));
    expect(container.read(maskPeekProvider), isFalse);

    final rect = tester.getRect(find.byKey(const Key('param-track-sharpen')));
    final gesture = await tester.startGesture(rect.center);
    await tester.pump();
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(container.read(maskPeekProvider), isTrue);

    await gesture.up();
    await tester.pump();
    expect(container.read(maskPeekProvider), isFalse);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('ordinary parameters never peek', (tester) async {
    await tester.pumpWidget(_harness(container, Parameter.exposure));

    final rect = tester.getRect(find.byKey(const Key('param-track-exposure')));
    final gesture = await tester.startGesture(rect.center);
    await tester.pump();
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(container.read(maskPeekProvider), isFalse);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(maskPeekProvider), isFalse);
  });
}
