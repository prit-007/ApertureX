import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/log/activity_log.dart';
import '../../core/log/log_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/tool_definition.dart';
import 'app_sheet.dart';

/// The look gallery: apply a built-in look, or import a shared look (JSON).
class LooksSheet extends ConsumerStatefulWidget {
  const LooksSheet({super.key});

  @override
  ConsumerState<LooksSheet> createState() => _LooksSheetState();
}

class _LooksSheetState extends ConsumerState<LooksSheet> {
  final _controller = TextEditingController();
  String? _importError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply(ToolDefinition tool) {
    ref.read(recipeControllerProvider.notifier).applyTool(tool);
    ref.read(recipeControllerProvider.notifier).commit(label: tool.name);
    axLog(LogDomain.preset, 'Applied look "${tool.name}"');
    Navigator.of(context).maybePop();
  }

  void _import() {
    try {
      final tool = ToolDefinition.decode(_controller.text);
      setState(() => _importError = null);
      _apply(tool);
    } on FormatException catch (e) {
      setState(() => _importError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'Looks',
      subtitle: 'One-tap grades — or paste a look someone shared with you.',
      children: [
        for (final tool in ToolLibrary.builtins)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.auto_fix_high),
            title: Text(tool.name),
            subtitle: Text(tool.description),
            onTap: () => _apply(tool),
          ),
        const SizedBox(height: Insets.lg),
        TextField(
          controller: _controller,
          maxLines: 3,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Paste a shared look (JSON)…',
            errorText: _importError,
          ),
        ),
        const SizedBox(height: Insets.md),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _import,
            child: const Text('Import look'),
          ),
        ),
      ],
    );
  }
}
