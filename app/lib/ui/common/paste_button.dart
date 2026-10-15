import 'package:flutter/services.dart' show Clipboard;
import 'package:material_ui/material_ui.dart';

/// One-tap "fill from clipboard" for the import text fields — removes the
/// tap → long-press → Paste → dismiss-keyboard dance from the preset flows.
class PasteButton extends StatelessWidget {
  const PasteButton({super.key, required this.controller, this.onPasted});

  final TextEditingController controller;
  final VoidCallback? onPasted;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.content_paste),
      tooltip: 'Paste from clipboard',
      onPressed: () async {
        try {
          final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
          if (text == null || text.isEmpty) return;
          controller.text = text;
          onPasted?.call();
        } catch (_) {
          // Clipboard failures must never break the field.
        }
      },
    );
  }
}
