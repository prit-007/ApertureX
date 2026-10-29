import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// photo_manager guard audit (#104): the plugin ships android/ios/macos
/// implementations only, so any *code* use outside the desktop-swappable
/// gallery source would throw MissingPluginException on a Linux/Windows
/// desktop. Comments may mention the package; imports and `PhotoManager.`
/// calls may only live in `gallery/photo_gallery_source.dart` (#103 owns
/// swapping that source out on desktop).
void main() {
  test('PhotoManager imports and calls stay in photo_gallery_source.dart', () {
    const allowed = 'gallery/photo_gallery_source.dart';
    final usage = RegExp(r"import 'package:photo_manager|\bPhotoManager\.");
    final offenders = <String>[];

    for (final entry in Directory('lib').listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      final rel = entry.path.replaceAll('\\', '/');
      final fromLib = rel.substring(rel.indexOf('lib/') + 4);
      if (usage.hasMatch(entry.readAsStringSync())) {
        if (fromLib != allowed) offenders.add(fromLib);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'photo_manager must stay behind the desktop-swappable source; '
          'move these call sites to a GallerySource/PhotoSaver seam (#104)',
    );
    // Sanity: the fence actually sees the one legitimate user.
    expect(
      File('lib/$allowed').readAsStringSync(),
      matches(usage),
      reason: 'guard would pass vacuously if the pattern matched nothing',
    );
  });
}
