import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aperturex/features/tether/tether_controller.dart';
import 'package:aperturex/features/tether/tether_model.dart';

void main() {
  group('TetherController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initializes connected with default telemetry and session', () {
      final state = container.read(tetherProvider);
      expect(state.isConnected, isTrue);
      expect(state.telemetry.cameraModel, 'Sony α7R V');
      expect(state.telemetry.batteryPercent, 94);
      expect(state.telemetry.shutterSpeed, '1/250s');
      expect(state.telemetry.aperture, 'f/2.8');
      expect(state.telemetry.iso, 100);
      expect(state.session.sessionName, 'Studio Shoot');
      expect(state.session.totalCaptures, 0);
    });

    test('disconnects and reconnects camera link', () {
      final notifier = container.read(tetherProvider.notifier);

      notifier.disconnect();
      expect(container.read(tetherProvider).isConnected, isFalse);
      expect(container.read(tetherProvider).connectionState, TetherConnectionState.disconnected);

      notifier.connect(model: 'Canon EOS R5');
      expect(container.read(tetherProvider).isConnected, isTrue);
      expect(container.read(tetherProvider).telemetry.cameraModel, 'Canon EOS R5');
    });

    test('triggers remote shutter release, adds capture item, and updates counter', () async {
      final notifier = container.read(tetherProvider.notifier);

      final initialRemaining = container.read(tetherProvider).telemetry.shotsRemaining;

      final capture = await notifier.triggerShutter();

      expect(capture, isNotNull);
      expect(capture!.filename, contains('Studio_Shoot_0001.ARW'));

      final state = container.read(tetherProvider);
      expect(state.session.totalCaptures, 1);
      expect(state.selectedCapture?.id, capture.id);
      expect(state.telemetry.shotsRemaining, initialRemaining - 1);
      expect(state.session.sequenceNumber, 2);

      // Trigger second shutter
      final secondCapture = await notifier.triggerShutter();
      expect(secondCapture!.filename, contains('Studio_Shoot_0002.ARW'));
      expect(container.read(tetherProvider).session.totalCaptures, 2);
    });

    test('updates telemetry parameters on camera changes', () {
      final notifier = container.read(tetherProvider.notifier);

      notifier.updateTelemetry(
        shutterSpeed: '1/1000s',
        aperture: 'f/1.4',
        iso: 400,
        batteryPercent: 88,
      );

      final state = container.read(tetherProvider);
      expect(state.telemetry.shutterSpeed, '1/1000s');
      expect(state.telemetry.aperture, 'f/1.4');
      expect(state.telemetry.iso, 400);
      expect(state.telemetry.batteryPercent, 88);
      expect(state.telemetry.exposureSummary, '1/1000s · f/1.4 · ISO 400');
    });

    test('configures session settings and resets captures', () async {
      final notifier = container.read(tetherProvider.notifier);

      notifier.configureSession(
        sessionName: 'Fashion Week',
        autoApplyRecipe: false,
      );

      expect(container.read(tetherProvider).session.sessionName, 'Fashion Week');
      expect(container.read(tetherProvider).session.autoApplyRecipe, isFalse);

      await notifier.triggerShutter();
      expect(container.read(tetherProvider).session.totalCaptures, 1);

      notifier.clearSession();
      expect(container.read(tetherProvider).session.totalCaptures, 0);
      expect(container.read(tetherProvider).selectedCapture, isNull);
    });
  });
}
