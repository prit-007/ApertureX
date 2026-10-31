import 'dart:convert';
import 'dart:io';
import 'app_update_model.dart';

/// Client for checking GitHub Releases and downloading OTA updates for ApertureX.
class AppUpdater {
  static const String currentVersion = '0.3.5';
  static const String githubRepo = 'prit-007/ApertureX';

  /// Compares two semantic version strings (e.g., 'v0.2.0' vs '0.1.0').
  /// Returns true if [remote] is strictly higher than [current].
  static bool isNewerVersion(String remote, String current) {
    try {
      final cleanRemote = remote
          .replaceFirst(RegExp(r'^[vV]'), '')
          .split('+')
          .first
          .split('-')
          .first;
      final cleanCurrent = current
          .replaceFirst(RegExp(r'^[vV]'), '')
          .split('+')
          .first
          .split('-')
          .first;

      final remoteParts = cleanRemote.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      final currentParts = cleanCurrent.split('.').map((s) => int.tryParse(s) ?? 0).toList();

      final maxLen = remoteParts.length > currentParts.length ? remoteParts.length : currentParts.length;

      for (var i = 0; i < maxLen; i++) {
        final r = i < remoteParts.length ? remoteParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;

        if (r > c) return true;
        if (r < c) return false;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Checks GitHub Releases API for the latest published release.
  /// Returns [AppReleaseInfo] if a newer version is available, or null if up to date.
  static Future<AppReleaseInfo?> checkForUpdate({
    HttpClient? client,
    String? repoOverride,
  }) async {
    final repo = repoOverride ?? githubRepo;
    final uri = Uri.parse('https://api.github.com/repos/$repo/releases/latest');

    final httpClient = client ?? HttpClient();
    try {
      final request = await httpClient.getUrl(uri);
      request.headers.set('User-Agent', 'ApertureX-App');
      request.headers.set('Accept', 'application/vnd.github.v3+json');

      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final release = AppReleaseInfo.fromJson(json);

      if (isNewerVersion(release.version, currentVersion)) {
        return release;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Streams the APK download to [destinationPath], reporting byte progress.
  static Future<File> downloadApk(
    String url, {
    required String destinationPath,
    void Function(int received, int total)? onProgress,
    HttpClient? client,
  }) async {
    final uri = Uri.parse(url);
    final httpClient = client ?? HttpClient();
    try {
      final request = await httpClient.getUrl(uri);
      request.headers.set('User-Agent', 'ApertureX-App');

      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Download failed with status: ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      var receivedBytes = 0;

      final file = File(destinationPath);
      if (await file.exists()) {
        await file.delete();
      }
      await file.create(recursive: true);

      final sink = file.openWrite();
      await response.forEach((chunk) {
        receivedBytes += chunk.length;
        if (onProgress != null) {
          onProgress(receivedBytes, totalBytes);
        }
        sink.add(chunk);
      });
      await sink.close();

      return file;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}
