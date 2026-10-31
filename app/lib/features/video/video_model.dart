import 'dart:math' as math;

/// Audio settings for an individual clip or track.
class VideoAudioSettings {
  const VideoAudioSettings({
    this.volume = 1.0,
    this.isMuted = false,
    this.fadeInMs = 0,
    this.fadeOutMs = 0,
  });

  /// Linear volume multiplier from 0.0 (silent) to 2.0 (+6dB boost).
  final double volume;

  /// Whether the audio track is muted.
  final bool isMuted;

  /// Audio fade-in duration from zero to target volume in milliseconds.
  final int fadeInMs;

  /// Audio fade-out duration from target volume to zero in milliseconds.
  final int fadeOutMs;

  /// Audio gain in decibels relative to unity gain (1.0 = 0dB).
  double get audioGainDb {
    if (isMuted || volume <= 0.0) return -60.0;
    return (20.0 * (math.log(volume) / math.ln10)).clamp(-60.0, 12.0);
  }

  VideoAudioSettings copyWith({
    double? volume,
    bool? isMuted,
    int? fadeInMs,
    int? fadeOutMs,
  }) {
    return VideoAudioSettings(
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      fadeInMs: fadeInMs ?? this.fadeInMs,
      fadeOutMs: fadeOutMs ?? this.fadeOutMs,
    );
  }
}

/// Standard framing presets for social and cinema destinations.
enum VideoFramingPreset {
  ratio16x9,
  ratio9x16,
  ratio1x1,
  ratio4x5,
  ratio21x9,
  original;

  double get aspectRatio {
    switch (this) {
      case VideoFramingPreset.ratio16x9:
        return 16.0 / 9.0;
      case VideoFramingPreset.ratio9x16:
        return 9.0 / 16.0;
      case VideoFramingPreset.ratio1x1:
        return 1.0;
      case VideoFramingPreset.ratio4x5:
        return 4.0 / 5.0;
      case VideoFramingPreset.ratio21x9:
        return 21.0 / 9.0;
      case VideoFramingPreset.original:
        return 16.0 / 9.0;
    }
  }

  String get label {
    switch (this) {
      case VideoFramingPreset.ratio16x9:
        return '16:9 (Landscape YouTube)';
      case VideoFramingPreset.ratio9x16:
        return '9:16 (Shorts / Reels / TikTok)';
      case VideoFramingPreset.ratio1x1:
        return '1:1 (Square Feed)';
      case VideoFramingPreset.ratio4x5:
        return '4:5 (Instagram Portrait)';
      case VideoFramingPreset.ratio21x9:
        return '21:9 (Cinemascope Ultra-wide)';
      case VideoFramingPreset.original:
        return 'Original Ratio';
    }
  }
}

/// Video viewport fit options.
enum VideoFitMode {
  fit,
  fill,
  stretch;

  String get label {
    switch (this) {
      case VideoFitMode.fit:
        return 'Fit (Letterbox)';
      case VideoFitMode.fill:
        return 'Fill (Crop)';
      case VideoFitMode.stretch:
        return 'Stretch';
    }
  }
}

/// 2D Transform and spatial framing parameters.
class VideoTransform {
  const VideoTransform({
    this.framing = VideoFramingPreset.ratio16x9,
    this.fitMode = VideoFitMode.fit,
    this.rotationDegrees = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.scale = 1.0,
    this.panX = 0.0,
    this.panY = 0.0,
  });

  final VideoFramingPreset framing;
  final VideoFitMode fitMode;
  final int rotationDegrees;
  final bool flipHorizontal;
  final bool flipVertical;
  final double scale;
  final double panX;
  final double panY;

  VideoTransform rotateClockwise() {
    return copyWith(rotationDegrees: (rotationDegrees + 90) % 360);
  }

  VideoTransform toggleFlipH() {
    return copyWith(flipHorizontal: !flipHorizontal);
  }

  VideoTransform toggleFlipV() {
    return copyWith(flipVertical: !flipVertical);
  }

  VideoTransform copyWith({
    VideoFramingPreset? framing,
    VideoFitMode? fitMode,
    int? rotationDegrees,
    bool? flipHorizontal,
    bool? flipVertical,
    double? scale,
    double? panX,
    double? panY,
  }) {
    return VideoTransform(
      framing: framing ?? this.framing,
      fitMode: fitMode ?? this.fitMode,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
      scale: scale ?? this.scale,
      panX: panX ?? this.panX,
      panY: panY ?? this.panY,
    );
  }
}

/// Transition styles between consecutive timeline clips.
enum VideoTransitionType {
  none,
  crossDissolve,
  dipToBlack,
  dipToWhite,
  wipeLeft,
  wipeRight;

  String get label {
    switch (this) {
      case VideoTransitionType.none:
        return 'Cut';
      case VideoTransitionType.crossDissolve:
        return 'Cross Dissolve';
      case VideoTransitionType.dipToBlack:
        return 'Dip to Black';
      case VideoTransitionType.dipToWhite:
        return 'Dip to White';
      case VideoTransitionType.wipeLeft:
        return 'Wipe Left';
      case VideoTransitionType.wipeRight:
        return 'Wipe Right';
    }
  }
}

/// Non-destructive transition between two video clips.
class VideoTransition {
  const VideoTransition({
    this.type = VideoTransitionType.none,
    this.durationMs = 500,
  });

  final VideoTransitionType type;
  final int durationMs;

  VideoTransition copyWith({
    VideoTransitionType? type,
    int? durationMs,
  }) {
    return VideoTransition(
      type: type ?? this.type,
      durationMs: durationMs ?? this.durationMs,
    );
  }
}

/// Screen positioning for text / title overlays.
enum VideoTextPosition {
  top,
  center,
  lowerThird,
  bottom;

  String get label {
    switch (this) {
      case VideoTextPosition.top:
        return 'Top Header';
      case VideoTextPosition.center:
        return 'Center Screen';
      case VideoTextPosition.lowerThird:
        return 'Lower Third';
      case VideoTextPosition.bottom:
        return 'Bottom Subtitle';
    }
  }
}

/// Animation styles for text overlays.
enum VideoTextAnimation {
  none,
  fadeIn,
  slideUp;

  String get label {
    switch (this) {
      case VideoTextAnimation.none:
        return 'Static Cut';
      case VideoTextAnimation.fadeIn:
        return 'Fade In/Out';
      case VideoTextAnimation.slideUp:
        return 'Slide Up';
    }
  }
}

/// A text or title overlay rendered onto the video sequence.
class VideoTextOverlay {
  const VideoTextOverlay({
    required this.id,
    required this.text,
    this.startMs = 0,
    this.durationMs = 3000,
    this.position = VideoTextPosition.lowerThird,
    this.animation = VideoTextAnimation.fadeIn,
    this.fontSize = 24.0,
    this.colorValue = 0xFFFFFFFF,
    this.backgroundColorValue = 0x88000000,
  });

  final String id;
  final String text;
  final int startMs;
  final int durationMs;
  final VideoTextPosition position;
  final VideoTextAnimation animation;
  final double fontSize;
  final int colorValue;
  final int backgroundColorValue;

  int get endMs => startMs + durationMs;

  bool isVisibleAt(int timeMs) => timeMs >= startMs && timeMs <= endMs;

  VideoTextOverlay copyWith({
    String? id,
    String? text,
    int? startMs,
    int? durationMs,
    VideoTextPosition? position,
    VideoTextAnimation? animation,
    double? fontSize,
    int? colorValue,
    int? backgroundColorValue,
  }) {
    return VideoTextOverlay(
      id: id ?? this.id,
      text: text ?? this.text,
      startMs: startMs ?? this.startMs,
      durationMs: durationMs ?? this.durationMs,
      position: position ?? this.position,
      animation: animation ?? this.animation,
      fontSize: fontSize ?? this.fontSize,
      colorValue: colorValue ?? this.colorValue,
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
    );
  }
}

/// Keyframe for parameter animation over time.
class VideoKeyframe {
  const VideoKeyframe({
    required this.timeMs,
    required this.value,
    this.curve = 'linear',
  });

  final int timeMs;
  final double value;
  final String curve;
}

/// Track of keyframes for a specific parameter.
class KeyframeTrack {
  const KeyframeTrack({
    required this.property,
    this.keyframes = const [],
  });

  final String property;
  final List<VideoKeyframe> keyframes;

  double evaluateAt(int timeMs, double defaultValue) {
    if (keyframes.isEmpty) return defaultValue;
    if (keyframes.length == 1 || timeMs <= keyframes.first.timeMs) {
      return keyframes.first.value;
    }
    if (timeMs >= keyframes.last.timeMs) {
      return keyframes.last.value;
    }

    // Find bounding keyframes
    for (var i = 0; i < keyframes.length - 1; i++) {
      final k0 = keyframes[i];
      final k1 = keyframes[i + 1];
      if (timeMs >= k0.timeMs && timeMs <= k1.timeMs) {
        final span = k1.timeMs - k0.timeMs;
        if (span <= 0) return k0.value;
        final t = (timeMs - k0.timeMs) / span;
        return k0.value + t * (k1.value - k0.value);
      }
    }
    return defaultValue;
  }
}

/// Represents an individual video clip loaded into the timeline.
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
    this.speed = 1.0,
    this.isReversed = false,
    this.audio = const VideoAudioSettings(),
    this.transform = const VideoTransform(),
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
  final double speed;
  final bool isReversed;
  final VideoAudioSettings audio;
  final VideoTransform transform;

  int get trimmedDurationMs =>
      (outPointMs - inPointMs).clamp(0, durationMs);

  /// Effective timeline duration after taking playback speed into account.
  int get effectiveDurationMs =>
      speed > 0 ? (trimmedDurationMs / speed).round() : trimmedDurationMs;

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
    double? speed,
    bool? isReversed,
    VideoAudioSettings? audio,
    VideoTransform? transform,
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
      speed: speed ?? this.speed,
      isReversed: isReversed ?? this.isReversed,
      audio: audio ?? this.audio,
      transform: transform ?? this.transform,
    );
  }
}

/// Maps a global timeline timestamp to a specific clip index and local clip timestamp.
class ClipTimeMap {
  const ClipTimeMap({
    required this.clipIndex,
    required this.localMs,
  });

  final int clipIndex;
  final int localMs;
}

/// Multi-clip sequence containing sequential clips, transitions, and overlays.
class VideoSequence {
  VideoSequence({
    this.id = 'seq-default',
    this.title = 'ApertureX Timeline Sequence',
    List<VideoClip>? clips,
    List<VideoTransition>? transitions,
    List<VideoTextOverlay>? overlays,
    this.globalFraming = VideoFramingPreset.ratio16x9,
  })  : clips = List.unmodifiable(clips ?? []),
        transitions = List.unmodifiable(transitions ??
            List.generate(
              math.max(0, (clips?.length ?? 0) - 1),
              (_) => const VideoTransition(),
            )),
        overlays = List.unmodifiable(overlays ?? []);

  final String id;
  final String title;
  final List<VideoClip> clips;
  final List<VideoTransition> transitions;
  final List<VideoTextOverlay> overlays;
  final VideoFramingPreset globalFraming;

  int get clipCount => clips.length;

  int get totalDurationMs {
    var total = 0;
    for (final clip in clips) {
      total += clip.effectiveDurationMs;
    }
    return total;
  }

  int getClipStartTime(int clipIndex) {
    var start = 0;
    for (var i = 0; i < clipIndex && i < clips.length; i++) {
      start += clips[i].effectiveDurationMs;
    }
    return start;
  }

  ClipTimeMap mapSequenceTimeToClip(int sequenceMs) {
    if (clips.isEmpty) return const ClipTimeMap(clipIndex: 0, localMs: 0);

    var accumulatedMs = 0;
    for (var i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final clipDuration = clip.effectiveDurationMs;
      if (sequenceMs < accumulatedMs + clipDuration || i == clips.length - 1) {
        final localTimelineMs = sequenceMs - accumulatedMs;
        final scaledMs = (localTimelineMs * clip.speed).round();
        final localClipMs = (clip.inPointMs + scaledMs).clamp(clip.inPointMs, clip.outPointMs);
        return ClipTimeMap(clipIndex: i, localMs: localClipMs);
      }
      accumulatedMs += clipDuration;
    }
    return ClipTimeMap(clipIndex: clips.length - 1, localMs: clips.last.outPointMs);
  }

  VideoSequence splitClip(int clipIndex, int splitLocalMs) {
    if (clipIndex < 0 || clipIndex >= clips.length) return this;
    final clip = clips[clipIndex];
    if (splitLocalMs <= clip.inPointMs || splitLocalMs >= clip.outPointMs) {
      return this;
    }

    final firstPart = clip.copyWith(
      id: '${clip.id}_part1',
      title: '${clip.title} (Part 1)',
      outPointMs: splitLocalMs,
    );

    final secondPart = clip.copyWith(
      id: '${clip.id}_part2',
      title: '${clip.title} (Part 2)',
      inPointMs: splitLocalMs,
    );

    final updatedClips = List<VideoClip>.from(clips);
    updatedClips.removeAt(clipIndex);
    updatedClips.insert(clipIndex, secondPart);
    updatedClips.insert(clipIndex, firstPart);

    final updatedTransitions = List<VideoTransition>.generate(
      updatedClips.length - 1,
      (i) => i < transitions.length ? transitions[i] : const VideoTransition(),
    );

    return VideoSequence(
      id: id,
      title: title,
      clips: updatedClips,
      transitions: updatedTransitions,
      overlays: overlays,
      globalFraming: globalFraming,
    );
  }

  VideoSequence removeClip(int clipIndex) {
    if (clips.length <= 1 || clipIndex < 0 || clipIndex >= clips.length) {
      return this;
    }
    final updatedClips = List<VideoClip>.from(clips)..removeAt(clipIndex);
    final updatedTransitions = List<VideoTransition>.generate(
      updatedClips.length - 1,
      (i) => i < transitions.length ? transitions[i] : const VideoTransition(),
    );
    return VideoSequence(
      id: id,
      title: title,
      clips: updatedClips,
      transitions: updatedTransitions,
      overlays: overlays,
      globalFraming: globalFraming,
    );
  }

  VideoSequence duplicateClip(int clipIndex) {
    if (clipIndex < 0 || clipIndex >= clips.length) return this;
    final clip = clips[clipIndex];
    final copy = clip.copyWith(
      id: '${clip.id}_copy_${DateTime.now().millisecondsSinceEpoch}',
      title: '${clip.title} (Copy)',
    );
    final updatedClips = List<VideoClip>.from(clips)..insert(clipIndex + 1, copy);
    final updatedTransitions = List<VideoTransition>.generate(
      updatedClips.length - 1,
      (i) => i < transitions.length ? transitions[i] : const VideoTransition(),
    );
    return VideoSequence(
      id: id,
      title: title,
      clips: updatedClips,
      transitions: updatedTransitions,
      overlays: overlays,
      globalFraming: globalFraming,
    );
  }

  VideoSequence reorderClip(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= clips.length ||
        newIndex < 0 ||
        newIndex >= clips.length ||
        oldIndex == newIndex) {
      return this;
    }
    final updatedClips = List<VideoClip>.from(clips);
    final item = updatedClips.removeAt(oldIndex);
    updatedClips.insert(newIndex, item);
    return VideoSequence(
      id: id,
      title: title,
      clips: updatedClips,
      transitions: transitions,
      overlays: overlays,
      globalFraming: globalFraming,
    );
  }

  VideoSequence updateClip(int index, VideoClip clip) {
    if (index < 0 || index >= clips.length) return this;
    final updatedClips = List<VideoClip>.from(clips)..[index] = clip;
    return VideoSequence(
      id: id,
      title: title,
      clips: updatedClips,
      transitions: transitions,
      overlays: overlays,
      globalFraming: globalFraming,
    );
  }

  VideoSequence addClip(VideoClip clip) {
    final updatedClips = List<VideoClip>.from(clips)..add(clip);
    final updatedTransitions = List<VideoTransition>.generate(
      updatedClips.length - 1,
      (i) => i < transitions.length ? transitions[i] : const VideoTransition(),
    );
    return VideoSequence(
      id: id,
      title: title,
      clips: updatedClips,
      transitions: updatedTransitions,
      overlays: overlays,
      globalFraming: globalFraming,
    );
  }

  VideoSequence setTransition(int index, VideoTransition transition) {
    if (index < 0 || index >= transitions.length) return this;
    final updatedTransitions = List<VideoTransition>.from(transitions)
      ..[index] = transition;
    return VideoSequence(
      id: id,
      title: title,
      clips: clips,
      transitions: updatedTransitions,
      overlays: overlays,
      globalFraming: globalFraming,
    );
  }

  VideoSequence addOverlay(VideoTextOverlay overlay) {
    final updatedOverlays = List<VideoTextOverlay>.from(overlays)..add(overlay);
    return VideoSequence(
      id: id,
      title: title,
      clips: clips,
      transitions: transitions,
      overlays: updatedOverlays,
      globalFraming: globalFraming,
    );
  }

  VideoSequence removeOverlay(String overlayId) {
    final updatedOverlays =
        overlays.where((o) => o.id != overlayId).toList();
    return VideoSequence(
      id: id,
      title: title,
      clips: clips,
      transitions: transitions,
      overlays: updatedOverlays,
      globalFraming: globalFraming,
    );
  }

  VideoSequence updateOverlay(VideoTextOverlay overlay) {
    final updatedOverlays = overlays
        .map((o) => o.id == overlay.id ? overlay : o)
        .toList();
    return VideoSequence(
      id: id,
      title: title,
      clips: clips,
      transitions: transitions,
      overlays: updatedOverlays,
      globalFraming: globalFraming,
    );
  }

  VideoSequence copyWith({
    String? id,
    String? title,
    List<VideoClip>? clips,
    List<VideoTransition>? transitions,
    List<VideoTextOverlay>? overlays,
    VideoFramingPreset? globalFraming,
  }) {
    return VideoSequence(
      id: id ?? this.id,
      title: title ?? this.title,
      clips: clips ?? this.clips,
      transitions: transitions ?? this.transitions,
      overlays: overlays ?? this.overlays,
      globalFraming: globalFraming ?? this.globalFraming,
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
    this.frameRate = 30.0,
    this.format = 'MP4',
  });

  final String targetResolution;
  final int lutExportSize;
  final String codec;
  final bool includeAudio;
  final bool exportOnlyLut;
  final double frameRate;
  final String format;

  VideoExportConfig copyWith({
    String? targetResolution,
    int? lutExportSize,
    String? codec,
    bool? includeAudio,
    bool? exportOnlyLut,
    double? frameRate,
    String? format,
  }) {
    return VideoExportConfig(
      targetResolution: targetResolution ?? this.targetResolution,
      lutExportSize: lutExportSize ?? this.lutExportSize,
      codec: codec ?? this.codec,
      includeAudio: includeAudio ?? this.includeAudio,
      exportOnlyLut: exportOnlyLut ?? this.exportOnlyLut,
      frameRate: frameRate ?? this.frameRate,
      format: format ?? this.format,
    );
  }
}
