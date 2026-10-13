import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../color/cube_lut.dart';
import '../../color/imported_lut.dart';
import '../../color/lut_atlas.dart';
import '../../core/theme/design_tokens.dart';
import 'app_sheet.dart';

/// Import a preset look by pasting `.cube` text. (A file picker entry point
/// plugs in here later; pasting keeps the core dependency-free.)
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
      final lut = CubeLut.parse(_controller.text);
      ref
          .read(importedLutProvider.notifier)
          .apply(LutAtlas(size: lut.size, rgba: lut.toAtlasRgba()));
      Navigator.of(context).maybePop();
      messenger.showSnackBar(
        SnackBar(content: Text('Applied LUT (${lut.size}³)')),
      );
    } on FormatException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Invalid .cube: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(importedLutProvider);
    return AppSheet(
      title: 'Import a .cube LUT',
      subtitle: 'Paste the contents of a .cube file to apply it.',
      children: [
        TextField(
          controller: _controller,
          maxLines: 6,
          minLines: 4,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: const InputDecoration(hintText: 'Paste .cube contents…'),
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
            const Spacer(),
            FilledButton(onPressed: _apply, child: const Text('Apply')),
          ],
        ),
      ],
    );
  }
}
