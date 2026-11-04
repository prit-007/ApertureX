import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
import '../../l10n/app_strings.dart';
import 'app_primitives.dart';
import 'parameter_control.dart';

/// Optics controls: chromatic aberration removal, defringe, and lens profile corrections.
class OpticsControls extends ConsumerWidget {
  const OpticsControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final notifier = ref.read(recipeControllerProvider.notifier);

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        SectionHeader(AppStrings.of(context).opticsRemoveCA),
        SwitchListTile(
          title: Text(AppStrings.of(context).opticsRemoveCA),
          subtitle: Text(AppStrings.of(context).opticsRemoveCASubtitle),
          value: recipe.removeChromaticAberration,
          onChanged: (val) {
            notifier.setRemoveChromaticAberration(val);
          },
        ),
        const SectionHeader('Defringe (Axial CA)'),
        const ParameterControl(parameter: Parameter.defringePurpleAmount),
        const ParameterControl(parameter: Parameter.defringeGreenAmount),
        SectionHeader(AppStrings.of(context).opticsEnableProfile),
        SwitchListTile(
          title: Text(AppStrings.of(context).opticsEnableProfile),
          subtitle: Text(AppStrings.of(context).opticsProfileSubtitle),
          value: recipe.profileCorrections,
          onChanged: (val) {
            notifier.setProfileCorrections(val);
          },
        ),
        if (recipe.profileCorrections) ...[
          const ParameterControl(parameter: Parameter.profileDistortion),
          const ParameterControl(parameter: Parameter.profileVignetting),
        ],
      ],
    );
  }
}
