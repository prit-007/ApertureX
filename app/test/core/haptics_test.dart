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
}
