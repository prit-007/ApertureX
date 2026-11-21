import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/log/activity_log.dart';
import '../../core/log/log_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../engine/engine.dart';

/// Interactive bottom sheet for content-aware canvas expansion.
class ExpandCanvasSheet extends ConsumerStatefulWidget {
  const ExpandCanvasSheet({
    super.key,
    required this.rgba,
    required this.width,
    required this.height,
    this.onExpanded,
  });

  final Uint8List rgba;
  final int width;
  final int height;
  final void Function(Uint8List expandedRgba, int newWidth, int newHeight)?
      onExpanded;

  @override
  ConsumerState<ExpandCanvasSheet> createState() => _ExpandCanvasSheetState();
}

class _ExpandCanvasSheetState extends ConsumerState<ExpandCanvasSheet> {
  int _modeIndex = 0; // 0: Smart, 1: White, 2: Black, 3: Reflect
  double _paddingPercent = 15.0; // 0 to 50%
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _apply() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final padW = (widget.width * (_paddingPercent / 100.0)).round();
      final padH = (widget.height * (_paddingPercent / 100.0)).round();

      final out = await AxEngine.expandCanvas(
        rgba: widget.rgba,
        width: widget.width,
        height: widget.height,
        padLeft: padW,
        padTop: padH,
        padRight: padW,
        padBottom: padH,
        mode: _modeIndex,
      );

      final newW = widget.width + padW * 2;
      final newH = widget.height + padH * 2;

      if (mounted) {
        widget.onExpanded?.call(out, newW, newH);
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      axLog(
        LogDomain.engine,
        'Expand canvas failed: $e',
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
                  'Expand Canvas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.width} × ${widget.height}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Text(
              'Expansion Mode',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.xs),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Smart')),
                ButtonSegment(value: 1, label: Text('White')),
                ButtonSegment(value: 2, label: Text('Black')),
                ButtonSegment(value: 3, label: Text('Reflect')),
              ],
              selected: {_modeIndex},
              onSelectionChanged: (selected) {
                setState(() => _modeIndex = selected.first);
              },
            ),
            const SizedBox(height: Insets.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Margin Size (${_paddingPercent.toStringAsFixed(0)}%)',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Slider(
                    value: _paddingPercent,
                    min: 5.0,
                    max: 50.0,
                    divisions: 9,
                    onChanged: (v) => setState(() => _paddingPercent = v),
                  ),
                ),
              ],
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
            const SizedBox(height: Insets.md),
            FilledButton.icon(
              onPressed: _isProcessing ? null : _apply,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.aspect_ratio_outlined),
              label: Text(_isProcessing ? 'Expanding…' : 'Expand Canvas'),
            ),
          ],
        ),
      ),
    );
  }
}
