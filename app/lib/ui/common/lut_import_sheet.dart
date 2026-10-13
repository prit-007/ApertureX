import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../color/cube_lut.dart';
import '../../color/imported_lut.dart';
import '../../color/lut_atlas.dart';

/// Bottom sheet to import a preset look by pasting `.cube` text. (A file picker
/// entry point plugs in here later; pasting keeps the core dependency-free.)
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
      messenger.showSnackBar(SnackBar(content: Text('Invalid .cube: ${e.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(importedLutProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Import a .cube LUT',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 6,
              minLines: 4,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste .cube contents here…',
              ),
            ),
            const SizedBox(height: 12),
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
        ),
      ),
    );
  }
}
