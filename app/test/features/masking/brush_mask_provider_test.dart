import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aperturex/features/masking/brush_mask_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BrushMaskSettings', () {
    test('defaults have showRubyMask true, rubyColor red, rubyOpacity 0.5', () {
      const settings = BrushMaskSettings();
      expect(settings.showRubyMask, isTrue);
      expect(settings.rubyColor, RubyMaskColor.red);
      expect(settings.rubyOpacity, 0.5);
    });

    test('copyWith overrides rubyColor and rubyOpacity', () {
      const settings = BrushMaskSettings();
      final updated = settings.copyWith(
        rubyColor: RubyMaskColor.green,
        rubyOpacity: 0.25,
      );
      expect(updated.rubyColor, RubyMaskColor.green);
      expect(updated.rubyOpacity, 0.25);
      // Unchanged fields are preserved
      expect(updated.showRubyMask, settings.showRubyMask);
      expect(updated.radius, settings.radius);
    });

    test('equality and hashCode account for rubyColor and rubyOpacity', () {
      const a = BrushMaskSettings(rubyColor: RubyMaskColor.red, rubyOpacity: 0.5);
      const b = BrushMaskSettings(rubyColor: RubyMaskColor.red, rubyOpacity: 0.5);
      const c = BrushMaskSettings(rubyColor: RubyMaskColor.blue, rubyOpacity: 0.5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('BrushMaskNotifier toggles ruby color and opacity', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(brushMaskProvider.notifier);
      notifier.setRubyColor(RubyMaskColor.white);
      notifier.setRubyOpacity(0.75);

      expect(container.read(brushMaskProvider).rubyColor, RubyMaskColor.white);
      expect(container.read(brushMaskProvider).rubyOpacity, 0.75);
    });
  });
}
