import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Desktop scaffold + branding contract (issue #102).
///
/// Why: `flutter create` seeds runner files with `com.example.*` bundle ids
/// and lowercase template titles, and regenerating the scaffold (or losing a
/// platform dir) would silently break the three desktop builds plus the Inno
/// installer (#105) that packages the Windows one. These are pure
/// file-content checks — no platform channels — so `flutter test` on the
/// Linux CI runner guards Windows/macOS assets too.
void main() {
  group('platform runners exist', () {
    for (final path in [
      // Windows
      'windows/CMakeLists.txt',
      'windows/runner/CMakeLists.txt',
      'windows/runner/main.cpp',
      'windows/runner/Runner.rc',
      'windows/runner/resources/app_icon.ico',
      // Linux
      'linux/CMakeLists.txt',
      'linux/runner/CMakeLists.txt',
      'linux/runner/main.cc',
      'linux/runner/my_application.cc',
      'linux/runner/icon.png',
      // macOS (no Podfile in the 3.44 template — CocoaPods state is
      // generated lazily during `flutter build macos`, as in nook):
      'macos/Runner/MainFlutterWindow.swift',
      'macos/Runner/Configs/AppInfo.xcconfig',
      'macos/Runner/Info.plist',
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
    ]) {
      test('$path is present and non-empty', () {
        final file = File(path);
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'missing $path — run flutter create --platforms=windows,linux,macos',
        );
        expect(file.lengthSync(), greaterThan(0), reason: '$path is empty');
      });
    }
  });

  group('branding', () {
    test('Linux APPLICATION_ID matches the mobile applicationId', () {
      final cmake = File('linux/CMakeLists.txt').readAsStringSync();
      expect(
        cmake,
        contains('set(APPLICATION_ID "com.devparadise.aperturex")'),
        reason:
            'Linux GTK app id must match Android applicationId '
            '(com.devparadise.aperturex) — ADR/issue #102 branding',
      );
    });

    test('Linux window title is ApertureX', () {
      final app = File('linux/runner/my_application.cc').readAsStringSync();
      expect(app, contains('gtk_window_set_title'));
      expect(
        app,
        contains('"ApertureX"'),
        reason:
            'taskbar/window title must read ApertureX, not the '
            'lowercase template name',
      );
    });

    test('macOS bundle id matches the mobile applicationId', () {
      final xcconfig = File(
        'macos/Runner/Configs/AppInfo.xcconfig',
      ).readAsStringSync();
      expect(
        xcconfig,
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.devparadise.aperturex'),
      );
    });

    test('macOS display name is ApertureX', () {
      final plist = File('macos/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('<key>CFBundleDisplayName</key>'));
      expect(plist, contains('<string>ApertureX</string>'));
    });

    test('Windows version resource brands ApertureX', () {
      final rc = File('windows/runner/Runner.rc').readAsStringSync();
      expect(rc, contains('VALUE "FileDescription", "ApertureX"'));
      expect(rc, contains('VALUE "ProductName", "ApertureX"'));
      // InternalName/OriginalFilename keep aperturex(.exe): they must match
      // the on-disk binary name (BINARY_NAME), not the display brand.
      expect(rc, contains('"aperturex.exe"'));
    });

    test('Windows window title is ApertureX', () {
      final main = File('windows/runner/main.cpp').readAsStringSync();
      expect(
        main,
        contains('ApertureX'),
        reason: 'CreateWindow/title string must read ApertureX',
      );
    });
  });

  group('icons generated from the 1024px masters', () {
    test('pubspec wires flutter_launcher_icons for windows + macos', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec,
        matches(RegExp(r'windows:\s*\n\s+generate:\s*true')),
        reason:
            'windows: generate: true must be added to '
            'flutter_launcher_icons (#102)',
      );
      expect(
        pubspec,
        matches(RegExp(r'macos:\s*\n\s+generate:\s*true')),
        reason:
            'macos: generate: true must be added to '
            'flutter_launcher_icons (#102)',
      );
    });

    test('Windows .ico is a real multi-size icon', () {
      final ico = File('windows/runner/resources/app_icon.ico');
      expect(ico.existsSync(), isTrue);
      // Flutter's default placeholder is a tiny stub; a generated multi-size
      // ico from the 1024 master is well above this floor.
      expect(
        ico.lengthSync(),
        greaterThan(10 * 1024),
        reason: 'run: dart run flutter_launcher_icons',
      );
    });

    test('Linux window icon is a real PNG', () {
      final icon = File('linux/runner/icon.png');
      expect(
        icon.existsSync(),
        isTrue,
        reason: 'copy the master to linux/runner/icon.png',
      );
      expect(icon.lengthSync(), greaterThan(10 * 1024));
      // PNG magic bytes — guards against a stray text/placeholder file.
      expect(icon.readAsBytesSync().sublist(0, 8), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
    });

    test(
      'macOS appiconset: every slot points at a real PNG (incl. 1024px)',
      () {
        final dir = Directory(
          'macos/Runner/Assets.xcassets/AppIcon.appiconset',
        );
        final files = dir
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .toSet();
        final json =
            jsonDecode(File('${dir.path}/Contents.json').readAsStringSync())
                as Map<String, dynamic>;
        final images = (json['images'] as List).cast<Map<String, dynamic>>();
        // The 10-slot matrix (16..512 @1x/@2x) shares PNGs, so a file-count
        // check alone would under-count — assert the matrix instead.
        expect(images.length, greaterThanOrEqualTo(10));
        for (final slot in images) {
          final name = slot['filename'] as String?;
          expect(
            name,
            isNotNull,
            reason: 'slot ${slot['size']}/${slot['scale']}',
          );
          expect(
            files,
            contains(name),
            reason: '$name missing from appiconset',
          );
        }
        expect(
          files,
          contains('app_icon_1024.png'),
          reason: 'a 1024px PNG must exist for the macOS icon slot',
        );
      },
    );
  });

  group('generated runner state stays out of git', () {
    test('.gitignore covers flutter desktop ephemeral dirs', () {
      final ignore = File('.gitignore').readAsStringSync();
      expect(
        ignore,
        contains('ephemeral'),
        reason:
            'windows/linux/macos flutter/ephemeral CMake state is '
            'machine-generated — flutter create seeds it, commit only '
            'the .gitignore rule',
      );
    });
  });
}
