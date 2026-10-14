import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/muted_parameters.dart';
import 'package:aperturex/edit/parameter.dart';

void main() {
  test('starts empty and toggles parameters in and out', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(mutedParametersProvider.notifier);

    expect(container.read(mutedParametersProvider), isEmpty);

    notifier.toggle(Parameter.exposure);
    expect(container.read(mutedParametersProvider), {Parameter.exposure});
    expect(notifier.isMuted(Parameter.exposure), isTrue);

    // Other parameters are unaffected.
    expect(notifier.isMuted(Parameter.contrast), isFalse);

    // Toggling again unmutes.
    notifier.toggle(Parameter.exposure);
    expect(container.read(mutedParametersProvider), isEmpty);
  });

  test('clear drops every mute', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(mutedParametersProvider.notifier);

    notifier
      ..toggle(Parameter.exposure)
      ..toggle(Parameter.vignette);
    expect(container.read(mutedParametersProvider).length, 2);

    notifier.clear();
    expect(container.read(mutedParametersProvider), isEmpty);
  });
}
