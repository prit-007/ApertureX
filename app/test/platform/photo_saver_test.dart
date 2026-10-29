import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/platform/file_saver.dart';
import 'package:aperturex/platform/photo_saver.dart';

/// Branch contract (#104): desktop → filesystem save dialog, never gal;
/// mobile → gal, never the dialog. [GallerySink] is the assertion seam — the
/// real gal has no Linux implementation, so a desktop save that reaches the
/// sink is a bug these fakes catch by recording every call.
class _RecordingSink implements GallerySink {
  int hasAccessCalls = 0;
  int requestAccessCalls = 0;
  bool accessGranted = true;
  final List<(Uint8List bytes, String name)> byteSaves = [];
  final List<String> pathSaves = [];

  @override
  Future<bool> hasAccess() async {
    hasAccessCalls++;
    return accessGranted;
  }

  @override
  Future<bool> requestAccess() async {
    requestAccessCalls++;
    return accessGranted;
  }

  @override
  Future<void> putImageBytes(Uint8List bytes, {required String name}) async {
    byteSaves.add((bytes, name));
  }

  @override
  Future<void> putImage(String path) async {
    pathSaves.add(path);
  }
}

class _RecordingDialog {
  int calls = 0;
  final List<(Uint8List bytes, String suggestedName)> seen = [];
  String? Function(Uint8List bytes, String suggestedName)? onCall;

  Future<String?> call(Uint8List bytes, String suggestedName) async {
    calls++;
    seen.add((bytes, suggestedName));
    return onCall?.call(bytes, suggestedName);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tmp;
  late _RecordingSink sink;
  late _RecordingDialog dialog;

  const bytes = <int>[0x44, 0x4e, 0x47, 0x00, 0x89];

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('photo_saver_test_');
    sink = _RecordingSink();
    dialog = _RecordingDialog();
    // Mobile saveFile resolves a temp dir through path_provider's method
    // channel; point it at this test's sandbox so no real temp dir leaks in.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getTemporaryDirectory') return tmp.path;
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  PhotoSaver saver({required bool isDesktop}) => PhotoSaver(
        isDesktop: isDesktop,
        dialog: dialog.call,
        sink: sink,
      );

  group('saveBytes (JPEG export)', () {
    test('desktop → dialog owns the save, sink untouched', () async {
      dialog.onCall = (b, name) => '${tmp.path}/chosen.jpg';

      final out = await saver(isDesktop: true)
          .saveBytes(Uint8List.fromList(bytes), name: 'aperturex_42');

      expect(dialog.calls, 1, reason: 'desktop save opens the dialog exactly once');
      expect(dialog.seen.single.$2, 'aperturex_42.jpg',
          reason: 'the dialog default name carries the export name + .jpg');
      expect(dialog.seen.single.$1, bytes);
      expect(out, isA<SavedToFile>());
      expect((out! as SavedToFile).file.path, '${tmp.path}/chosen.jpg');
      expect(sink.hasAccessCalls, 0,
          reason: 'gal has no Linux impl — reaching the sink on desktop is the bug');
      expect(sink.byteSaves, isEmpty);
      expect(sink.pathSaves, isEmpty);
    });

    test('desktop cancel → null, sink untouched', () async {
      dialog.onCall = (b, name) => null;

      final out = await saver(isDesktop: true)
          .saveBytes(Uint8List.fromList(bytes), name: 'aperturex_7');

      expect(out, isNull, reason: 'cancel aborts quietly');
      expect(sink.hasAccessCalls, 0);
      expect(sink.byteSaves, isEmpty);
    });

    test('desktopFileName overrides the desktop suggested name', () async {
      // Preset cards keep gal's historical name WITH its extension
      // ('<title>_card.png'); the dialog must open with that exact name
      // instead of stacking a second '.jpg' on top.
      dialog.onCall = (b, name) => '${tmp.path}/card.png';

      await saver(isDesktop: true).saveBytes(
        Uint8List.fromList(bytes),
        name: 'My Look_card.png',
        desktopFileName: 'My Look_card.png',
      );

      expect(dialog.seen.single.$2, 'My Look_card.png');
    });

    test('mobile → gal putImageBytes, dialog untouched', () async {
      final out = await saver(isDesktop: false)
          .saveBytes(Uint8List.fromList(bytes), name: 'aperturex_9');

      expect(out, isA<SavedToGallery>());
      expect(sink.byteSaves, hasLength(1));
      expect(sink.byteSaves.single.$2, 'aperturex_9',
          reason: 'gal takes the name without extension (gal doc contract)');
      expect(sink.byteSaves.single.$1, bytes);
      expect(sink.hasAccessCalls, 1);
      expect(sink.requestAccessCalls, 0, reason: 'already granted → no prompt');
      expect(dialog.calls, 0, reason: 'mobile must never open a file dialog');
    });

    test('mobile requests gallery access first when missing', () async {
      sink.accessGranted = false;

      final out = await saver(isDesktop: false)
          .saveBytes(Uint8List.fromList(bytes), name: 'aperturex_10');

      expect(sink.hasAccessCalls, 1);
      expect(sink.requestAccessCalls, 1,
          reason: 'mirrors the pre-#104 hasAccess → requestAccess flow');
      expect(out, isA<SavedToGallery>(),
          reason: 'denial surfaces later as a gal error, not a silent skip');
      expect(dialog.calls, 0);
    });
  });

  group('saveFile (DNG/TIFF16 export)', () {
    test('desktop → dialog path, no temp file, sink untouched', () async {
      dialog.onCall = (b, name) => '${tmp.path}/lossless.dng';

      final out = await saver(isDesktop: true).saveFile(
        Uint8List.fromList(bytes),
        name: 'aperturex_3',
        extension: 'dng',
      );

      expect(dialog.seen.single.$2, 'aperturex_3.dng');
      expect(out, isA<SavedToFile>());
      expect((out! as SavedToFile).file.path, '${tmp.path}/lossless.dng');
      expect(sink.pathSaves, isEmpty);
      expect(sink.hasAccessCalls, 0);
      expect(
        tmp.listSync(),
        hasLength(1),
        reason: 'desktop must not stage a temp copy — the only file is the '
            'one the dialog path received',
      );
    });

    test('desktop cancel → null', () async {
      dialog.onCall = (b, name) => null;

      final out = await saver(isDesktop: true).saveFile(
        Uint8List.fromList(bytes),
        name: 'aperturex_4',
        extension: 'tiff',
      );

      expect(out, isNull);
      expect(sink.pathSaves, isEmpty);
    });

    test('mobile → temp file staged for gal, dialog untouched', () async {
      final out = await saver(isDesktop: false).saveFile(
        Uint8List.fromList(bytes),
        name: 'aperturex_5',
        extension: 'dng',
      );

      expect(out, isA<SavedToGallery>());
      expect(sink.pathSaves, hasLength(1));
      expect(sink.pathSaves.single, '${tmp.path}/aperturex_5.dng');
      final staged = File(sink.pathSaves.single);
      expect(staged.readAsBytesSync(), bytes,
          reason: 'gal consumes a real file — bytes must round-trip');
      expect(dialog.calls, 0);
    });
  });

  group('providers compose the production saver', () {
    test('photoSaverProvider picks up isDesktop/dialog/sink overrides', () async {
      dialog.onCall = (b, name) => '${tmp.path}/from-container.jpg';
      final container = ProviderContainer(
        overrides: [
          isDesktopPlatformProvider.overrideWithValue(true),
          savePathDialogProvider.overrideWithValue(dialog.call),
          gallerySinkProvider.overrideWithValue(sink),
        ],
      );
      addTearDown(container.dispose);

      final out = await container
          .read(photoSaverProvider)
          .saveBytes(Uint8List.fromList(bytes), name: 'aperturex_11');

      expect(out, isA<SavedToFile>());
      expect(dialog.calls, 1);
      expect(sink.hasAccessCalls, 0,
          reason: 'desktop flag flows through to the branch decision');
    });
  });
}
