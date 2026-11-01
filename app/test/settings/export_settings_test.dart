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
    container.read(exportSettingsProvider.notifier).setOutputSharpen(media: 1, amount: 0.5);
    container.read(exportSettingsProvider.notifier).setMetadataMode(ExportMetadataMode.copyrightOnly);
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
    expect(restored.read(exportSettingsProvider).outputSharpenMedia, 1);
    expect(restored.read(exportSettingsProvider).metadataMode, ExportMetadataMode.copyrightOnly);
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

  test('applies export presets correctly', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(exportSettingsProvider.notifier);

    n.applyPreset(ExportPresetKind.webSocial);
    expect(container.read(exportSettingsProvider).quality, 85);
    expect(container.read(exportSettingsProvider).maxDim, 2048);
    expect(container.read(exportSettingsProvider).colorSpace, 0);
    expect(container.read(exportSettingsProvider).outputSharpenMedia, 1);
    expect(container.read(exportSettingsProvider).metadataMode, ExportMetadataMode.copyrightOnly);

    n.applyPreset(ExportPresetKind.proDisplay);
    expect(container.read(exportSettingsProvider).colorSpace, 1);
    expect(container.read(exportSettingsProvider).ultraHdr, isTrue);
  });

  test('formats filename tokens correctly', () {
    const settings = ExportSettings(
      filenamePattern: '{original}_{preset}_{counter}_{dimensions}',
    );
    final out = settings.formatFilename(
      original: 'DSC_0042.CR3',
      preset: 'landscape',
      counter: 7,
      outWidth: 3840,
      outHeight: 2160,
    );
    expect(out, 'DSC_0042_landscape_007_3840x2160');
  });

  test('computes target dimensions across all resize modes', () {
    const origSettings = ExportSettings(resizeMode: ExportResizeMode.original);
    expect(origSettings.computeDimensions(4000, 3000), (width: 4000, height: 3000));

    const longEdgeSettings = ExportSettings(
      resizeMode: ExportResizeMode.longEdge,
      resizeDimension: 2000,
    );
    expect(longEdgeSettings.computeDimensions(4000, 2000), (width: 2000, height: 1000));

    const shortEdgeSettings = ExportSettings(
      resizeMode: ExportResizeMode.shortEdge,
      resizeDimension: 1000,
    );
    expect(shortEdgeSettings.computeDimensions(4000, 2000), (width: 2000, height: 1000));

    const percentSettings = ExportSettings(
      resizeMode: ExportResizeMode.percentage,
      resizePercentage: 50,
    );
    expect(percentSettings.computeDimensions(4000, 2000), (width: 2000, height: 1000));

    // Don't enlarge guard
    const guardSettings = ExportSettings(
      resizeMode: ExportResizeMode.longEdge,
      resizeDimension: 3000,
      dontEnlarge: true,
    );
    expect(guardSettings.computeDimensions(1000, 800), (width: 1000, height: 800));
  });

  test('estimates file sizes across formats', () {
    const settings = ExportSettings(quality: 90);
    final jpgSize = settings.estimateFileSize(width: 4000, height: 3000, format: 'jpeg');
    expect(jpgSize, contains('MB'));

    final pngSize = settings.estimateFileSize(width: 2000, height: 1500, format: 'png');
    expect(pngSize, contains('MB'));
  });
}
