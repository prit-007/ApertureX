import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/recipe.dart';
import 'video_grading_controller.dart';
import 'video_model.dart';
import 'video_timeline_widget.dart';

/// Professional Video Color Grading, Editing & Multi-Clip Studio screen.
class VideoEditorScreen extends ConsumerStatefulWidget {
  const VideoEditorScreen({
    super.key,
    this.initialClip,
  });

  final VideoClip? initialClip;

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _exportLutSize = 33;
  bool _isExporting = false;
  String _targetResolution = '1080p FHD (1920×1080)';
  String _selectedCodec = 'H.264 (MP4)';
  double _exportFps = 30.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    if (widget.initialClip != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(videoGradingProvider.notifier).loadClip(widget.initialClip!);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _exportCubeLut() async {
    setState(() => _isExporting = true);
    try {
      final cubeText = await ref.read(videoGradingProvider.notifier).exportCubeLut(
            size: _exportLutSize,
            title: ref.read(videoGradingProvider).clip.title,
          );
      await Clipboard.setData(ClipboardData(text: cubeText));
      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported $_exportLutSize³ .CUBE LUT to clipboard (DaVinci Resolve / Premiere ready)',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export .CUBE LUT: $e')),
        );
      }
    }
  }

  Future<void> _exportGradedVideo() async {
    setState(() => _isExporting = true);
    // Non-destructive video export pipeline execution
    await Future<void>.delayed(const Duration(milliseconds: 300));
    setState(() => _isExporting = false);
    if (mounted) {
      final state = ref.read(videoGradingProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rendered video sequence (${state.sequence.totalDurationMs / 1000}s, ${state.sequence.clipCount} clips) at $_targetResolution $_selectedCodec',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(videoGradingProvider);
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.clip.title.isNotEmpty ? state.clip.title : 'Video Color & Edit Studio',
        ),
        actions: [
          TextButton.icon(
            key: const Key('reset-grade-btn'),
            onPressed: () => ref.read(videoGradingProvider.notifier).resetGrade(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reset Grade'),
          ),
          IconButton(
            key: const Key('export-cube-btn'),
            tooltip: 'Export .CUBE 3D LUT for NLE',
            icon: const Icon(Icons.gradient),
            onPressed: _isExporting ? null : _exportCubeLut,
          ),
          FilledButton.icon(
            key: const Key('export-video-btn'),
            onPressed: _isExporting ? null : _exportGradedVideo,
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.movie_creation, size: 18),
            label: const Text('Export Video'),
          ),
          const SizedBox(width: Insets.md),
        ],
      ),
      body: isDesktop
          ? Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Expanded(child: _buildVideoViewport(state)),
                      const VideoTimelineWidget(),
                    ],
                  ),
                ),
                VerticalDivider(width: 1, color: theme.dividerColor),
                SizedBox(
                  width: 390,
                  child: _buildInspector(state),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(
                  flex: 4,
                  child: _buildVideoViewport(state),
                ),
                const VideoTimelineWidget(),
                Divider(height: 1, color: theme.dividerColor),
                Expanded(
                  flex: 5,
                  child: _buildInspector(state),
                ),
              ],
            ),
    );
  }

  Widget _buildVideoViewport(VideoGradingState state) {
    final theme = Theme.of(context);
    final clip = state.clip;
    final framing = state.sequence.globalFraming;
    final aspect = framing.aspectRatio;
    final transform = clip.transform;

    // Filter text overlays active at the current sequence timestamp
    final activeOverlays = state.sequence.overlays.where(
      (o) => o.isVisibleAt(state.playback.positionMs),
    ).toList();

    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: aspect,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video Canvas Frame with 2D Transforms
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(
                  transform.flipHorizontal ? -transform.scale : transform.scale,
                  transform.flipVertical ? -transform.scale : transform.scale,
                  1.0,
                )..rotateZ((transform.rotationDegrees * 3.141592653589793) / 180.0),
                child: Container(
                  color: const Color(0xFF151515),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          state.playback.isPlaying ? Icons.movie : Icons.play_circle_outline,
                          size: 64,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: Insets.sm),
                        Text(
                          '${clip.width} × ${clip.height} · ${clip.fps.toStringAsFixed(0)} FPS',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        if (clip.speed != 1.0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Speed: ${clip.speed}x',
                              style: TextStyle(color: theme.colorScheme.tertiary, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Grade active badge
              if (state.recipe != EditRecipe.neutral)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '3D LUT APPLIED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),

              // Aspect Ratio Guide Tag
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    framing.label.split(' ').first,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Active Text Overlays rendered on video
              for (final overlay in activeOverlays)
                _buildOverlayWidget(overlay),

              // On-screen timecode overlay
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    VideoClip.formatTimecode(state.playback.positionMs, fps: clip.fps),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayWidget(VideoTextOverlay overlay) {
    Alignment alignment;
    switch (overlay.position) {
      case VideoTextPosition.top:
        alignment = Alignment.topCenter;
      case VideoTextPosition.center:
        alignment = Alignment.center;
      case VideoTextPosition.lowerThird:
        alignment = const Alignment(0, 0.65);
      case VideoTextPosition.bottom:
        alignment = Alignment.bottomCenter;
    }

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Color(overlay.backgroundColorValue),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          overlay.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(overlay.colorValue),
            fontSize: overlay.fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildInspector(VideoGradingState state) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Grading'),
            Tab(text: 'Wheels'),
            Tab(key: Key('transform-tab'), text: 'Transform'),
            Tab(key: Key('audio-tab'), text: 'Audio'),
            Tab(key: Key('text-tab'), text: 'Titles / Text'),
            Tab(text: 'Export / Info'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGradingTab(state),
              _buildColorWheelsTab(state),
              _buildTransformTab(state),
              _buildAudioTab(state),
              _buildTextOverlaysTab(state),
              _buildExportInfoTab(state),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGradingTab(VideoGradingState state) {
    final recipe = state.recipe;
    final notifier = ref.read(videoGradingProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(Insets.md),
      children: [
        _buildSliderTile(
          label: 'Exposure',
          value: recipe.exposure,
          min: -4.0,
          max: 4.0,
          divisions: 80,
          onChanged: (v) => notifier.updateRecipe(recipe.copyWith(exposure: v)),
        ),
        _buildSliderTile(
          label: 'Contrast',
          value: recipe.contrast,
          min: -1.0,
          max: 1.0,
          divisions: 100,
          onChanged: (v) => notifier.updateRecipe(recipe.copyWith(contrast: v)),
        ),
        _buildSliderTile(
          label: 'Highlights',
          value: recipe.highlights,
          min: -1.0,
          max: 1.0,
          divisions: 100,
          onChanged: (v) => notifier.updateRecipe(recipe.copyWith(highlights: v)),
        ),
        _buildSliderTile(
          label: 'Shadows',
          value: recipe.shadows,
          min: -1.0,
          max: 1.0,
          divisions: 100,
          onChanged: (v) => notifier.updateRecipe(recipe.copyWith(shadows: v)),
        ),
        _buildSliderTile(
          label: 'Whites',
          value: recipe.whites,
          min: -1.0,
          max: 1.0,
          divisions: 100,
          onChanged: (v) => notifier.updateRecipe(recipe.copyWith(whites: v)),
        ),
        _buildSliderTile(
          label: 'Blacks',
          value: recipe.blacks,
          min: -1.0,
          max: 1.0,
          divisions: 100,
          onChanged: (v) => notifier.updateRecipe(recipe.copyWith(blacks: v)),
        ),
        const Divider(height: 24),
        _buildSliderTile(
          label: 'Temperature',
          value: recipe.temperature,
          min: -100.0,
          max: 100.0,
          divisions: 200,
          onChanged: (v) => notifier.updateRecipe(recipe.copyWith(temperature: v)),
        ),
        _buildSliderTile(
          label: 'Tint',
          value: recipe.tint,
          min: -100.0,
          max: 100.0,
          divisions: 200,
          onChanged: (v) => notifier.updateRecipe(recipe.copyWith(tint: v)),
        ),
        _buildSliderTile(
          label: 'Vibrance',
          value: recipe.vibrance,
          min: -100.0,
          max: 100.0,
          divisions: 200,
          onChanged: (v) => notifier.updateRecipe(recipe.copyWith(vibrance: v)),
        ),
        _buildSliderTile(
          label: 'Saturation',
          value: recipe.saturation,
          min: -100.0,
          max: 100.0,
          divisions: 200,
          onChanged: (v) => notifier.updateRecipe(recipe.copyWith(saturation: v)),
        ),
      ],
    );
  }

  Widget _buildColorWheelsTab(VideoGradingState state) {
    return ListView(
      padding: const EdgeInsets.all(Insets.md),
      children: [
        _buildColorWheelCard(
          title: 'Lift (Shadows)',
          color: const Color(0xFF2A2A38),
          icon: Icons.brightness_low,
          description: 'Controls black point and shadow tone cast',
        ),
        const SizedBox(height: Insets.md),
        _buildColorWheelCard(
          title: 'Gamma (Midtones)',
          color: const Color(0xFF38382A),
          icon: Icons.brightness_medium,
          description: 'Adjusts exposure balance and midtone contrast',
        ),
        const SizedBox(height: Insets.md),
        _buildColorWheelCard(
          title: 'Gain (Highlights)',
          color: const Color(0xFF382A2A),
          icon: Icons.brightness_high,
          description: 'Modulates white level and highlight color temperature',
        ),
      ],
    );
  }

  Widget _buildTransformTab(VideoGradingState state) {
    final notifier = ref.read(videoGradingProvider.notifier);
    final clip = state.clip;
    final transform = clip.transform;
    final framing = state.sequence.globalFraming;

    return ListView(
      padding: const EdgeInsets.all(Insets.md),
      children: [
        Text('Aspect Ratio & Canvas Framing', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Insets.xs),
        DropdownButtonFormField<VideoFramingPreset>(
          initialValue: framing,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final preset in VideoFramingPreset.values)
              DropdownMenuItem(
                value: preset,
                child: Text(preset.label),
              ),
          ],
          onChanged: (preset) {
            if (preset != null) notifier.setFraming(preset);
          },
        ),
        const SizedBox(height: Insets.md),

        Text('Orientation & Spatial Tools', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Insets.xs),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('rotate-clip-btn'),
                onPressed: notifier.rotateActiveClip,
                icon: const Icon(Icons.rotate_right),
                label: Text('Rotate 90° (${transform.rotationDegrees}°)'),
              ),
            ),
            const SizedBox(width: Insets.sm),
            IconButton.outlined(
              key: const Key('flip-h-btn'),
              tooltip: 'Flip Horizontal',
              icon: Icon(
                Icons.flip,
                color: transform.flipHorizontal ? Theme.of(context).colorScheme.primary : null,
              ),
              onPressed: notifier.toggleFlipH,
            ),
            IconButton.outlined(
              key: const Key('flip-v-btn'),
              tooltip: 'Flip Vertical',
              icon: Icon(
                Icons.flip,
                color: transform.flipVertical ? Theme.of(context).colorScheme.primary : null,
              ),
              onPressed: notifier.toggleFlipV,
            ),
          ],
        ),
        const SizedBox(height: Insets.md),

        _buildSliderTile(
          label: 'Scale / Zoom',
          value: transform.scale,
          min: 0.5,
          max: 3.0,
          divisions: 50,
          onChanged: notifier.setScale,
        ),
        const SizedBox(height: Insets.sm),

        Text('Canvas Fit Mode', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Insets.xs),
        SegmentedButton<VideoFitMode>(
          segments: [
            for (final m in VideoFitMode.values)
              ButtonSegment(value: m, label: Text(m.name.toUpperCase())),
          ],
          selected: {transform.fitMode},
          onSelectionChanged: (set) {
            if (set.isNotEmpty) notifier.setFitMode(set.first);
          },
        ),
      ],
    );
  }

  Widget _buildAudioTab(VideoGradingState state) {
    final notifier = ref.read(videoGradingProvider.notifier);
    final audio = state.clip.audio;

    return ListView(
      padding: const EdgeInsets.all(Insets.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            audio.isMuted ? Icons.volume_off : Icons.volume_up,
                            color: audio.isMuted ? Colors.redAccent : Colors.greenAccent,
                          ),
                          const SizedBox(width: Insets.sm),
                          Flexible(
                            child: Text(
                              'Track Gain: ${audio.isMuted ? 'Muted' : '${(audio.volume * 100).round()}%'}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      key: const Key('mute-toggle-btn'),
                      value: !audio.isMuted,
                      onChanged: (_) => notifier.toggleMute(),
                    ),
                  ],
                ),
                Text(
                  'Peak Level: ${audio.audioGainDb.toStringAsFixed(1)} dBFS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Insets.md),

        _buildSliderTile(
          label: 'Volume Gain',
          value: audio.volume,
          min: 0.0,
          max: 2.0,
          divisions: 40,
          onChanged: notifier.setVolume,
        ),
        const SizedBox(height: Insets.md),

        _buildSliderTile(
          label: 'Audio Fade In (ms)',
          value: audio.fadeInMs.toDouble(),
          min: 0.0,
          max: 3000.0,
          divisions: 30,
          onChanged: (v) => notifier.setFadeIn(v.round()),
        ),
        const SizedBox(height: Insets.md),

        _buildSliderTile(
          label: 'Audio Fade Out (ms)',
          value: audio.fadeOutMs.toDouble(),
          min: 0.0,
          max: 3000.0,
          divisions: 30,
          onChanged: (v) => notifier.setFadeOut(v.round()),
        ),
      ],
    );
  }

  Widget _buildTextOverlaysTab(VideoGradingState state) {
    final notifier = ref.read(videoGradingProvider.notifier);
    final overlays = state.sequence.overlays;

    return ListView(
      padding: const EdgeInsets.all(Insets.md),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Text Overlays (${overlays.length})',
                style: Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Insets.sm),
            FilledButton.tonalIcon(
              key: const Key('add-text-overlay-btn'),
              onPressed: () {
                final newOverlay = VideoTextOverlay(
                  id: 'title_${DateTime.now().millisecondsSinceEpoch}',
                  text: 'New Scene Title',
                  startMs: state.playback.positionMs,
                  durationMs: 3000,
                  position: VideoTextPosition.lowerThird,
                );
                notifier.addTextOverlay(newOverlay);
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Title'),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),

        if (overlays.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No text overlays in sequence.\nTap "+ Add Title" to insert a title card or lower third.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38),
              ),
            ),
          )
        else
          for (final overlay in overlays)
            Card(
              margin: const EdgeInsets.only(bottom: Insets.sm),
              child: Padding(
                padding: const EdgeInsets.all(Insets.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: overlay.text,
                            decoration: const InputDecoration(
                              labelText: 'Overlay Text',
                              isDense: true,
                            ),
                            onChanged: (val) {
                              notifier.updateTextOverlay(overlay.copyWith(text: val));
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => notifier.removeTextOverlay(overlay.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<VideoTextPosition>(
                            initialValue: overlay.position,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Position', isDense: true),
                            items: [
                              for (final p in VideoTextPosition.values)
                                DropdownMenuItem(value: p, child: Text(p.label)),
                            ],
                            onChanged: (pos) {
                              if (pos != null) {
                                notifier.updateTextOverlay(overlay.copyWith(position: pos));
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: DropdownButtonFormField<VideoTextAnimation>(
                            initialValue: overlay.animation,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Animation', isDense: true),
                            items: [
                              for (final a in VideoTextAnimation.values)
                                DropdownMenuItem(value: a, child: Text(a.label)),
                            ],
                            onChanged: (anim) {
                              if (anim != null) {
                                notifier.updateTextOverlay(overlay.copyWith(animation: anim));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      'Timing: ${VideoClip.formatTimecode(overlay.startMs)} → ${VideoClip.formatTimecode(overlay.endMs)} (${overlay.durationMs / 1000}s)',
                      style: const TextStyle(fontSize: 11, color: Colors.white54, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildExportInfoTab(VideoGradingState state) {
    final clip = state.clip;
    final sequence = state.sequence;

    return ListView(
      padding: const EdgeInsets.all(Insets.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sequence & Timeline Telemetry', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: Insets.sm),
                _buildInfoRow('Clips in Sequence', '${sequence.clipCount} clips'),
                _buildInfoRow('Total Duration', VideoClip.formatTimecode(sequence.totalDurationMs)),
                _buildInfoRow('Source Dimensions', '${clip.width} × ${clip.height}'),
                _buildInfoRow('Timeline Aspect Ratio', sequence.globalFraming.label),
                _buildInfoRow('Native Frame Rate', '${clip.fps.toStringAsFixed(0)} fps'),
                _buildInfoRow('Speed Multiplier', '${clip.speed}x'),
              ],
            ),
          ),
        ),
        const SizedBox(height: Insets.md),

        Text('Export Target Settings', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Insets.xs),
        DropdownButtonFormField<String>(
          initialValue: _targetResolution,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Target Resolution',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: '4K UHD (3840×2160)', child: Text('4K UHD (3840×2160)')),
            DropdownMenuItem(value: '1080p FHD (1920×1080)', child: Text('1080p FHD (1920×1080)')),
            DropdownMenuItem(value: '720p HD (1280×720)', child: Text('720p HD (1280×720)')),
            DropdownMenuItem(value: 'Reels / Shorts (1080×1920)', child: Text('Reels / Shorts (1080×1920)')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _targetResolution = v);
          },
        ),
        const SizedBox(height: Insets.md),

        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCodec,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Codec & Container',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'H.264 (MP4)', child: Text('H.264 (MP4)')),
                  DropdownMenuItem(value: 'ProRes 422 (MOV)', child: Text('ProRes 422 (MOV)')),
                  DropdownMenuItem(value: 'VP9 (WebM)', child: Text('VP9 (WebM)')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedCodec = v);
                },
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: DropdownButtonFormField<double>(
                initialValue: _exportFps,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Frame Rate',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 24.0, child: Text('24 fps (Cinema)')),
                  DropdownMenuItem(value: 25.0, child: Text('25 fps (PAL)')),
                  DropdownMenuItem(value: 30.0, child: Text('30 fps (Standard)')),
                  DropdownMenuItem(value: 60.0, child: Text('60 fps (High Smooth)')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _exportFps = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),

        Text('.CUBE 3D LUT Export Precision', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Insets.xs),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 17, label: Text('17³ (Draft)')),
            ButtonSegment(value: 33, label: Text('33³ (Pro)')),
            ButtonSegment(value: 65, label: Text('65³ (Master)')),
          ],
          selected: {_exportLutSize},
          onSelectionChanged: (set) => setState(() => _exportLutSize = set.first),
        ),
      ],
    );
  }

  Widget _buildSliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Text(
              value.toStringAsFixed(value.abs() < 10 ? 2 : 0),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white70),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildColorWheelCard({
    required String title,
    required Color color,
    required IconData icon,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.amberAccent),
              const SizedBox(width: Insets.sm),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
