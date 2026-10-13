import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/recipe_controller.dart';
import '../../edit/tool_definition.dart';

/// The tool gallery: apply a built-in look, or import a shared look (JSON).
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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Looks',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final tool in ToolLibrary.builtins)
                    ListTile(
                      leading: const Icon(Icons.auto_fix_high),
                      title: Text(tool.name),
                      subtitle: Text(tool.description),
                      onTap: () => _apply(tool),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    maxLines: 3,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Paste a shared look (JSON)…',
                      errorText: _importError,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _import,
                      child: const Text('Import look'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
