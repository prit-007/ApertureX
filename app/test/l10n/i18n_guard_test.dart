import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The 5 tool panels migrated to AppStrings in #164. The guard test verifies
/// none of them regress to bare Text('...') literals.
const _panelFiles = {
  'lib/ui/common/mask_controls.dart',
  'lib/ui/common/geometry_controls.dart',
  'lib/ui/common/retouch_controls.dart',
  'lib/ui/common/blur_controls.dart',
  'lib/ui/common/optics_controls.dart',
};

/// Regex matches simple `Text('...')` literals on a single line — the pattern
/// migrated in #164. Multi-line, dynamic (interpolated), or dynamic Text( calls
/// are not flagged.
final _bareTextRegex = RegExp(r"Text\('\s*[^$#]");

void main() {
  group('i18n guard', () {
    test('no bare Text literals outside AppStrings in #164 panel files', () {
      final violations = <String>[];

      for (final relPath in _panelFiles) {
        final file = File(relPath);
        if (!file.existsSync()) continue;
        final contents = file.readAsStringSync();
        final matches = _bareTextRegex.allMatches(contents);
        for (final m in matches) {
          // Skip if the Text argument already goes through AppStrings
          if (contents.substring(m.start, m.end).contains('AppStrings')) continue;
          violations.add('$relPath:${m.start}: ${m.group(0)}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: '''
Found bare Text('...') literals in #164 panel files that bypass AppStrings i18n.
Migrate each to AppStrings.of(context).xxx.

Violations:
${violations.join('\n')}
''',
      );
    });
  });
}
