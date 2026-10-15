import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/viewport/roi_decoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('aperturex/roi_decode');

  /// A 12 MP source (4000x3000, 48 MiB RGBA) and a 24 MP source
  /// (6000x4000, 96 MiB RGBA).
  const smallW = 4000, smallH = 3000;
  const bigW = 6000, bigH = 4000;

  Uint8List fakeRgba(int w, int h) => Uint8List(w * h * 4);

  RoiBand band(int w, int h) => RoiBand(width: w, height: h, rgba: fakeRgba(w, h));

  group('needsNativeRoiDecoder (tier probe)', () {
    test('keeps small frames on the in-process Rust path', () {
      expect(needsNativeRoiDecoder(smallW, smallH), isFalse);
    });

    test('routes large frames to the platform region decoder', () {
      expect(needsNativeRoiDecoder(bigW, bigH), isTrue);
      expect(needsNativeRoiDecoder(12000, 9000), isTrue); // >100 MP
    });
  });

  group('RoiDecoder.decodeBand', () {
    late List<MethodCall> calls;
    RoiBand? nativeResult;
    Object? nativeError;
    int rustCalls = 0;

    late RoiDecoder decoder;

    setUp(() {
      calls = <MethodCall>[];
      nativeResult = null;
      nativeError = null;
      rustCalls = 0;
      decoder = RoiDecoder(
        rustFallback: ({
          required Uint8List bytes,
          required int x,
          required int y,
          required int width,
          required int height,
        }) async {
          rustCalls++;
          return band(width, height);
        },
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            final err = nativeError;
            if (err != null) throw err;
            return nativeResult == null
                ? null
                : <String, Object?>{
                    'width': nativeResult!.width,
                    'height': nativeResult!.height,
                    'rgba': nativeResult!.rgba,
                  };
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('uses the platform region decoder for large frames', () async {
      nativeResult = band(6000, 500);
      final out = await decoder.decodeBand(
        bytes: Uint8List(8),
        imageW: bigW,
        imageH: bigH,
        bandTop: 250,
        bandBottom: 750,
      );
      expect(out, isNotNull);
      expect(out!.width, 6000);
      expect(out.height, 500);
      expect(rustCalls, 0);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'decodeBand');
      expect(calls.single.arguments, <String, Object?>{
        'jpeg': Uint8List(8),
        'x': 0,
        'y': 250,
        'width': 6000,
        'height': 500,
      });
    });

    test('falls back to the Rust decoder when the platform fails', () async {
      nativeError = PlatformException(code: 'decode');
      final out = await decoder.decodeBand(
        bytes: Uint8List(4),
        imageW: bigW,
        imageH: bigH,
        bandTop: 10,
        bandBottom: 20,
      );
      expect(out, isNotNull);
      expect(rustCalls, 1);
      expect(out!.width, bigW);
      expect(out.height, 10);
    });

    test('falls back to the Rust decoder when no plugin is registered',
        () async {
      // No mock handler → MissingPluginException (iOS, widget tests).
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      final out = await decoder.decodeBand(
        bytes: Uint8List(4),
        imageW: bigW,
        imageH: bigH,
        bandTop: 0,
        bandBottom: 8,
      );
      expect(out, isNotNull);
      expect(rustCalls, 1);
    });

    test('small frames skip the platform channel entirely', () async {
      final out = await decoder.decodeBand(
        bytes: Uint8List(4),
        imageW: smallW,
        imageH: smallH,
        bandTop: 100,
        bandBottom: 200,
      );
      expect(out, isNotNull);
      expect(calls, isEmpty);
      expect(rustCalls, 1);
      // Rust fallback got the band rect verbatim.
      expect(out!.width, smallW);
      expect(out.height, 100);
    });

    test('rejects invalid bands without decoding', () async {
      expect(
        await decoder.decodeBand(
          bytes: Uint8List(4),
          imageW: smallW,
          imageH: smallH,
          bandTop: 100,
          bandBottom: 100,
        ),
        isNull,
      );
      expect(
        await decoder.decodeBand(
          bytes: Uint8List(4),
          imageW: smallW,
          imageH: smallH,
          bandTop: -1,
          bandBottom: 50000,
        ),
        isNull,
      );
      expect(calls, isEmpty);
      expect(rustCalls, 0);
    });
  });
}
