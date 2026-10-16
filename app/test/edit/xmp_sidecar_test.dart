import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/xmp_sidecar.dart';
import 'package:aperturex/edit/xmp_writer.dart';

void main() {
  group('fileNameFor (Adobe sidecar convention, #77)', () {
    test('replaces the image extension with .xmp', () {
      expect(XmpSidecar.fileNameFor('IMG_1234.NEF'), 'IMG_1234.xmp');
      expect(XmpSidecar.fileNameFor('photo.jpg'), 'photo.xmp');
    });

    test('keeps extension-less export names', () {
      expect(XmpSidecar.fileNameFor('aperturex_5'), 'aperturex_5.xmp');
      expect(XmpSidecar.fileNameFor('aperturex_99123'), 'aperturex_99123.xmp');
    });

    test('sanitizes characters a filesystem would reject', () {
      expect(XmpSidecar.fileNameFor('ios/FD86:L0.jpg'), 'ios_FD86_L0.xmp');
      expect(XmpSidecar.fileNameFor('a\\b*c?.nef'), 'a_b_c_.xmp');
    });
  });

  group('DirectoryXmpSidecarSink', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('xmp_sidecar'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('writes the recipe as .xmp next to the export', () async {
      final recipe = EditRecipe.neutral.copyWith(exposure: 0.75);
      final sink = DirectoryXmpSidecarSink(() async => tmp);

      await sink.write('aperturex_9', recipe);

      final file = File('${tmp.path}/aperturex_9.xmp');
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), writeXmp(recipe));
    });

    test('creates the directory on first use', () async {
      final nested = Directory('${tmp.path}/exports');
      final sink = DirectoryXmpSidecarSink(() async => nested);

      await sink.write('a', EditRecipe.neutral);

      expect(File('${nested.path}/a.xmp').existsSync(), isTrue);
    });

    test('a later export overwrites the previous sidecar', () async {
      final sink = DirectoryXmpSidecarSink(() async => tmp);
      await sink.write(
        'shot',
        EditRecipe.neutral.copyWith(exposure: 0.1),
      );
      await sink.write(
        'shot',
        EditRecipe.neutral.copyWith(exposure: 0.9),
      );

      final content = File('${tmp.path}/shot.xmp').readAsStringSync();
      expect(content, contains('crs:Exposure2012="0.9"'));
      expect(content, isNot(contains('crs:Exposure2012="0.1"')));
    });
  });

  test('emitXmpSidecar is best effort: a failing sink never fails the export', () async {
    await emitXmpSidecar(_ThrowingSink(), 'x', EditRecipe.neutral);
    await emitXmpSidecar(null, 'x', EditRecipe.neutral);
  });
}

class _ThrowingSink implements XmpSidecarSink {
  @override
  Future<void> write(String imageName, EditRecipe recipe) async =>
      throw StateError('disk full');
}
