import 'package:aperturex/engine/preview_texture.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Frame notification for zero-copy delivery (spike B).
///
/// On Android the embedding observes the SurfaceProducer's buffer queue
/// itself, but a raw `CVPixelBuffer` on iOS is silent: the engine only
/// re-samples `copyPixelBuffer` after `textureFrameAvailable`. Dart must
/// therefore poke the registry after every `previewRender` that wrote into
/// the bound buffer — these tests pin that bridge method.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('aperturex/preview_texture');
  final log = <MethodCall>[];

  void mockHandler(Future<Object?>? Function(MethodCall call)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  tearDown(() {
    log.clear();
    mockHandler(null);
  });

  test('frameAvailable notifies the registry with the texture id', () async {
    mockHandler((call) async {
      log.add(call);
      return null;
    });

    await PreviewTextureChannel.frameAvailable(42);

    expect(log, hasLength(1));
    expect(log.single.method, 'frameAvailable');
    expect(log.single.arguments, {'textureId': 42});
  });

  test('frameAvailable completes when no platform plugin is installed', () async {
    // Widget tests / desktop: no handler -> MissingPluginException, which
    // must not propagate into the viewport's render loop.
    mockHandler(null);

    await expectLater(PreviewTextureChannel.frameAvailable(7), completes);
  });

  test('frameAvailable swallows platform errors', () async {
    mockHandler((call) async {
      throw PlatformException(code: 'bad_args', message: 'nope');
    });

    await expectLater(PreviewTextureChannel.frameAvailable(7), completes);
  });
}
