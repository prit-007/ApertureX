import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aperturex/settings/shared_preferences_provider.dart';
import 'package:aperturex/settings/shell_preference.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShellPreference', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to lightroom shell when unconfigured', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(shellPreferenceProvider), AppShellKind.lightroom);
    });

    test('select changes active shell and persists preference', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(shellPreferenceProvider.notifier).select(AppShellKind.snapseed);
      expect(container.read(shellPreferenceProvider), AppShellKind.snapseed);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('shell_kind'), 'snapseed');
    });

    test('synchronously restores snapseed shell via sharedPreferencesProvider without flash', () async {
      SharedPreferences.setMockInitialValues({'shell_kind': 'snapseed'});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Must be immediately snapseed on the first read synchronously
      expect(container.read(shellPreferenceProvider), AppShellKind.snapseed);
    });

    test('defaults to lightroom when persisted value is unrecognized', () async {
      SharedPreferences.setMockInitialValues({'shell_kind': 'unknown_shell'});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(shellPreferenceProvider), AppShellKind.lightroom);
    });
  });
}
