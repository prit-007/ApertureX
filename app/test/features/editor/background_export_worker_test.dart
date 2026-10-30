import 'dart:io';
import 'dart:typed_data';

import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/features/editor/background_export_worker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late Directory tempDir;

  setUpAll(() async {
    // Attempt to load rust native dylib if available
    final dylib = '${Directory.current.path}/rust/target/debug/librust_lib_aperturex.so';
    if (File(dylib).existsSync()) {
      try {
        // Rust lib available
      } catch (_) {}
    }
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ax_bg_export_test_');
    container = ProviderContainer(
      overrides: [
        exportExecutorProvider.overrideWithValue(
          (task, cancelToken, onProgress) async {
            onProgress(0.5);
            await Future<void>.delayed(const Duration(milliseconds: 20));
            onProgress(1.0);
            return Uint8List.fromList([1, 2, 3, 4]);
          },
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('ExportTask data model properties and transitions', () {
    final task = ExportTask(
      id: 'test_1',
      targetPath: '${tempDir.path}/out.jpg',
      recipe: EditRecipe.neutral,
      rgba: Uint8List(16),
      width: 2,
      height: 2,
    );

    expect(task.isTerminal, isFalse);
    expect(task.progress, 0.0);
    expect(task.status, ExportTaskStatus.pending);

    final running = task.copyWith(
      status: ExportTaskStatus.rendering,
      progress: 0.5,
    );
    expect(running.status, ExportTaskStatus.rendering);
    expect(running.progress, 0.5);
    expect(running.isTerminal, isFalse);

    final done = running.copyWith(
      status: ExportTaskStatus.completed,
      progress: 1.0,
      bytesWritten: 1024,
    );
    expect(done.isTerminal, isTrue);
    expect(done.bytesWritten, 1024);
  });

  test('BackgroundExportWorker completes export and writes to file', () async {
    final worker = container.read(backgroundExportWorkerProvider.notifier);
    final targetPath = '${tempDir.path}/out.jpg';

    final taskId = worker.enqueue(
      rgba: Uint8List(64),
      width: 4,
      height: 4,
      recipe: EditRecipe.neutral,
      targetPath: targetPath,
    );

    expect(taskId, isNotEmpty);

    // Wait for queue to drain
    while (worker.isRunning) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final task = container
        .read(backgroundExportWorkerProvider)
        .firstWhere((t) => t.id == taskId);
    expect(task.status, ExportTaskStatus.completed);
    expect(task.progress, 1.0);
    expect(task.bytesWritten, 4);
    expect(File(targetPath).existsSync(), isTrue);
  });

  test('BackgroundExportWorker cancellation', () async {
    // Container with delayed mock executor to allow cancellation
    final delayedContainer = ProviderContainer(
      overrides: [
        exportExecutorProvider.overrideWithValue(
          (task, cancelToken, onProgress) async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return Uint8List(10);
          },
        ),
      ],
    );

    final worker = delayedContainer.read(backgroundExportWorkerProvider.notifier);
    final taskId = worker.enqueue(
      rgba: Uint8List(64),
      width: 4,
      height: 4,
      recipe: EditRecipe.neutral,
      targetPath: '${tempDir.path}/cancel_out.jpg',
    );

    // Immediately cancel
    await worker.cancel(taskId);

    final task = delayedContainer
        .read(backgroundExportWorkerProvider)
        .firstWhere((t) => t.id == taskId);
    expect(task.status, ExportTaskStatus.cancelled);
    expect(task.isTerminal, isTrue);

    worker.clearCompleted();
    expect(delayedContainer.read(backgroundExportWorkerProvider).isEmpty, isTrue);
    delayedContainer.dispose();
  });
}
