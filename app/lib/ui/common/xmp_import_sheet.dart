import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/xmp_preset.dart';
import 'app_sheet.dart';

/// Import a Lightroom `.xmp` preset (best-effort) and show the per-setting
/// compatibility report (ADR 0009).
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
          child: import.notes.isEmpty
              ? const Center(child: Text('Nothing to import.'))
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final note in import.notes)
                      ListTile(
                        dense: true,
                        leading: Icon(_icon(note.status), size: 18),
                        title: Text(note.setting),
                        subtitle: note.detail.isEmpty
                            ? null
                            : Text(note.detail),
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
    return AppSheet(
      title: 'Import a Lightroom .xmp preset',
      subtitle: 'Paste the preset contents; you’ll see what mapped cleanly.',
      children: [
        TextField(
          controller: _controller,
          maxLines: 6,
          minLines: 4,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: const InputDecoration(hintText: 'Paste .xmp contents…'),
        ),
        const SizedBox(height: Insets.md),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(onPressed: _apply, child: const Text('Apply')),
        ),
      ],
    );
  }
}
