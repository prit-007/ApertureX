import 'package:flutter_test/flutter_test.dart';

import 'package:aperturex/features/video/video_model.dart';

void main() {
  group('VideoClip', () {
    test('calculates duration, frame counts, and aspect ratio correctly', () {
      const clip = VideoClip(
        id: 'v1',
        path: '/storage/movies/reel.mp4',
        durationMs: 10000, // 10 seconds
        fps: 24.0,
        width: 3840,
        height: 2160,
      );

      expect(clip.totalFrames, 240);
      expect(clip.aspectRatio, closeTo(16.0 / 9.0, 0.001));
      expect(clip.trimmedDurationMs, 10000);
      expect(clip.trimmedFrames, 240);
    });

    test('supports in-point and out-point trimming', () {
      const clip = VideoClip(
        id: 'v2',
        path: '/storage/movies/action.mp4',
        durationMs: 30000, // 30 seconds
        fps: 30.0,
        inPointMs: 5000,
        outPointMs: 15000,
      );

      expect(clip.trimmedDurationMs, 10000);
      expect(clip.trimmedFrames, 300);
      expect(clip.totalFrames, 900);

      // copyWith updates trim bounds cleanly
      final trimmedMore = clip.copyWith(inPointMs: 8000, outPointMs: 12000);
      expect(trimmedMore.trimmedDurationMs, 4000);
      expect(trimmedMore.trimmedFrames, 120);
    });

    test('formats standard SMPTE-style timecode', () {
      // 0 ms -> 00:00:00.00
      expect(VideoClip.formatTimecode(0, fps: 24.0), '00:00:00.00');

      // 1500 ms at 30 fps -> 1 sec 15 frames -> 00:00:01.15
      expect(VideoClip.formatTimecode(1500, fps: 30.0), '00:00:01.15');

      // 65000 ms at 30 fps -> 1 min 5 sec 0 frames -> 00:01:05.00
      expect(VideoClip.formatTimecode(65000, fps: 30.0), '00:01:05.00');

      // 3661000 ms -> 1 hr 1 min 1 sec
      expect(VideoClip.formatTimecode(3661000, fps: 30.0), '01:01:01.00');
    });

    test('converts between ms and frames accurately', () {
      const clip = VideoClip(
        id: 'v3',
        path: '/storage/c.mp4',
        durationMs: 10000,
        fps: 25.0,
      );

      expect(clip.msToFrame(1000), 25);
      expect(clip.frameToMs(50), 2000);
    });
  });

  group('VideoPlaybackState', () {
    test('initializes with expected defaults and updates immutably', () {
      const initial = VideoPlaybackState();
      expect(initial.isPlaying, isFalse);
      expect(initial.positionMs, 0);
      expect(initial.isLooping, isTrue);
      expect(initial.speed, 1.0);

      final playing = initial.copyWith(isPlaying: true, positionMs: 500);
      expect(playing.isPlaying, isTrue);
      expect(playing.positionMs, 500);
      expect(playing.isLooping, isTrue);
    });
  });
}
