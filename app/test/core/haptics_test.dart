import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/core/haptics.dart';

void main() {
  group('hapticFor', () {
    test('landing exactly on neutral fires neutralCross', () {
      expect(hapticFor(0.3, 0.0, -1, 1), HapticTick.neutralCross);
    });

    test('crossing neutral (+ to -) fires neutralCross', () {
      expect(hapticFor(0.3, -0.1, -1, 1), HapticTick.neutralCross);
    });

    test('crossing neutral (- to +) fires neutralCross', () {
      expect(hapticFor(-0.2, 0.4, -1, 1), HapticTick.neutralCross);
    });

    test('an ordinary move fires nothing', () {
      expect(hapticFor(0.3, 0.6, -1, 1), HapticTick.none);
      expect(hapticFor(0.0, 0.5, -1, 1), HapticTick.none);
      expect(hapticFor(0.0, 0.0, -1, 1), HapticTick.none);
    });

    test('reaching an end-stop fires limit', () {
      expect(hapticFor(0.9, 1.0, -1, 1), HapticTick.limit);
      expect(hapticFor(-0.9, -1.0, -1, 1), HapticTick.limit);
    });

    test('resting at an end-stop does not repeat', () {
      expect(hapticFor(1.0, 1.0, -1, 1), HapticTick.none);
    });

    test('exposure EV range is respected', () {
      expect(hapticFor(3.5, 4.0, -4, 4), HapticTick.limit);
      expect(hapticFor(1.0, 0.0, -4, 4), HapticTick.neutralCross);
    });
  });

  group('hapticGradientIntensity', () {
    test('is silent inside the safe zone', () {
      expect(hapticGradientIntensity(0, -4, 4), 0);
      expect(hapticGradientIntensity(3.0, -4, 4), 0); // at the safe boundary
      expect(hapticGradientIntensity(-3.0, -4, 4), 0);
    });

    test('pulses only near the limits and peaks at the end-stop', () {
      expect(hapticGradientIntensity(3.5, -4, 4), closeTo(0.5, 1e-9));
      expect(hapticGradientIntensity(4.0, -4, 4), 1);
      expect(hapticGradientIntensity(-4.0, -4, 4), 1);
      expect(hapticGradientIntensity(3.9, -4, 4), lessThan(1));
    });

    test('intensity rises monotonically toward the limit', () {
      final values = [3.05, 3.2, 3.5, 3.8, 4.0];
      for (var i = 1; i < values.length; i++) {
        expect(
          hapticGradientIntensity(values[i], -4, 4),
          greaterThan(hapticGradientIntensity(values[i - 1], -4, 4)),
        );
      }
    });

    test('works for unipolar ranges too', () {
      expect(hapticGradientIntensity(0.5, 0, 1), 0);
      expect(hapticGradientIntensity(0.9, 0, 1), greaterThan(0));
      expect(hapticGradientIntensity(1.0, 0, 1), 1);
    });

    test('degenerate ranges never pulse', () {
      expect(hapticGradientIntensity(1, 1, 1), 0);
      expect(hapticGradientIntensity(1, 5, 1), 0);
      expect(hapticGradientIntensity(1, -1, 1, safeFraction: 1), 0);
    });
  });

  group('hapticGradientInterval', () {
    test('gets faster as intensity rises', () {
      expect(
        hapticGradientInterval(1),
        lessThan(hapticGradientInterval(0.5)),
      );
      expect(hapticGradientInterval(0.5), lessThan(hapticGradientInterval(0.01)));
    });

    test('stays within 45..140 ms', () {
      expect(hapticGradientInterval(0).inMicroseconds, 140000);
      expect(hapticGradientInterval(1).inMicroseconds, 45000);
    });
  });

  group('HapticGradientPacer', () {
    test('never fires while safely inside the range', () {
      final pacer = HapticGradientPacer();
      for (var i = 0; i < 50; i++) {
        expect(
          pacer.tick(const Duration(milliseconds: 50), value: 1, min: -4, max: 4),
          isFalse,
        );
      }
    });

    test('fires at the interval, then faster as intensity grows', () {
      final pacer = HapticGradientPacer();
      // intensity 0.5 -> interval ~92.5ms
      expect(
        pacer.tick(const Duration(milliseconds: 60), value: 3.5, min: -4, max: 4),
        isFalse,
      );
      expect(
        pacer.tick(const Duration(milliseconds: 40), value: 3.5, min: -4, max: 4),
        isTrue,
      );
      // Interval restarts after a fire.
      expect(
        pacer.tick(const Duration(milliseconds: 50), value: 3.5, min: -4, max: 4),
        isFalse,
      );
      expect(
        pacer.tick(const Duration(milliseconds: 50), value: 3.5, min: -4, max: 4),
        isTrue,
      );
    });

    test('re-entering the safe zone drops the accumulation', () {
      final pacer = HapticGradientPacer();
      // 60 ms at intensity 0.5 (interval 92.5 ms) — not enough yet.
      expect(
        pacer.tick(const Duration(milliseconds: 60), value: 3.5, min: -4, max: 4),
        isFalse,
      );
      // Back to neutral: a long pause accrues nothing.
      pacer.tick(const Duration(milliseconds: 1000), value: 0, min: -4, max: 4);
      expect(pacer.intensity, 0);
      expect(
        pacer.tick(const Duration(milliseconds: 50), value: 3.5, min: -4, max: 4),
        isFalse,
      );
    });

    test('reset clears the accumulated time and intensity', () {
      final pacer = HapticGradientPacer();
      pacer.tick(const Duration(milliseconds: 100), value: 4, min: -4, max: 4);
      pacer.reset();
      expect(pacer.intensity, 0);
      expect(
        pacer.tick(const Duration(milliseconds: 10), value: 4, min: -4, max: 4),
        isFalse,
      );
    });
  });
}
