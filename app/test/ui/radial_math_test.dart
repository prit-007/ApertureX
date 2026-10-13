import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/ui/snapseed/snapseed_shell.dart';

void main() {
  group('nearestRadialItem', () {
    const center = Offset(200, 200);
    const r = 84.0;

    test('points to the top item when the pointer is above', () {
      expect(nearestRadialItem(center, center + const Offset(0, -r), 3, r), 0);
    });

    test('picks the clockwise neighbour for a right-side pointer', () {
      // Three items at -90°, 30°, 150°. Right side ≈ the 30° item (index 1).
      expect(nearestRadialItem(center, center + const Offset(r, 0.4 * r), 3, r), 1);
    });

    test('picks the last item for a lower-left pointer', () {
      // -90 + 240 = 150° → lower-left (index 2).
      expect(nearestRadialItem(center, center + const Offset(-0.7 * r, 0.7 * r), 3, r), 2);
    });
  });
}
