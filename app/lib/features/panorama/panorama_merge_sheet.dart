import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/log/activity_log.dart';
import '../../core/log/log_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../engine/engine.dart';
import '../../src/rust/api/panorama.dart' as rust_panorama;

/// Bottom sheet for panoramic photo merge with projection selection.
class PanoramaMergeSheet extends ConsumerStatefulWidget {
  const PanoramaMergeSheet({
    super.key,
    required this.inputImages,
    this.onMerged,
  });

  final List<rust_panorama.ApiPanoramaInput> inputImages;
  final void Function(rust_panorama.ApiPanoramaResult result)? onMerged;

  @override
  ConsumerState<PanoramaMergeSheet> createState() => _PanoramaMergeSheetState();
}

class _PanoramaMergeSheetState extends ConsumerState<PanoramaMergeSheet> {
  int _projectionIndex = 1; // 0: Planar, 1: Cylindrical, 2: Spherical
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _runMerge() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final res = await AxEngine.stitchPanorama(
        images: widget.inputImages,
        projectionIndex: _projectionIndex,
      );
      if (mounted) {
        widget.onMerged?.call(res);
        Navigator.of(context).pop(res);
      }
    } catch (e, st) {
      axLog(
        LogDomain.engine,
        'Panorama merge failed: $e',
        level: LogLevel.error,
        error: e.toString(),
        stack: st.toString(),
      );
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Panorama Merge',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.inputImages.length} Photos',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Text(
              'Projection Mode',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.xs),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Planar')),
                ButtonSegment(value: 1, label: Text('Cylindrical')),
                ButtonSegment(value: 2, label: Text('Spherical')),
              ],
              selected: {_projectionIndex},
              onSelectionChanged: (selected) {
                setState(() => _projectionIndex = selected.first);
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: Insets.sm),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: Insets.lg),
            FilledButton.icon(
              onPressed: _isProcessing ? null : _runMerge,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.panorama_outlined),
              label: Text(_isProcessing ? 'Stitching…' : 'Merge Panorama'),
            ),
          ],
        ),
      ),
    );
  }
}
