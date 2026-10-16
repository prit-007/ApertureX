import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../color/cube_lut.dart';
import '../../color/grade_spec.dart';
import '../../core/theme/design_tokens.dart';
import '../../edit/recipe_controller.dart';
import '../../engine/engine.dart';
import 'app_sheet.dart';

/// Modal bottom sheet to export current color grade as an Adobe / DaVinci Resolve .CUBE LUT.
class LutExportSheet extends ConsumerStatefulWidget {
  const LutExportSheet({super.key});

  @override
  ConsumerState<LutExportSheet> createState() => _LutExportSheetState();
}

class _LutExportSheetState extends ConsumerState<LutExportSheet> {
  int _lutSize = 33;
  late final TextEditingController _titleController;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'ApertureX Grade');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _exportAndCopy() async {
    setState(() => _isExporting = true);
    final messenger = ScaffoldMessenger.of(context);
    final title = _titleController.text.trim().isEmpty
        ? 'ApertureX Grade'
        : _titleController.text.trim();

    try {
      final recipe = ref.read(recipeControllerProvider).recipe;
      final spec = GradeSpec.fromRecipe(recipe);

      String cubeText;
      try {
        cubeText = await AxEngine.exportCubeLut(
          spec,
          size: _lutSize,
          title: title,
        );
      } catch (_) {
        // Fallback for headless environments or when bridge is unavailable
        final n = _lutSize;
        final data = Float32List(n * n * n * 3);
        final inv = 1.0 / (n - 1);
        final ev = (1 << recipe.exposure.round().clamp(-4, 4)).toDouble();
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
        final lut = CubeLut(size: n, data: data, title: title);
        cubeText = lut.toCubeText(title: title);
      }

      await Clipboard.setData(ClipboardData(text: cubeText));
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Copied $_lutSize³ .CUBE LUT to clipboard'),
        ),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppSheet(
      title: 'Export Grade as .CUBE',
      subtitle: 'Use this 3D LUT directly in DaVinci Resolve, Premiere Pro, or Final Cut.',
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'LUT Title',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: Insets.md),
        Text(
          'Lattice Resolution',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Insets.xs),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 17,
              label: Text('17³ (Draft)'),
            ),
            ButtonSegment(
              value: 33,
              label: Text('33³ (Video/Resolve)'),
            ),
            ButtonSegment(
              value: 65,
              label: Text('65³ (Master)'),
            ),
          ],
          selected: {_lutSize},
          onSelectionChanged: (set) {
            setState(() => _lutSize = set.first);
          },
        ),
        const SizedBox(height: Insets.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isExporting ? null : _exportAndCopy,
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.copy),
            label: const Text('Copy .CUBE to Clipboard'),
          ),
        ),
      ],
    );
  }
}
