import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'parameter.dart';

/// Parameters bypassed in the live preview ("tap-to-mute", issue #31).
///
/// A mute is a temporary A/B, not an edit: the recipe keeps the stored value
/// and only the render skips it (like Lightroom's Alt-preview). Export is
/// unaffected, so preview-mute never leaks into a saved file.
class MutedParameters extends Notifier<Set<Parameter>> {
  @override
  Set<Parameter> build() => const <Parameter>{};

  bool isMuted(Parameter parameter) => state.contains(parameter);

  void toggle(Parameter parameter) {
    final next = Set<Parameter>.of(state);
    if (!next.remove(parameter)) next.add(parameter);
    state = Set<Parameter>.unmodifiable(next);
  }

  void clear() => state = const <Parameter>{};
}

final mutedParametersProvider = NotifierProvider<MutedParameters, Set<Parameter>>(
  MutedParameters.new,
);
