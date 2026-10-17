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
      expect(settings.enableFossBadge, isFalse);
      expect(settings.enableC2pa, isTrue); // C2PA opt-in/active for authenticity
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
        enableFossBadge: true,
      );

      final rustSpec = settings.toRustBrandingSpec();
      expect(rustSpec.enableMuseumFrame, isTrue);
      expect(rustSpec.frameTheme, equals(1));
      expect(rustSpec.exifLine1, equals('SONY A7III • 35MM'));
      expect(rustSpec.exifLine2, equals('1/250s • f/2.0 • ISO 100'));
      expect(rustSpec.enableSignature, isTrue);
      expect(rustSpec.signatureText, equals('© 2026 Test'));
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
      );
      expect(container.read(exportBrandingProvider).signatureText, equals('© Jane Doe'));
      expect(container.read(exportBrandingProvider).signatureOpacity, equals(0.9));

      notifier.setFossBadge(true);
      expect(container.read(exportBrandingProvider).enableFossBadge, isTrue);

      notifier.setC2pa(false);
      expect(container.read(exportBrandingProvider).enableC2pa, isFalse);
    });
  });
}
