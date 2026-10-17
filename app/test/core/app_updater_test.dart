import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/core/updater/app_update_model.dart';
import 'package:aperturex/core/updater/app_updater.dart';

void main() {
  group('Version Comparison', () {
    test('correctly identifies newer semantic versions', () {
      expect(AppUpdater.isNewerVersion('v0.2.0', '0.1.0'), isTrue);
      expect(AppUpdater.isNewerVersion('0.1.1', '0.1.0'), isTrue);
      expect(AppUpdater.isNewerVersion('1.0.0', '0.9.9'), isTrue);
      expect(AppUpdater.isNewerVersion('v1.0.1+5', '1.0.0'), isTrue);
    });

    test('correctly identifies older or equal versions as not newer', () {
      expect(AppUpdater.isNewerVersion('0.1.0', '0.1.0'), isFalse);
      expect(AppUpdater.isNewerVersion('v0.1.0', '0.1.0'), isFalse);
      expect(AppUpdater.isNewerVersion('0.0.9', '0.1.0'), isFalse);
      expect(AppUpdater.isNewerVersion('v0.0.1', '0.1.0'), isFalse);
    });
  });

  group('AppReleaseInfo JSON parsing', () {
    test('parses GitHub release response with APK asset', () {
      const jsonStr = '''
      {
        "tag_name": "v0.2.0",
        "name": "ApertureX v0.2.0 - Neural Plugins & Lossless DNG",
        "body": "### Features\\n- Declarative ONNX plugins\\n- Lossless CFA DNG export",
        "html_url": "https://github.com/prit-007/ApertureX/releases/tag/v0.2.0",
        "published_at": "2026-10-17T12:00:00Z",
        "prerelease": false,
        "assets": [
          {
            "name": "aperturex-v0.2.0.apk",
            "size": 42000000,
            "browser_download_url": "https://github.com/prit-007/ApertureX/releases/download/v0.2.0/aperturex-v0.2.0.apk"
          },
          {
            "name": "checksums.txt",
            "size": 512,
            "browser_download_url": "https://github.com/prit-007/ApertureX/releases/download/v0.2.0/checksums.txt"
          }
        ]
      }
      ''';

      final Map<String, dynamic> data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final release = AppReleaseInfo.fromJson(data);

      expect(release.tagName, 'v0.2.0');
      expect(release.version, '0.2.0');
      expect(release.releaseName, 'ApertureX v0.2.0 - Neural Plugins & Lossless DNG');
      expect(release.changelog, contains('Declarative ONNX plugins'));
      expect(release.apkDownloadUrl, 'https://github.com/prit-007/ApertureX/releases/download/v0.2.0/aperturex-v0.2.0.apk');
      expect(release.apkSizeBytes, 42000000);
      expect(release.isPrerelease, isFalse);
    });
  });
}
