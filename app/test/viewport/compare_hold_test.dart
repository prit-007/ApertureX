import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/viewport/compare_hold.dart';

void main() {
  group('CompareHoldNotifier', () {
    test('defaults to false (not comparing)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(compareHoldProvider), isFalse);
    });

    test('hold sets state to true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(compareHoldProvider.notifier).hold();
      expect(container.read(compareHoldProvider), isTrue);
    });

    test('release sets state to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(compareHoldProvider.notifier);
      notifier.hold();
      expect(container.read(compareHoldProvider), isTrue);

      notifier.release();
      expect(container.read(compareHoldProvider), isFalse);
    });

    test('set is idempotent when value does not change', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var notificationCount = 0;
      container.listen<bool>(compareHoldProvider, (_, _) {
        notificationCount++;
      });

      final notifier = container.read(compareHoldProvider.notifier);
      notifier.set(true);
      expect(notificationCount, 1);

      // Setting same value again should be a no-op
      notifier.set(true);
      expect(notificationCount, 1);

      notifier.set(false);
      expect(notificationCount, 2);

      notifier.set(false);
      expect(notificationCount, 2);
    });
  });
}
