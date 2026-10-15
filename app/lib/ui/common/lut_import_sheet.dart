import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../color/cube_lut.dart';
import '../../color/hald_clut.dart';
import '../../color/imported_lut.dart';
import '../../color/lut_atlas.dart';
import '../../core/log/activity_log.dart';
import '../../core/log/log_providers.dart';
import '../../core/theme/design_tokens.dart';
import 'app_sheet.dart';
import 'lut_export_sheet.dart';

/// Import a preset look by pasting `.cube` text or picking a HALD CLUT PNG.
class LutImportSheet extends ConsumerStatefulWidget {
  const LutImportSheet({super.key});

  @override
  ConsumerState<LutImportSheet> createState() => _LutImportSheetState();
}

class _LutImportSheetState extends ConsumerState<LutImportSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final lut = CubeLut.parseAuto(_controller.text);
      ref
          .read(importedLutProvider.notifier)
          .apply(LutAtlas(size: lut.size, rgba: lut.toAtlasRgba()));
      axLog(LogDomain.preset, 'Applied LUT (${lut.size}³)');
      Navigator.of(context).maybePop();
      messenger.showSnackBar(
        SnackBar(content: Text('Applied LUT (${lut.size}³)')),
      );
    } on FormatException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Invalid LUT: ${e.message}')),
      );
    }
  }

  Future<void> _pickHald() async {
    // file_picker 12+ removed `withData`/`FilePickerResult`: pick a single PNG
    // via the document picker and read its bytes on demand.
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['png'],
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!HaldClut.isHaldPng(bytes)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Not a HALD CLUT PNG (need a square L³ image)'),
        ),
      );
      return;
    }
    try {
      final hald = HaldClut.extract(Uint8List.fromList(bytes));
      ref
          .read(importedLutProvider.notifier)
          .apply(LutAtlas(size: hald.size, rgba: hald.toAtlasRgba()));
      axLog(
        LogDomain.preset,
        'Imported HALD level ${hald.level} · ${hald.size}³',
      );
      Navigator.of(context).maybePop();
      messenger.showSnackBar(
        SnackBar(content: Text('Applied HALD · ${hald.size}³')),
      );
    } on FormatException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Invalid HALD: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(importedLutProvider);
    return AppSheet(
          title: 'Import a LUT',
      subtitle: 'Paste a .cube (1D/3D) or .3dl file, or pick a HALD CLUT PNG.',
      children: [
        TextField(
          controller: _controller,
          maxLines: 6,
          minLines: 4,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: const InputDecoration(hintText: 'Paste .cube / .3dl…'),
        ),
        const SizedBox(height: Insets.md),
        Row(
          children: [
            TextButton(
              onPressed: active == null
                  ? null
                  : () {
                      ref.read(importedLutProvider.notifier).clear();
                      Navigator.of(context).maybePop();
                    },
              child: const Text('Clear'),
            ),
            const SizedBox(width: Insets.xs),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).maybePop();
                showAppSheet(context, const LutExportSheet());
              },
              icon: const Icon(Icons.file_upload, size: 16),
              label: const Text('Export .CUBE'),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: _pickHald,
              child: const Text('Pick HALD PNG'),
            ),
            const SizedBox(width: Insets.sm),
            FilledButton(onPressed: _apply, child: const Text('Apply')),
          ],
        ),
      ],
    );
  }
}
