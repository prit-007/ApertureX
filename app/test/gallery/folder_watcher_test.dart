import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/gallery/folder_watcher.dart';

void main() {
  group('AutoImportFolderWatcher Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('aperturex_watch_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('ignores initial existing files so only new photos trigger notification', () async {
      // Create initial photo before watcher starts
      final initialFile = File('${tempDir.path}/existing.jpg');
      await initialFile.writeAsBytes([1, 2, 3]);

      final discovered = <String>[];
      final watcher = AutoImportFolderWatcher(
        directoryPath: tempDir.path,
        debounceDuration: const Duration(milliseconds: 50),
        onPhotoDiscovered: (file) => discovered.add(file.path),
      );

      await watcher.start();
      expect(watcher.isWatching, isTrue);

      // Wait a moment
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(discovered, isEmpty, reason: 'Existing photos should not be re-announced');

      // Now drop a new photo
      final newFile = File('${tempDir.path}/shot_001.dng');
      await newFile.writeAsBytes([4, 5, 6]);

      // Wait for debounce and notification
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(discovered.length, 1);
      expect(discovered.first, newFile.path);

      await watcher.stop();
      expect(watcher.isWatching, isFalse);
    });

    test('filters out unsupported extensions (e.g. .txt, .tmp)', () async {
      final discovered = <String>[];
      final watcher = AutoImportFolderWatcher(
        directoryPath: tempDir.path,
        debounceDuration: const Duration(milliseconds: 50),
        onPhotoDiscovered: (file) => discovered.add(file.path),
      );

      await watcher.start();

      final textFile = File('${tempDir.path}/log.txt');
      await textFile.writeAsString('hello world');

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(discovered, isEmpty);

      await watcher.stop();
    });
  });
}
