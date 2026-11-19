import 'package:aperturex/platform/intent_handler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('aperturex/incoming_intent');
  final log = <MethodCall>[];

  void mockHandler(Future<Object?>? Function(MethodCall call)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  tearDown(() {
    log.clear();
    mockHandler(null);
  });

  group('IntentHandler', () {
    test('fetches cold-start initial image when available', () async {
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4]);
      mockHandler((call) async {
        log.add(call);
        if (call.method == 'getInitialImage') {
          return sampleBytes;
        }
        return null;
      });

      final handler = IntentHandler(channel: channel);
      final initial = await handler.init();

      expect(log, hasLength(1));
      expect(log.single.method, 'getInitialImage');
      expect(initial, sampleBytes);
      handler.dispose();
    });

    test('listens for live incoming images on onImageReceived stream', () async {
      mockHandler((call) async {
        if (call.method == 'getInitialImage') return null;
        return null;
      });

      final handler = IntentHandler(channel: channel);
      await handler.init();

      final received = <Uint8List>[];
      final sub = handler.onImageReceived.listen(received.add);

      // Simulate native platform sending onImageReceived
      final payload = Uint8List.fromList([9, 8, 7]);
      final binaryMessenger = TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger;
      await binaryMessenger.handlePlatformMessage(
        'aperturex/incoming_intent',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('onImageReceived', payload),
        ),
        (data) {},
      );

      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.single, payload);

      await sub.cancel();
      handler.dispose();
    });
  });
}
