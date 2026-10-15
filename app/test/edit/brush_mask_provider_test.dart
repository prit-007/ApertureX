import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/features/masking/brush_mask_provider.dart';

void main() {
  group('BrushMaskProvider', () {
    test('default settings are sensible', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final settings = container.read(brushMaskProvider);
      expect(settings.radius, 0.05);
      expect(settings.feather, 0.25);
      expect(settings.flow, 1.0);
      expect(settings.isEraser, isFalse);
      expect(settings.showRubyMask, isTrue);
    });

    test('updates radius, feather, flow and toggles eraser/ruby', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(brushMaskProvider.notifier);

      notifier.setRadius(0.12);
      expect(container.read(brushMaskProvider).radius, 0.12);

      notifier.setFeather(0.4);
      expect(container.read(brushMaskProvider).feather, 0.4);

      notifier.setFlow(0.8);
      expect(container.read(brushMaskProvider).flow, 0.8);

      notifier.toggleEraser();
      expect(container.read(brushMaskProvider).isEraser, isTrue);

      notifier.toggleRubyMask();
      expect(container.read(brushMaskProvider).showRubyMask, isFalse);
    });
  });
}
