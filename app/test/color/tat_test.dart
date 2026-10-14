import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/color/tat.dart';

void main() {
  group('nearestHslBand', () {
    test('maps the primary hues to their bands', () {
      expect(nearestHslBand(0.0), 0); // red
      expect(nearestHslBand(120 / 360), 3); // green
      expect(nearestHslBand(240 / 360), 5); // blue
      expect(nearestHslBand(0.98), 0); // near red, wrap-aware
    });
  });

  group('hueOf', () {
    test('returns the expected hue for primaries', () {
      expect(hueOf(255, 0, 0), closeTo(0, 1e-6));
      expect(hueOf(0, 255, 0), closeTo(1 / 3, 1e-3));
      expect(hueOf(0, 0, 255), closeTo(2 / 3, 1e-3));
    });

    test('greys have no hue', () {
      expect(hueOf(128, 128, 128), 0);
    });
  });

  test('the TAT component cycles hue -> saturation -> luminance', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(tatComponentProvider.notifier);

    expect(container.read(tatComponentProvider), 1); // saturation default
    notifier.cycle();
    expect(container.read(tatComponentProvider), 2);
    notifier.cycle();
    expect(container.read(tatComponentProvider), 0);
    notifier.cycle();
    expect(container.read(tatComponentProvider), 1);
  });
}
