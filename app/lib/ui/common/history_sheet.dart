import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/recipe_controller.dart';
import 'app_sheet.dart';

/// The branchable history: every commit as a named node. Tapping a node jumps
/// to it; a subsequent edit branches from there (ADR 0011).
class HistorySheet extends ConsumerWidget {
  const HistorySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recipeControllerProvider);
    final notifier = ref.read(recipeControllerProvider.notifier);

    return AppSheet(
      title: 'History',
      subtitle:
          'Tap any step to jump back. Editing from there starts a new branch.',
      scrollable: false,
      children: [
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: state.history.length,
            itemBuilder: (context, i) {
              final current = i == state.index;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                selected: current,
                leading: Icon(
                  current ? Icons.radio_button_checked : Icons.circle_outlined,
                  size: 18,
                ),
                title: Text(
                  state.history[i].label,
                  style: TextStyle(
                    fontWeight: current ? FontWeight.w600 : FontWeight.w400,
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
    );
  }
}
