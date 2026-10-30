import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/viewport/split_compare.dart';

void main() {
  group('SplitCompare state & notifier', () {
    test('initial state defaults to disabled and sideBySide orientation', () {
      final container = ProviderContainer();
      final state = container.read(splitCompareProvider);

      expect(state.isEnabled, isFalse);
      expect(state.orientation, SplitOrientation.sideBySide);
    });

    test('toggle flips isEnabled state', () {
      final container = ProviderContainer();
      final notifier = container.read(splitCompareProvider.notifier);

      notifier.toggle();
      expect(container.read(splitCompareProvider).isEnabled, isTrue);

      notifier.toggle();
      expect(container.read(splitCompareProvider).isEnabled, isFalse);
    });

    test('setEnabled explicitly sets enabled flag', () {
      final container = ProviderContainer();
      final notifier = container.read(splitCompareProvider.notifier);

      notifier.setEnabled(true);
      expect(container.read(splitCompareProvider).isEnabled, isTrue);

      notifier.setEnabled(true); // No change
      expect(container.read(splitCompareProvider).isEnabled, isTrue);

      notifier.setEnabled(false);
      expect(container.read(splitCompareProvider).isEnabled, isFalse);
    });

    test('toggleOrientation flips between sideBySide and topBottom', () {
      final container = ProviderContainer();
      final notifier = container.read(splitCompareProvider.notifier);

      expect(container.read(splitCompareProvider).orientation, SplitOrientation.sideBySide);
      notifier.toggleOrientation();
      expect(container.read(splitCompareProvider).orientation, SplitOrientation.topBottom);
      notifier.toggleOrientation();
      expect(container.read(splitCompareProvider).orientation, SplitOrientation.sideBySide);
    });

    test('setOrientation explicitly sets orientation', () {
      final container = ProviderContainer();
      final notifier = container.read(splitCompareProvider.notifier);

      notifier.setOrientation(SplitOrientation.topBottom);
      expect(container.read(splitCompareProvider).orientation, SplitOrientation.topBottom);

      notifier.setOrientation(SplitOrientation.topBottom); // No change
      expect(container.read(splitCompareProvider).orientation, SplitOrientation.topBottom);

      notifier.setOrientation(SplitOrientation.sideBySide);
      expect(container.read(splitCompareProvider).orientation, SplitOrientation.sideBySide);
    });
  });
}
