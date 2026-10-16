import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Dependency families that would break ApertureX's verifiable 100%-offline
/// claim (#76). Matched as substrings of the *dependency name* (parsed from
/// pubspec.yaml, never from repository URLs in comments), so `http_parser`,
/// `firebase_analytics` or `web_socket_channel` are all caught.
const _forbiddenFamilies = <String>[
  'http',
  'dio',
  'firebase',
  'firestore',
  'analytics',
  'crashlytics',
  'sentry',
  'mixpanel',
  'amplitude',
  'supabase',
  'graphql',
  'web_socket',
  'socket_io',
  'telemetry',
];

/// Packages consciously allowed despite matching [_forbiddenFamilies].
/// Adding an entry requires a written justification — that is the "until
/// consciously whitelisted" part of the claim.
const _whitelist = <String, String>{
  // 'example_package': 'why this network use is acceptable',
};

/// True when [name] is a dependency family the offline claim forbids.
bool isForbiddenDependency(String name) {
  final lower = name.toLowerCase();
  if (_whitelist.containsKey(lower)) return false;
  return _forbiddenFamilies.any(lower.contains);
}

/// Dependency *names* from the `dependencies`, `dev_dependencies` and
/// `dependency_overrides` sections of a pubspec (section-scoped, comments and
/// blank lines ignored, so repository URLs or prose in comments can never
/// trip the guard).
Set<String> dependencyNames(String pubspec) {
  final names = <String>{};
  var inDependencySection = false;
  for (final rawLine in pubspec.split('\n')) {
    if (rawLine.trimLeft().startsWith('#')) continue;
    final line = rawLine.split('#').first;
    if (line.trim().isEmpty) continue;
    if (!line.startsWith(' ')) {
      // Column-0 key: opens a dependency section or ends the previous one.
      inDependencySection =
          line == 'dependencies:' ||
          line == 'dev_dependencies:' ||
          line == 'dependency_overrides:';
      continue;
    }
    if (!inDependencySection) continue;
    final match = RegExp(r'^\s+([A-Za-z0-9_-]+):').firstMatch(line);
    if (match != null) names.add(match.group(1)!);
  }
  return names;
}

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  group('offline dependency guard (#76)', () {
    test('the parser reads both dependencies and dev_dependencies', () {
      final names = dependencyNames(pubspec);
      expect(names, contains('flutter_riverpod'));
      expect(names, contains('flutter_test'));
      expect(names.length, greaterThan(10));
      // Section scoping: repository/commit URLs in comments are not names.
      expect(names.where((n) => n.contains('://')), isEmpty);
    });

    test('every forbidden family is enumerated and caught', () {
      const samples = [
        'http',
        'http_parser',
        'dio',
        'firebase_core',
        'firebase_analytics',
        'cloud_firestore',
        'sentry_flutter',
        'web_socket_channel',
        'socket_io_client',
        'supabase_flutter',
        'graphql_client',
        'mixpanel_flutter',
      ];
      for (final sample in samples) {
        expect(
          isForbiddenDependency(sample),
          isTrue,
          reason: '$sample must trip the offline guard',
        );
      }
    });

    test('benign packages and whitelisted ones pass', () {
      const benign = [
        'flutter',
        'flutter_test',
        'flutter_riverpod',
        'path_provider',
        'photo_manager',
        'shared_preferences',
        'share_plus',
        'cupertino_icons',
        'material_ui',
        'rust_lib_aperturex',
      ];
      for (final name in benign) {
        expect(
          isForbiddenDependency(name),
          isFalse,
          reason: '$name is not a network package',
        );
      }
      // Whitelist is consulted before the family match.
      expect(_whitelist.containsKey('path_provider'), isFalse);
    });

    test('pubspec declares no network or analytics packages', () {
      final offenders =
          dependencyNames(pubspec).where(isForbiddenDependency).toList();
      expect(
        offenders,
        isEmpty,
        reason:
            'The 100%-offline claim is violated by: $offenders. '
            'Remove them or consciously whitelist in offline_guard_test.dart.',
      );
    });
  });
}
