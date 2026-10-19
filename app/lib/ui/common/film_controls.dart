import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/parameter.dart';
import 'parameter_control.dart';

/// Film emulation controls: photochemical red halation, multi-pass optical bloom,
/// and physical archival emulsion dust & scratches.
///
/// Organized into collapsible ExpansionTile groups so users can focus on one
/// film effect at a time without cognitive overload.
class FilmControls extends ConsumerWidget {
  const FilmControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        expansionTileTheme: const ExpansionTileThemeData(
          shape: RoundedRectangleBorder(),
          collapsedShape: RoundedRectangleBorder(),
          tilePadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        ),
      ),
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.only(bottom: 12, top: 2),
        children: [
          ExpansionTile(
            initiallyExpanded: true,
            title: _PanelTitle('Halation'),
            children: const [
              _ParamPad(Parameter.filmHalation),
              _ParamPad(Parameter.filmHalationRadius),
              _ParamPad(Parameter.filmHalationThreshold),
            ],
          ),
          ExpansionTile(
            initiallyExpanded: true,
            title: _PanelTitle('Optical Bloom'),
            children: const [
              _ParamPad(Parameter.filmBloom),
              _ParamPad(Parameter.filmBloomRadius),
              _ParamPad(Parameter.filmBloomThreshold),
            ],
          ),
          ExpansionTile(
            initiallyExpanded: true,
            title: _PanelTitle('Film Emulsion'),
            children: const [
              _ParamPad(Parameter.filmDust),
              _ParamPad(Parameter.filmScratches),
            ],
          ),
        ],
      ),
    );
  }
}

/// Uppercase section title used inside FilmControls ExpansionTiles.
class _PanelTitle extends StatelessWidget {
  final String title;
  const _PanelTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
}

/// Pads a ParameterControl with tight 12px horizontal, 2px vertical spacing.
class _ParamPad extends StatelessWidget {
  final Parameter param;
  const _ParamPad(this.param);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ParameterControl(parameter: param),
      );
}
