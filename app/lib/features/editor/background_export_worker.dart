import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../color/grade_spec.dart';
import '../../edit/adjustment_layer.dart';
import '../../edit/recipe.dart';
import '../../engine/engine.dart';
import 'export_progress.dart';

/// Supported formats for the background export worker.
enum ExportFormat { jpeg, png, dng, tiff16 }

/// Lifecycle states for an individual export task.
enum ExportTaskStatus {
  pending,
  decoding,
  rendering,
  saving,
  completed,
  failed,
  cancelled,
}

/// Representation of a single queued or executing background export.
class ExportTask {
  ExportTask({
    required this.id,
    required this.targetPath,
    required this.recipe,
    required this.rgba,
    required this.width,
    required this.height,
    this.format = ExportFormat.jpeg,
    this.quality = 90,
    this.maxDim,
    this.status = ExportTaskStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    this.cancelToken = 0,
    this.bytesWritten = 0,
    this.layers = const <AdjustmentLayer>[],
  });

  final String id;
  final String targetPath;
  final EditRecipe recipe;
  final Uint8List rgba;
  final int width;
  final int height;
  final ExportFormat format;
  final int quality;
  final int? maxDim;
  final ExportTaskStatus status;
  final double progress;
  final String? errorMessage;
  final int cancelToken;
  final int bytesWritten;
  final List<AdjustmentLayer> layers;

  bool get isTerminal =>
      status == ExportTaskStatus.completed ||
      status == ExportTaskStatus.failed ||
      status == ExportTaskStatus.cancelled;

  ExportTask copyWith({
    ExportTaskStatus? status,
    double? progress,
    String? errorMessage,
    int? cancelToken,
    int? bytesWritten,
  }) {
    return ExportTask(
      id: id,
      targetPath: targetPath,
      recipe: recipe,
      rgba: rgba,
      width: width,
      height: height,
      format: format,
      quality: quality,
      maxDim: maxDim,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      cancelToken: cancelToken ?? this.cancelToken,
      bytesWritten: bytesWritten ?? this.bytesWritten,
      layers: layers,
    );
  }
}

/// Hook allowing tests to inject custom export execution logic.
typedef ExportExecutor = Future<Uint8List?> Function(
  ExportTask task,
  int cancelToken,
  void Function(double fraction) onProgress,
);

final exportExecutorProvider = Provider<ExportExecutor?>((ref) => null);

/// Riverpod provider for the singleton [BackgroundExportWorker].
final backgroundExportWorkerProvider =
    NotifierProvider<BackgroundExportWorker, List<ExportTask>>(
  BackgroundExportWorker.new,
);

/// Background export worker that persists long-running exports even if the
/// editor screen unmounts (#5).
class BackgroundExportWorker extends Notifier<List<ExportTask>> {
  final _updateController = StreamController<ExportTask>.broadcast();
  bool _isProcessing = false;
  int _sequence = 0;

  Stream<ExportTask> get onTaskUpdate => _updateController.stream;

  @override
  List<ExportTask> build() {
    ref.onDispose(() {
      _updateController.close();
    });
    return const [];
  }

  /// Whether the worker is currently executing a job.
  bool get isRunning => _isProcessing;

  /// Overall progress across all queued and running tasks in 0..1.
  double get overallProgress {
    if (state.isEmpty) return 0.0;
    final totalProgress = state.fold<double>(0.0, (sum, t) => sum + t.progress);
    return totalProgress / state.length;
  }

  /// Enqueues a new background export task and kicks off the background processor.
  String enqueue({
    required Uint8List rgba,
    required int width,
    required int height,
    required EditRecipe recipe,
    required String targetPath,
    ExportFormat format = ExportFormat.jpeg,
    int quality = 90,
    int? maxDim,
    List<AdjustmentLayer> layers = const <AdjustmentLayer>[],
  }) {
    final id = 'task_${DateTime.now().millisecondsSinceEpoch}_${_sequence++}';
    final task = ExportTask(
      id: id,
      rgba: rgba,
      width: width,
      height: height,
      recipe: recipe,
      targetPath: targetPath,
      format: format,
      quality: quality,
      maxDim: maxDim,
      layers: layers,
    );

    state = [...state, task];
    _updateController.add(task);
    _drainQueue();
    return id;
  }

  /// Cancels an in-flight or pending export task.
  Future<void> cancel(String taskId) async {
    final index = state.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final task = state[index];

    if (task.cancelToken > 0) {
      try {
        await AxEngine.exportCancelSet(task.cancelToken);
      } catch (_) {}
    }

    final updated = task.copyWith(status: ExportTaskStatus.cancelled);
    final next = [...state];
    next[index] = updated;
    state = next;
    _updateController.add(updated);
  }

  /// Clears finished (completed/failed/cancelled) tasks from memory.
  void clearCompleted() {
    state = state.where((t) => !t.isTerminal).toList();
  }

  void _updateTask(
    String id, {
    ExportTaskStatus? status,
    double? progress,
    String? errorMessage,
    int? cancelToken,
    int? bytesWritten,
  }) {
    final index = state.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final task = state[index];
    final updated = task.copyWith(
      status: status,
      progress: progress,
      errorMessage: errorMessage,
      cancelToken: cancelToken,
      bytesWritten: bytesWritten,
    );
    final next = [...state];
    next[index] = updated;
    state = next;
    _updateController.add(updated);
  }

  Future<void> _drainQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (true) {
        final pending = state.cast<ExportTask?>().firstWhere(
          (t) => t?.status == ExportTaskStatus.pending,
          orElse: () => null,
        );
        if (pending == null) break;

        await _processTask(pending);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processTask(ExportTask task) async {
    _updateTask(task.id, status: ExportTaskStatus.decoding, progress: 0.1);

    int cancelToken = 0;
    ExportProgressPoller? poller;
    File? tempFile;

    try {
      final customExecutor = ref.read(exportExecutorProvider);
      if (task.format == ExportFormat.jpeg && customExecutor == null) {
        try {
          cancelToken = await AxEngine.exportCancelNew();
        } catch (_) {}
        _updateTask(
          task.id,
          status: ExportTaskStatus.rendering,
          cancelToken: cancelToken,
          progress: 0.2,
        );

        if (cancelToken > 0) {
          poller = ExportProgressPoller(
            token: cancelToken,
            read: AxEngine.exportProgressFraction,
            onValue: (fraction) {
              _updateTask(
                task.id,
                progress: 0.2 + (fraction.clamp(0.0, 1.0) * 0.65),
              );
            },
          )..start();
        }
      } else {
        _updateTask(task.id, status: ExportTaskStatus.rendering, progress: 0.3);
      }

      Uint8List? exportedBytes;

      if (customExecutor != null) {
        exportedBytes = await customExecutor(
          task,
          cancelToken,
          (fraction) {
            _updateTask(
              task.id,
              progress: 0.2 + (fraction.clamp(0.0, 1.0) * 0.65),
            );
          },
        );
      } else {
        switch (task.format) {
          case ExportFormat.jpeg:
            exportedBytes = await AxEngine.exportJpegFull(
              rgba: task.rgba,
              width: task.width,
              height: task.height,
              spec: GradeSpec.fromRecipe(task.recipe),
              quality: task.quality,
              maxDim: task.maxDim,
              cancelToken: cancelToken,
              layers: task.layers,
            );
            break;
          case ExportFormat.png:
            exportedBytes = await AxEngine.exportPng(
              rgba: task.rgba,
              width: task.width,
              height: task.height,
            );
            break;
          case ExportFormat.tiff16:
            exportedBytes = await AxEngine.exportTiff16(
              rgba: task.rgba,
              width: task.width,
              height: task.height,
              xmp: '',
            );
            break;
          case ExportFormat.dng:
            exportedBytes = await AxEngine.exportDng(
              rawBytes: task.rgba,
              xmp: '',
            );
            break;
        }
      }

      poller?.stop();

      // Check if cancelled during rendering
      final current = state.firstWhere((t) => t.id == task.id);
      if (current.status == ExportTaskStatus.cancelled || exportedBytes == null) {
        _updateTask(task.id, status: ExportTaskStatus.cancelled);
        return;
      }

      _updateTask(task.id, status: ExportTaskStatus.saving, progress: 0.9);

      // Atomic write directly to destination
      final targetFile = File(task.targetPath);
      await targetFile.parent.create(recursive: true);

      tempFile = File('${task.targetPath}.tmp_${task.id}');
      await tempFile.writeAsBytes(exportedBytes, flush: true);
      await tempFile.rename(task.targetPath);

      _updateTask(
        task.id,
        status: ExportTaskStatus.completed,
        progress: 1.0,
        bytesWritten: exportedBytes.length,
      );
    } catch (e) {
      poller?.stop();
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      final current = state.cast<ExportTask?>().firstWhere(
        (t) => t?.id == task.id,
        orElse: () => null,
      );
      if (current?.status == ExportTaskStatus.cancelled) {
        return;
      }
      _updateTask(
        task.id,
        status: ExportTaskStatus.failed,
        errorMessage: e.toString(),
      );
    } finally {
      if (cancelToken > 0) {
        try {
          await AxEngine.exportCancelDrop(cancelToken);
        } catch (_) {}
      }
    }
  }
}
