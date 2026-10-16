import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/log/activity_log.dart';
import '../../core/log/log_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../edit/lrtemplate_preset.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/xmp_preset.dart';
import 'app_sheet.dart';
import 'paste_button.dart';

/// Import a Lightroom `.xmp` or `.lrtemplate` preset (best-effort) and show the
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
    final text = _controller.text.trim();
    final isLrtemplate = text.startsWith('s =') ||
        text.startsWith('return {') ||
        (!text.startsWith('<') && text.contains('settings'));
    final import =
        isLrtemplate ? parseLrtemplatePreset(text) : parseXmpPreset(text);
    ref
        .read(recipeControllerProvider.notifier)
        .loadRecipe(import.recipe, label: 'Preset');
    axLog(
      LogDomain.preset,
      'Imported ${isLrtemplate ? ".lrtemplate" : ".xmp"} preset (${import.notes.length} settings)',
    );
    // Thumb-zone report sheet (ADR-consistent AppSheet), not a centred
    // dialog: the user's thumb is already at the bottom of the screen.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => AppSheet(
        title: 'Preset compatibility',
        maxHeightFactor: 0.6,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // report sheet
              Navigator.of(this.context).maybePop(); // import sheet
            },
            child: const Text('OK'),
          ),
        ],
        children: [
          if (import.notes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Insets.lg),
              child: Center(child: Text('Nothing to import.')),
            )
          else
            for (final note in import.notes)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(_icon(note.status), size: 18),
                title: Text(note.setting),
                subtitle: note.detail.isEmpty ? null : Text(note.detail),
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
      title: 'Import a preset (.xmp or .lrtemplate)',
      subtitle: 'Paste the preset contents; you’ll see what mapped cleanly.',
      children: [
        TextField(
          controller: _controller,
          maxLines: 6,
          minLines: 4,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Paste .xmp or .lrtemplate contents…',
            suffixIcon: PasteButton(controller: _controller),
          ),
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
