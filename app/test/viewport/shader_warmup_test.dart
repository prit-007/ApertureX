import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/viewport/shader_warmup.dart';

void main() {
  group('ShaderWarmup', () {
    test('kicks off exactly once, even when called concurrently', () async {
      var calls = 0;
      final warmup = ShaderWarmup(warm: () async => calls++);

      await Future.wait([warmup(), warmup(), warmup()]);

      expect(calls, 1);
    });

    // End-to-end guard for the uniform/sampler contract of BOTH declared
    // programs: the rasterize step throws if a slot is left unset (the same
    // validation the engine applies on the first editor frame).
    test('the real warmup rasterizes both declared programs', () async {
      await ShaderWarmup()();
    });
  });

  testWidgets(
    'bootstrap kicks the warmup before the first frame, and the editor '
    'program load follows it',
    (tester) async {
      final log = <String>[];
      final warmup = ShaderWarmup(warm: () async => log.add('warmup'));

      final scope = bootstrapApp(
        warmup: warmup,
        overrides: [
          lutProgramProvider.overrideWith((ref) async {
            log.add('editor-load');
            return warmup.lutProgram();
          }),
        ],
        child: const SizedBox(),
      );
      // Kicked during bootstrap — before anything was pumped, i.e. before
      // the first frame ever renders.
      expect(log, ['warmup']);

      await tester.pumpWidget(scope);
      expect(log, ['warmup']);

      // The editor's shared program request lands after the warmup kick.
      final context = tester.element(find.byType(SizedBox));
      final container = ProviderScope.containerOf(context, listen: false);
      await container.read(lutProgramProvider.future);
      expect(log, ['warmup', 'editor-load']);
    },
  );
}
