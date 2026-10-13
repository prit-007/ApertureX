import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/recipe_controller.dart';

/// The branchable history: every commit as a named node. Tapping a node jumps
/// to it; a subsequent edit branches from there (ADR 0011).
class HistorySheet extends ConsumerWidget {
  const HistorySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recipeControllerProvider);
    final notifier = ref.read(recipeControllerProvider.notifier);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'History',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: state.history.length,
              itemBuilder: (context, i) {
                final current = i == state.index;
                return ListTile(
                  dense: true,
                  selected: current,
                  leading: Icon(
                    current ? Icons.radio_button_checked : Icons.circle_outlined,
                    size: 16,
                    color: current ? Colors.white : Colors.white38,
                  ),
                  title: Text(
                    state.history[i].label,
                    style: TextStyle(
                      color: current ? Colors.white : Colors.white70,
                    ),
                  ),
                  onTap: () {
                    notifier.jumpTo(i);
                    Navigator.of(context).maybePop();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
