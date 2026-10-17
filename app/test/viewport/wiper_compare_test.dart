import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/viewport/wiper_compare.dart';

void main() {
  group('WiperCompare state & notifier', () {
    test('initial state defaults to inactive, center position, and vertical orientation', () {
      final container = ProviderContainer();
      final state = container.read(wiperCompareProvider);

      expect(state.isActive, isFalse);
      expect(state.position, 0.50);
      expect(state.orientation, WiperOrientation.vertical);
    });

    test('toggle flips isActive state', () {
      final container = ProviderContainer();
      final notifier = container.read(wiperCompareProvider.notifier);

      notifier.toggle();
      expect(container.read(wiperCompareProvider).isActive, isTrue);

      notifier.toggle();
      expect(container.read(wiperCompareProvider).isActive, isFalse);
    });

    test('setPosition clamps to 0.0 .. 1.0', () {
      final container = ProviderContainer();
      final notifier = container.read(wiperCompareProvider.notifier);

      notifier.setPosition(0.75);
      expect(container.read(wiperCompareProvider).position, 0.75);

      notifier.setPosition(1.5);
      expect(container.read(wiperCompareProvider).position, 1.0);

      notifier.setPosition(-0.2);
      expect(container.read(wiperCompareProvider).position, 0.0);
    });

    test('resetPosition snaps position back to center 0.50', () {
      final container = ProviderContainer();
      final notifier = container.read(wiperCompareProvider.notifier);

      notifier.setPosition(0.88);
      notifier.resetPosition();
      expect(container.read(wiperCompareProvider).position, 0.50);
    });

    test('toggleOrientation flips between vertical and horizontal', () {
      final container = ProviderContainer();
      final notifier = container.read(wiperCompareProvider.notifier);

      expect(container.read(wiperCompareProvider).orientation, WiperOrientation.vertical);
      notifier.toggleOrientation();
      expect(container.read(wiperCompareProvider).orientation, WiperOrientation.horizontal);
      notifier.toggleOrientation();
      expect(container.read(wiperCompareProvider).orientation, WiperOrientation.vertical);
    });
  });
}
