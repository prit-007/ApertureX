import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tessera/settings/app_settings.dart';
import 'package:tessera/settings/shell_preference.dart';

void main() {
  test('persists the chosen theme mode', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'light');
  });

  test('restores the persisted theme mode', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(themeModeProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  test('persists and restores the interface shell', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(shellPreferenceProvider.notifier)
        .select(AppShellKind.snapseed);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('shell_kind'), 'snapseed');

    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    restored.read(shellPreferenceProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(restored.read(shellPreferenceProvider), AppShellKind.snapseed);
  });
}
