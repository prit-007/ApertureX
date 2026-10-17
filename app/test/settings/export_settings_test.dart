import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aperturex/settings/export_settings.dart';

void main() {
  test('persists and restores export quality + max size', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(exportSettingsProvider.notifier).setQuality(80);
    container.read(exportSettingsProvider.notifier).setMaxDim(1080);
    container.read(exportSettingsProvider.notifier).setColorSpace(1);
    container.read(exportSettingsProvider.notifier).setUltraHdr(true);
    container.read(exportSettingsProvider.notifier).setHdrHeadroom(3.0);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('export_quality'), 80);
    expect(prefs.getInt('export_max_dim'), 1080);
    expect(prefs.getInt('export_color_space'), 1);
    expect(prefs.getBool('export_ultra_hdr'), isTrue);
    expect(prefs.getDouble('export_hdr_headroom'), 3.0);

    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    restored.read(exportSettingsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(restored.read(exportSettingsProvider).quality, 80);
    expect(restored.read(exportSettingsProvider).maxDim, 1080);
    expect(restored.read(exportSettingsProvider).colorSpace, 1);
    expect(restored.read(exportSettingsProvider).ultraHdr, isTrue);
    expect(restored.read(exportSettingsProvider).hdrHeadroom, 3.0);
  });

  test('clamps out-of-range values', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(exportSettingsProvider.notifier);
    n.setQuality(200);
    expect(container.read(exportSettingsProvider).quality, 100);
    n.setQuality(10);
    expect(container.read(exportSettingsProvider).quality, 60);

    n.setHdrHeadroom(10.0);
    expect(container.read(exportSettingsProvider).hdrHeadroom, 4.0);
    n.setHdrHeadroom(0.2);
    expect(container.read(exportSettingsProvider).hdrHeadroom, 1.0);
  });
}
