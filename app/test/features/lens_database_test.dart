import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/features/lens/lens_database.dart';

void main() {
  group('LensDatabase', () {
    test('contains curated lenses across major camera makers', () {
      final makers = LensDatabase.getMakers();
      expect(makers, containsAll(['Sony', 'Canon', 'Nikon', 'Fujifilm', 'Apple', 'Google']));
    });

    test('matches Sony FE 24-70mm F2.8 GM II by model string', () {
      final match = LensDatabase.findBestMatch(lensModel: 'FE 24-70mm F2.8 GM II');
      expect(match, isNotNull);
      expect(match!.maker, 'Sony');
      expect(match.model, 'FE 24-70mm F2.8 GM II');
      expect(match.maxAperture, 2.8);
      expect(match.distortionCorrection, greaterThan(0));
      expect(match.vignetteCorrection, greaterThan(0));
    });

    test('matches Canon RF 50mm F1.2 by keywords', () {
      final match = LensDatabase.findBestMatch(lensModel: 'RF 50mm F1.2 L USM');
      expect(match, isNotNull);
      expect(match!.maker, 'Canon');
      expect(match.model, 'RF 50mm F1.2 L USM');
    });

    test('matches iPhone 15 Pro computational lens by maker and focal length', () {
      final match = LensDatabase.findBestMatch(
        cameraMake: 'Apple',
        focalLength: 6.86,
      );
      expect(match, isNotNull);
      expect(match!.maker, 'Apple');
      expect(match.model, contains('iPhone 15 Pro Main Camera'));
    });

    test('filters lenses by maker', () {
      final sonyLenses = LensDatabase.getLensesForMaker('Sony');
      expect(sonyLenses, isNotEmpty);
      expect(sonyLenses.every((l) => l.maker == 'Sony'), isTrue);
    });
  });
}
