import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/platform/file_saver.dart';

/// Desktop filesystem save (#104): `gal` has no Linux implementation and
/// `file_picker` has no path-only save dialog, so the save flow is split at a
/// [SavePathDialog] seam — the dialog resolves a path, [saveBytesDesktop]
/// owns the write. Testing the seam (not the plugin) keeps these pure host
/// tests: no portal, no platform channels, no GTK.
void main() {
  late Directory tmp;
  final bytes = Uint8List.fromList([0x41, 0x50, 0x58, 0x00, 0xff, 0x42]);

  setUp(() async {
    // Create in setUp, not the test body: fake-async widget environments can
    // deadlock on real IO started inside a zone they don't control.
    tmp = await Directory.systemTemp.createTemp('file_saver_test_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('dialog path → bytes written byte-identically, File carries the name',
      () async {
    final destination = '${tmp.path}/chosen name.png';
    var dialogCalled = false;

    final out = await saveBytesDesktop(
      bytes,
      suggestedName: 'suggested.jpg',
      defaultDirectory: '${tmp.path}/unused',
      dialog: (b, suggestedName) async {
        dialogCalled = true;
        return destination;
      },
    );

    expect(out, isNotNull, reason: 'a chosen path must save, returning the file');
    expect(out!.path, destination, reason: 'the dialog path is the saved path');
    expect(out.readAsBytesSync(), bytes,
        reason: 'round-trip must be byte-identical — re-encoding loses data');
    expect(dialogCalled, isTrue,
        reason: 'dialog seam must be the branch used');
    expect(File('${tmp.path}/unused').existsSync(), isFalse,
        reason: 'defaultDirectory is only a fallback, never the primary target');
  });

  test('dialog passes the suggested name through for the native default',
      () async {
    String? gotName;
    Uint8List? gotBytes;

    await saveBytesDesktop(
      bytes,
      suggestedName: 'aperturex_42.jpg',
      defaultDirectory: tmp.path,
      dialog: (b, suggestedName) async {
        gotBytes = b;
        gotName = suggestedName;
        return '${tmp.path}/aperturex_42.jpg';
      },
    );

    expect(gotName, 'aperturex_42.jpg',
        reason: 'the native dialog must open with the export\'s file name');
    expect(gotBytes, bytes,
        reason: 'file_picker\'s saveFile requires the payload up front '
            '(the Linux/Windows impls write it themselves)');
  });

  test('dialog cancelled → null and nothing written', () async {
    final out = await saveBytesDesktop(
      bytes,
      suggestedName: 'aperturex_7.jpg',
      // Even with a fallback available, a user cancel must abort — writing
      // somewhere the user didn't confirm would break the cancel contract.
      defaultDirectory: '${tmp.path}/Pictures/ApertureX',
      dialog: (b, suggestedName) async => null,
    );

    expect(out, isNull, reason: 'cancel aborts: no file, no error');
    expect(Directory('${tmp.path}/Pictures/ApertureX').existsSync(), isFalse,
        reason: 'cancel must not spill into the fallback directory');
    expect(tmp.listSync(recursive: true), isEmpty,
        reason: 'cancel writes nothing anywhere under the sandbox');
  });

  test('dialog unavailable (MissingPluginException) → default dir fallback '
      'creates ApertureX on demand', () async {
    final defaultDirectory = '${tmp.path}/Pictures/ApertureX';

    final out = await saveBytesDesktop(
      bytes,
      suggestedName: 'headless.jpg',
      defaultDirectory: defaultDirectory,
      dialog: (b, suggestedName) async =>
          throw MissingPluginException('no portal here'),
    );

    expect(out, isNotNull,
        reason: 'a headless run still exports — into the default directory');
    expect(out!.path, '$defaultDirectory/headless.jpg');
    expect(out.readAsBytesSync(), bytes);
    expect(Directory(defaultDirectory).existsSync(), isTrue,
        reason: 'ApertureX/ is created on demand, not assumed to exist');
  });

  test('dialog unimplemented → same fallback (host tests / older plugins)',
      () async {
    final defaultDirectory = '${tmp.path}/fallback';

    final out = await saveBytesDesktop(
      bytes,
      suggestedName: 'no-impl.jpg',
      defaultDirectory: defaultDirectory,
      dialog: (b, suggestedName) async =>
          throw UnimplementedError('saveFile() has not been implemented.'),
    );

    expect(out, isNotNull);
    expect(out!.path, '$defaultDirectory/no-impl.jpg');
    expect(out.readAsBytesSync(), bytes);
  });

  test('fallback uses the caller defaultDirectory, not a baked-in home path',
      () async {
    final defaultDirectory = '${tmp.path}/elsewhere';

    final out = await saveBytesDesktop(
      bytes,
      suggestedName: 'x.jpg',
      defaultDirectory: defaultDirectory,
      dialog: (b, suggestedName) async => throw MissingPluginException(),
    );

    expect(out!.path.startsWith(defaultDirectory), isTrue,
        reason: 'tests must never write into the real ~/Pictures');
  });

  test('savePathDialogProvider defaults to the file_picker adapter', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(savePathDialogProvider), isA<SavePathDialog>());
  });
}
