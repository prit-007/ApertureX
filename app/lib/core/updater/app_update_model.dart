/// Status of the OTA update pipeline.
enum UpdateStatus {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  downloaded,
  error,
}

/// Release metadata retrieved from GitHub Releases API.
class AppReleaseInfo {

  const AppReleaseInfo({
    required this.tagName,
    required this.version,
    required this.releaseName,
    required this.changelog,
    required this.htmlUrl,
    required this.apkDownloadUrl,
    required this.apkSizeBytes,
    required this.publishedAt,
    required this.isPrerelease,
  });

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? '';
    final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
    final releaseName = json['name'] as String? ?? tagName;
    final changelog = json['body'] as String? ?? '';
    final htmlUrl = json['html_url'] as String? ?? '';
    final isPrerelease = json['prerelease'] as bool? ?? false;
    final publishedStr = json['published_at'] as String?;
    final publishedAt = publishedStr != null
        ? DateTime.tryParse(publishedStr) ?? DateTime.now()
        : DateTime.now();

    String? apkUrl;
    int? apkSize;

    final assets = json['assets'] as List<dynamic>?;
    if (assets != null) {
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          if (name.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String?;
            apkSize = asset['size'] as int?;
            break;
          }
        }
      }
    }

    return AppReleaseInfo(
      tagName: tagName,
      version: version,
      releaseName: releaseName,
      changelog: changelog,
      htmlUrl: htmlUrl,
      apkDownloadUrl: apkUrl,
      apkSizeBytes: apkSize,
      publishedAt: publishedAt,
      isPrerelease: isPrerelease,
    );
  }
  final String tagName;
  final String version;
  final String releaseName;
  final String changelog;
  final String htmlUrl;
  final String? apkDownloadUrl;
  final int? apkSizeBytes;
  final DateTime publishedAt;
  final bool isPrerelease;
}
