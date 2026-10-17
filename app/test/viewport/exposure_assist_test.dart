import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/viewport/exposure_assist.dart';

void main() {
  group('ExposureAssist', () {
    test('defaults to off with standard cine thresholds', () {
      final container = ProviderContainer();
      final state = container.read(exposureAssistProvider);

      expect(state.mode, ExposureAssistMode.off);
      expect(state.isActive, isFalse);
      expect(state.zebraHigh, 0.98);
      expect(state.zebraLow, 0.02);
    });

    test('cycleMode traverses off -> zebras -> falseColor -> off', () {
      final container = ProviderContainer();
      final notifier = container.read(exposureAssistProvider.notifier);

      expect(container.read(exposureAssistProvider).mode, ExposureAssistMode.off);

      notifier.cycleMode();
      expect(container.read(exposureAssistProvider).mode, ExposureAssistMode.zebras);
      expect(container.read(exposureAssistProvider).isActive, isTrue);

      notifier.cycleMode();
      expect(container.read(exposureAssistProvider).mode, ExposureAssistMode.falseColor);
      expect(container.read(exposureAssistProvider).isActive, isTrue);

      notifier.cycleMode();
      expect(container.read(exposureAssistProvider).mode, ExposureAssistMode.off);
      expect(container.read(exposureAssistProvider).isActive, isFalse);
    });

    test('setMode directly sets the exposure inspection mode', () {
      final container = ProviderContainer();
      final notifier = container.read(exposureAssistProvider.notifier);

      notifier.setMode(ExposureAssistMode.falseColor);
      expect(container.read(exposureAssistProvider).mode, ExposureAssistMode.falseColor);
      expect(container.read(exposureAssistProvider).isActive, isTrue);

      notifier.setMode(ExposureAssistMode.off);
      expect(container.read(exposureAssistProvider).mode, ExposureAssistMode.off);
      expect(container.read(exposureAssistProvider).isActive, isFalse);
    });

    test('setThresholds clamps within 0.0 .. 1.0', () {
      final container = ProviderContainer();
      final notifier = container.read(exposureAssistProvider.notifier);

      notifier.setThresholds(high: 1.05, low: -0.1);
      expect(container.read(exposureAssistProvider).zebraHigh, 1.0);
      expect(container.read(exposureAssistProvider).zebraLow, 0.0);

      notifier.setThresholds(high: 0.90, low: 0.05);
      expect(container.read(exposureAssistProvider).zebraHigh, 0.90);
      expect(container.read(exposureAssistProvider).zebraLow, 0.05);
    });

    test('reset restores default inspection state', () {
      final container = ProviderContainer();
      final notifier = container.read(exposureAssistProvider.notifier);

      notifier.setMode(ExposureAssistMode.zebras);
      notifier.setThresholds(high: 0.95, low: 0.05);
      expect(container.read(exposureAssistProvider).isActive, isTrue);

      notifier.reset();
      expect(container.read(exposureAssistProvider).mode, ExposureAssistMode.off);
      expect(container.read(exposureAssistProvider).zebraHigh, 0.98);
      expect(container.read(exposureAssistProvider).zebraLow, 0.02);
    });
  });
}
