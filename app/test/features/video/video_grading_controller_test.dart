import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/features/video/video_grading_controller.dart';
import 'package:aperturex/features/video/video_model.dart';

void main() {
  group('VideoGradingController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initializes with default clip and neutral recipe', () {
      final state = container.read(videoGradingProvider);
      expect(state.clip.durationMs, 15000);
      expect(state.playback.isPlaying, isFalse);
      expect(state.recipe, equals(EditRecipe.neutral));
    });

    test('loads a custom video clip and initializes playback markers', () {
      const clip = VideoClip(
        id: 'clip-101',
        path: '/storage/sample.mp4',
        title: 'Cinematic Sunset',
        durationMs: 20000,
        fps: 24.0,
        inPointMs: 2000,
        outPointMs: 18000,
      );

      container.read(videoGradingProvider.notifier).loadClip(clip);

      final state = container.read(videoGradingProvider);
      expect(state.clip.id, 'clip-101');
      expect(state.clip.title, 'Cinematic Sunset');
      expect(state.playback.inPointMs, 2000);
      expect(state.playback.outPointMs, 18000);
      expect(state.playback.positionMs, 2000);
    });

    test('toggles playback, steps frames forward and backward', () {
      final notifier = container.read(videoGradingProvider.notifier);

      expect(container.read(videoGradingProvider).playback.isPlaying, isFalse);

      notifier.togglePlay();
      expect(container.read(videoGradingProvider).playback.isPlaying, isTrue);

      notifier.togglePlay();
      expect(container.read(videoGradingProvider).playback.isPlaying, isFalse);

      // Step frame forward: 30 fps -> ~33ms
      notifier.seekTo(1000);
      notifier.stepFrameForward();
      expect(container.read(videoGradingProvider).playback.positionMs, closeTo(1033, 2));

      // Step frame backward
      notifier.stepFrameBackward();
      expect(container.read(videoGradingProvider).playback.positionMs, closeTo(1000, 2));
    });

    test('trims in-point and out-point with boundary clamping', () {
      final notifier = container.read(videoGradingProvider.notifier);

      notifier.setInPoint(3000);
      expect(container.read(videoGradingProvider).clip.inPointMs, 3000);

      notifier.setOutPoint(12000);
      expect(container.read(videoGradingProvider).clip.outPointMs, 12000);
      expect(container.read(videoGradingProvider).clip.trimmedDurationMs, 9000);
    });

    test('tick advances position and loops at out-point', () {
      final notifier = container.read(videoGradingProvider.notifier);
      notifier.loadClip(
        const VideoClip(
          id: 'c',
          path: 'p',
          durationMs: 5000,
          inPointMs: 1000,
          outPointMs: 4000,
        ),
      );

      notifier.play();
      notifier.seekTo(3950);

      // Advance by 100ms -> exceeds out-point 4000ms -> loops back to in-point (1000ms)
      notifier.tick(100);

      expect(container.read(videoGradingProvider).playback.positionMs, 1000);
    });

    test('exports 3D .CUBE LUT from graded recipe', () async {
      final notifier = container.read(videoGradingProvider.notifier);

      final gradedRecipe = EditRecipe.neutral.copyWith(
        exposure: 0.5,
        contrast: 0.2,
      );
      notifier.updateRecipe(gradedRecipe);

      final cubeLut = await notifier.exportCubeLut(size: 17, title: 'Golden Hour');

      expect(cubeLut.contains('LUT_3D_SIZE 17'), isTrue);
      expect(cubeLut.contains('TITLE "Golden Hour"'), isTrue);
      expect(cubeLut.contains('DOMAIN_MIN 0.0 0.0 0.0'), isTrue);
      expect(cubeLut.contains('DOMAIN_MAX 1.0 1.0 1.0'), isTrue);
    });
  });
}
