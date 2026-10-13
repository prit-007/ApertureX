import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/recipe_controller.dart';
import '../../edit/xmp_preset.dart';

/// Bottom sheet to import a Lightroom `.xmp` preset (best-effort) and show the
/// per-setting compatibility report (ADR 0009).
class XmpImportSheet extends ConsumerStatefulWidget {
  const XmpImportSheet({super.key});

  @override
  ConsumerState<XmpImportSheet> createState() => _XmpImportSheetState();
}

class _XmpImportSheetState extends ConsumerState<XmpImportSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final import = parseXmpPreset(_controller.text);
    ref
        .read(recipeControllerProvider.notifier)
        .loadRecipe(import.recipe, label: 'Preset');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preset compatibility'),
        content: SizedBox(
          width: 320,
          height: 320,
          child: ListView(
            children: [
              for (final note in import.notes)
                ListTile(
                  dense: true,
                  leading: Icon(_icon(note.status), size: 18),
                  title: Text(note.setting),
                  subtitle: note.detail.isEmpty ? null : Text(note.detail),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // dialog
              Navigator.of(this.context).maybePop(); // sheet
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static IconData _icon(PresetStatus s) => switch (s) {
    PresetStatus.applied => Icons.check_circle_outline,
    PresetStatus.approximated => Icons.tune,
    PresetStatus.unsupported => Icons.block,
  };

  @override
  Widget build(BuildContext context) {
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
              'Import a Lightroom .xmp preset',
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
                hintText: 'Paste .xmp contents here…',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _apply, child: const Text('Apply')),
            ),
          ],
        ),
      ),
    );
  }
}
