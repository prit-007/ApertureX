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
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('export_quality'), 80);
    expect(prefs.getInt('export_max_dim'), 1080);

    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    restored.read(exportSettingsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(restored.read(exportSettingsProvider).quality, 80);
    expect(restored.read(exportSettingsProvider).maxDim, 1080);
  });

  test('clamps out-of-range values', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(exportSettingsProvider.notifier);
    n.setQuality(200);
    expect(container.read(exportSettingsProvider).quality, 100);
    n.setQuality(10);
    expect(container.read(exportSettingsProvider).quality, 60);
  });
}
