import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/parameter.dart';
import 'app_primitives.dart';
import 'parameter_control.dart';

/// Film emulation controls: photochemical red halation, multi-pass optical bloom,
/// and physical archival emulsion dust & scratches.
class FilmControls extends ConsumerWidget {
  const FilmControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.only(bottom: 16),
      children: const [
        SectionHeader('Halation'),
        ParameterControl(parameter: Parameter.filmHalation),
        ParameterControl(parameter: Parameter.filmHalationRadius),
        ParameterControl(parameter: Parameter.filmHalationThreshold),
        SectionHeader('Optical Bloom'),
        ParameterControl(parameter: Parameter.filmBloom),
        ParameterControl(parameter: Parameter.filmBloomRadius),
        ParameterControl(parameter: Parameter.filmBloomThreshold),
        SectionHeader('Film Emulsion'),
        ParameterControl(parameter: Parameter.filmDust),
        ParameterControl(parameter: Parameter.filmScratches),
      ],
    );
  }
}
