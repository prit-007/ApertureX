import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/settings/export_branding_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ExportBrandingSettings', () {
    test('default state has sensible pro defaults', () {
      const settings = ExportBrandingSettings();
      expect(settings.enableMuseumFrame, isFalse);
      expect(settings.frameThemeIndex, equals(0)); // Studio White
      expect(settings.enableSignature, isFalse);
      expect(settings.signatureOpacity, equals(0.8));
      expect(settings.signatureAnchorIndex, equals(8)); // BottomRight
      expect(settings.signatureColor, equals(0)); // White
      expect(settings.signatureDropShadow, isTrue);
      expect(settings.enableTiledWatermark, isFalse);
      expect(settings.enableFossBadge, isFalse);
      expect(settings.enableC2pa, isTrue);
    });

    test('toRustBrandingSpec maps correctly', () {
      const settings = ExportBrandingSettings(
        enableMuseumFrame: true,
        frameThemeIndex: 1, // Matte Dark
        exifLine1: 'SONY A7III • 35MM',
        exifLine2: '1/250s • f/2.0 • ISO 100',
        enableSignature: true,
        signatureText: '© 2026 Test',
        signatureAnchorIndex: 8,
        signatureColor: 3, // Gold
        signatureInsetPct: 5.0,
        signatureDropShadow: true,
        enableTiledWatermark: true,
        tiledText: 'PROOF',
        tiledOpacity: 0.3,
        enableFossBadge: true,
      );

      final rustSpec = settings.toRustBrandingSpec();
      expect(rustSpec.enableMuseumFrame, isTrue);
      expect(rustSpec.frameTheme, equals(1));
      expect(rustSpec.exifLine1, equals('SONY A7III • 35MM'));
      expect(rustSpec.exifLine2, equals('1/250s • f/2.0 • ISO 100'));
      expect(rustSpec.enableSignature, isTrue);
      expect(rustSpec.signatureText, equals('© 2026 Test'));
      expect(rustSpec.signatureColor, equals(3));
      expect(rustSpec.signatureInsetPct, equals(5.0));
      expect(rustSpec.signatureDropShadow, isTrue);
      expect(rustSpec.enableTiledWatermark, isTrue);
      expect(rustSpec.tiledText, equals('PROOF'));
      expect(rustSpec.tiledOpacity, equals(0.3));
      expect(rustSpec.enableFossBadge, isTrue);
    });

    test('notifier updates state and persists', () async {
      final container = ProviderContainer();
      final notifier = container.read(exportBrandingProvider.notifier);
      expect(container.read(exportBrandingProvider).enableMuseumFrame, isFalse);

      notifier.setMuseumFrame(
        enabled: true,
        themeIndex: 2, // Warm Gallery
        line1: 'LEICA M11',
        line2: '1/500s • f/1.4',
      );

      expect(container.read(exportBrandingProvider).enableMuseumFrame, isTrue);
      expect(container.read(exportBrandingProvider).frameThemeIndex, equals(2));
      expect(container.read(exportBrandingProvider).exifLine1, equals('LEICA M11'));

      notifier.setSignature(
        enabled: true,
        text: '© Jane Doe',
        opacity: 0.9,
        color: 3,
        insetPct: 4.0,
        dropShadow: false,
      );
      expect(container.read(exportBrandingProvider).signatureText, equals('© Jane Doe'));
      expect(container.read(exportBrandingProvider).signatureOpacity, equals(0.9));
      expect(container.read(exportBrandingProvider).signatureColor, equals(3));
      expect(container.read(exportBrandingProvider).signatureInsetPct, equals(4.0));
      expect(container.read(exportBrandingProvider).signatureDropShadow, isFalse);

      notifier.setTiledWatermark(
        enabled: true,
        text: 'CLIENT PROOF',
        opacity: 0.2,
      );
      expect(container.read(exportBrandingProvider).enableTiledWatermark, isTrue);
      expect(container.read(exportBrandingProvider).tiledText, equals('CLIENT PROOF'));

      notifier.setLogo(
        enabled: true,
        bytes: Uint8List.fromList([1, 2, 3]),
        path: 'logo.png',
      );
      expect(container.read(exportBrandingProvider).enableLogo, isTrue);
      expect(container.read(exportBrandingProvider).logoBytes?.length, equals(3));

      notifier.clearLogo();
      expect(container.read(exportBrandingProvider).enableLogo, isFalse);

      notifier.applyWatermarkPreset(WatermarkPreset.goldStudio);
      expect(container.read(exportBrandingProvider).enableSignature, isTrue);
      expect(container.read(exportBrandingProvider).signatureColor, equals(3)); // Gold

      notifier.setFossBadge(true);
      expect(container.read(exportBrandingProvider).enableFossBadge, isTrue);

      notifier.setC2pa(false);
      expect(container.read(exportBrandingProvider).enableC2pa, isFalse);
    });
  });
}
