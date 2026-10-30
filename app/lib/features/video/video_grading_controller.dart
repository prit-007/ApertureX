import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../color/cube_lut.dart';
import '../../color/grade_spec.dart';
import '../../edit/recipe.dart';
import '../../engine/engine.dart';
import 'video_model.dart';

/// Combined state for video playback and color grading.
class VideoGradingState {
  const VideoGradingState({
    required this.clip,
    this.playback = const VideoPlaybackState(),
    this.recipe = EditRecipe.neutral,
    this.isScrubbing = false,
  });

  final VideoClip clip;
  final VideoPlaybackState playback;
  final EditRecipe recipe;
  final bool isScrubbing;

  VideoGradingState copyWith({
    VideoClip? clip,
    VideoPlaybackState? playback,
    EditRecipe? recipe,
    bool? isScrubbing,
  }) {
    return VideoGradingState(
      clip: clip ?? this.clip,
      playback: playback ?? this.playback,
      recipe: recipe ?? this.recipe,
      isScrubbing: isScrubbing ?? this.isScrubbing,
    );
  }
}

/// Provider managing video playback, timeline trim, and color grading.
final videoGradingProvider =
    NotifierProvider<VideoGradingController, VideoGradingState>(
  VideoGradingController.new,
);

class VideoGradingController extends Notifier<VideoGradingState> {
  Timer? _playbackTimer;

  @override
  VideoGradingState build() {
    ref.onDispose(() {
      _playbackTimer?.cancel();
    });

    const defaultClip = VideoClip(
      id: 'demo_clip',
      path: '',
      title: 'Demo Reel',
      durationMs: 15000, // 15 seconds
      fps: 30.0,
      width: 1920,
      height: 1080,
    );

    return const VideoGradingState(
      clip: defaultClip,
      playback: VideoPlaybackState(outPointMs: 15000),
      recipe: EditRecipe.neutral,
    );
  }

  void loadClip(VideoClip clip) {
    _playbackTimer?.cancel();
    state = state.copyWith(
      clip: clip,
      playback: VideoPlaybackState(
        positionMs: clip.inPointMs,
        inPointMs: clip.inPointMs,
        outPointMs: clip.outPointMs,
      ),
    );
  }

  void togglePlay() {
    if (state.playback.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void play() {
    if (state.playback.isPlaying) return;
    _playbackTimer?.cancel();

    // If at or past outPoint, wrap to inPoint
    var pos = state.playback.positionMs;
    if (pos >= state.clip.outPointMs) {
      pos = state.clip.inPointMs;
    }

    state = state.copyWith(
      playback: state.playback.copyWith(isPlaying: true, positionMs: pos),
    );

    const intervalMs = 33; // ~30 fps tick
    _playbackTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (_) {
      tick((intervalMs * state.playback.speed).round());
    });
  }

  void pause() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    state = state.copyWith(
      playback: state.playback.copyWith(isPlaying: false),
    );
  }

  void tick(int elapsedMs) {
    if (!state.playback.isPlaying) return;

    var newPos = state.playback.positionMs + elapsedMs;
    final outPt = state.clip.outPointMs;
    final inPt = state.clip.inPointMs;

    if (newPos >= outPt) {
      if (state.playback.isLooping) {
        newPos = inPt;
      } else {
        newPos = outPt;
        pause();
      }
    }

    state = state.copyWith(
      playback: state.playback.copyWith(positionMs: newPos),
    );
  }

  void seekTo(int positionMs) {
    final clamped = positionMs.clamp(0, state.clip.durationMs);
    state = state.copyWith(
      playback: state.playback.copyWith(positionMs: clamped),
    );
  }

  void stepFrameForward() {
    pause();
    final frameDurationMs = (1000.0 / state.clip.fps).round();
    seekTo(state.playback.positionMs + frameDurationMs);
  }

  void stepFrameBackward() {
    pause();
    final frameDurationMs = (1000.0 / state.clip.fps).round();
    seekTo(state.playback.positionMs - frameDurationMs);
  }

  void setInPoint(int ms) {
    final clamped = ms.clamp(0, state.clip.outPointMs);
    final updatedClip = state.clip.copyWith(inPointMs: clamped);
    final currentPos = state.playback.positionMs < clamped
        ? clamped
        : state.playback.positionMs;

    state = state.copyWith(
      clip: updatedClip,
      playback: state.playback.copyWith(
        inPointMs: clamped,
        positionMs: currentPos,
      ),
    );
  }

  void setOutPoint(int ms) {
    final clamped = ms.clamp(state.clip.inPointMs, state.clip.durationMs);
    final updatedClip = state.clip.copyWith(outPointMs: clamped);
    final currentPos = state.playback.positionMs > clamped
        ? clamped
        : state.playback.positionMs;

    state = state.copyWith(
      clip: updatedClip,
      playback: state.playback.copyWith(
        outPointMs: clamped,
        positionMs: currentPos,
      ),
    );
  }

  void toggleLoop() {
    state = state.copyWith(
      playback: state.playback.copyWith(isLooping: !state.playback.isLooping),
    );
  }

  void setSpeed(double speed) {
    state = state.copyWith(
      playback: state.playback.copyWith(speed: speed),
    );
  }

  void updateRecipe(EditRecipe recipe) {
    state = state.copyWith(recipe: recipe);
  }

  void resetGrade() {
    state = state.copyWith(recipe: EditRecipe.neutral);
  }

  Future<String> exportCubeLut({int size = 33, String? title}) async {
    final lutTitle = (title != null && title.isNotEmpty)
        ? title
        : (state.clip.title.isNotEmpty ? state.clip.title : 'ApertureX Video Grade');

    try {
      final spec = GradeSpec.fromRecipe(state.recipe);
      return await AxEngine.exportCubeLut(
        spec,
        size: size,
        title: lutTitle,
      );
    } catch (_) {
      // Pure Dart fallback for headless/test environments
      final n = size;
      final data = Float32List(n * n * n * 3);
      final inv = 1.0 / (n - 1);
      final ev = (1 << state.recipe.exposure.round().clamp(-4, 4)).toDouble();
      for (var b = 0; b < n; b++) {
        for (var g = 0; g < n; g++) {
          for (var r = 0; r < n; r++) {
            final idx = (r + g * n + b * n * n) * 3;
            data[idx] = (r * inv * ev).clamp(0.0, 1.0);
            data[idx + 1] = (g * inv * ev).clamp(0.0, 1.0);
            data[idx + 2] = (b * inv * ev).clamp(0.0, 1.0);
          }
        }
      }
      final lut = CubeLut(size: n, data: data, title: lutTitle);
      return lut.toCubeText(title: lutTitle);
    }
  }
}
