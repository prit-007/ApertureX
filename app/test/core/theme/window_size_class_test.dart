import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/core/theme/window_size_class.dart';

void main() {
  group('WindowSizeClass', () {
    test('compact is below 600 dp', () {
      expect(windowSizeClassFor(0), WindowSizeClass.compact);
      expect(windowSizeClassFor(390), WindowSizeClass.compact);
      expect(windowSizeClassFor(599), WindowSizeClass.compact);
    });

    test('medium is 600 to 839 dp', () {
      expect(windowSizeClassFor(600), WindowSizeClass.medium);
      expect(windowSizeClassFor(700), WindowSizeClass.medium);
      expect(windowSizeClassFor(839), WindowSizeClass.medium);
    });

    test('expanded is 840 to 1199 dp', () {
      expect(windowSizeClassFor(840), WindowSizeClass.expanded);
      expect(windowSizeClassFor(1024), WindowSizeClass.expanded);
      expect(windowSizeClassFor(1199), WindowSizeClass.expanded);
    });

    test('large is 1200 to 1599 dp', () {
      expect(windowSizeClassFor(1200), WindowSizeClass.large);
      expect(windowSizeClassFor(1440), WindowSizeClass.large);
      expect(windowSizeClassFor(1599), WindowSizeClass.large);
    });

    test('extraLarge is 1600 dp and above', () {
      expect(windowSizeClassFor(1600), WindowSizeClass.extraLarge);
      expect(windowSizeClassFor(1920), WindowSizeClass.extraLarge);
      expect(windowSizeClassFor(2560), WindowSizeClass.extraLarge);
    });

    test('boundary values land in the higher class', () {
      expect(windowSizeClassFor(599.99), WindowSizeClass.compact);
      expect(windowSizeClassFor(600.0), WindowSizeClass.medium);
      expect(windowSizeClassFor(839.99), WindowSizeClass.medium);
      expect(windowSizeClassFor(840.0), WindowSizeClass.expanded);
      expect(windowSizeClassFor(1199.99), WindowSizeClass.expanded);
      expect(windowSizeClassFor(1200.0), WindowSizeClass.large);
      expect(windowSizeClassFor(1599.99), WindowSizeClass.large);
      expect(windowSizeClassFor(1600.0), WindowSizeClass.extraLarge);
    });

    test('enum values are ordered compact to extraLarge', () {
      expect(WindowSizeClass.values, [
        WindowSizeClass.compact,
        WindowSizeClass.medium,
        WindowSizeClass.expanded,
        WindowSizeClass.large,
        WindowSizeClass.extraLarge,
      ]);
    });
  });
}
