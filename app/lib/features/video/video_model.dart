/// Represents a video clip loaded into the grading and editing studio.
class VideoClip {
  const VideoClip({
    required this.id,
    required this.path,
    this.title = '',
    this.durationMs = 0,
    this.fps = 30.0,
    this.width = 1920,
    this.height = 1080,
    this.inPointMs = 0,
    int? outPointMs,
  }) : outPointMs = outPointMs ?? durationMs;

  final String id;
  final String path;
  final String title;
  final int durationMs;
  final double fps;
  final int width;
  final int height;
  final int inPointMs;
  final int outPointMs;

  int get trimmedDurationMs =>
      (outPointMs - inPointMs).clamp(0, durationMs);

  int get totalFrames => ((durationMs / 1000.0) * fps).round();

  int get trimmedFrames => ((trimmedDurationMs / 1000.0) * fps).round();

  double get aspectRatio => height > 0 ? width / height : 16.0 / 9.0;

  int msToFrame(int ms) => ((ms / 1000.0) * fps).round();

  int frameToMs(int frame) => ((frame / fps) * 1000.0).round();

  static String formatTimecode(int ms, {double fps = 30.0}) {
    if (ms < 0) ms = 0;
    final totalSeconds = ms ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final frame = (((ms % 1000) / 1000.0) * fps).floor();

    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    final ff = frame.toString().padLeft(2, '0');

    return '$hh:$mm:$ss.$ff';
  }

  VideoClip copyWith({
    String? id,
    String? path,
    String? title,
    int? durationMs,
    double? fps,
    int? width,
    int? height,
    int? inPointMs,
    int? outPointMs,
  }) {
    final newDuration = durationMs ?? this.durationMs;
    final newIn = (inPointMs ?? this.inPointMs).clamp(0, newDuration);
    final newOut = (outPointMs ?? this.outPointMs).clamp(newIn, newDuration);

    return VideoClip(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      durationMs: newDuration,
      fps: fps ?? this.fps,
      width: width ?? this.width,
      height: height ?? this.height,
      inPointMs: newIn,
      outPointMs: newOut,
    );
  }
}

/// Dynamic playback and transport state for the video player.
class VideoPlaybackState {
  const VideoPlaybackState({
    this.isPlaying = false,
    this.positionMs = 0,
    this.isLooping = true,
    this.speed = 1.0,
    this.inPointMs = 0,
    this.outPointMs = 0,
  });

  final bool isPlaying;
  final int positionMs;
  final bool isLooping;
  final double speed;
  final int inPointMs;
  final int outPointMs;

  VideoPlaybackState copyWith({
    bool? isPlaying,
    int? positionMs,
    bool? isLooping,
    double? speed,
    int? inPointMs,
    int? outPointMs,
  }) {
    return VideoPlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      positionMs: positionMs ?? this.positionMs,
      isLooping: isLooping ?? this.isLooping,
      speed: speed ?? this.speed,
      inPointMs: inPointMs ?? this.inPointMs,
      outPointMs: outPointMs ?? this.outPointMs,
    );
  }
}

/// Configuration for video rendering and 3D LUT export.
class VideoExportConfig {
  const VideoExportConfig({
    this.targetResolution = 'Source',
    this.lutExportSize = 33,
    this.codec = 'H.264',
    this.includeAudio = true,
    this.exportOnlyLut = false,
  });

  final String targetResolution;
  final int lutExportSize;
  final String codec;
  final bool includeAudio;
  final bool exportOnlyLut;

  VideoExportConfig copyWith({
    String? targetResolution,
    int? lutExportSize,
    String? codec,
    bool? includeAudio,
    bool? exportOnlyLut,
  }) {
    return VideoExportConfig(
      targetResolution: targetResolution ?? this.targetResolution,
      lutExportSize: lutExportSize ?? this.lutExportSize,
      codec: codec ?? this.codec,
      includeAudio: includeAudio ?? this.includeAudio,
      exportOnlyLut: exportOnlyLut ?? this.exportOnlyLut,
    );
  }
}
