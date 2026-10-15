import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/xmp_preset.dart';

const _xmp = '''
<x:xmpmeta xmlns:x="adobe:ns:meta/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
 <rdf:RDF><rdf:Description
   xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/"
   crs:Exposure2012="+0.50"
   crs:Contrast2012="+20"
   crs:Temperature="5500"
   crs:LensProfileEnable="1"/>
 </rdf:RDF>
</x:xmpmeta>
''';

final _lookBlob = base64.encode(List<int>.generate(12, (i) => i));

final _xmpWithEmbeddedLook = '''
<x:xmpmeta xmlns:x="adobe:ns:meta/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
 <rdf:RDF><rdf:Description
   xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/"
   crs:Exposure2012="+0.50"
   crs:LookName="Vintage Hollywood"
   crs:LookAmount="1.000000"
   crs:LookTable="$_lookBlob"
   crs:ProfileLookTable="$_lookBlob"/>
 </rdf:RDF>
</x:xmpmeta>
''';

const _xmpWithNamedLookOnly = '''
<rdf:Description xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/"
   crs:LookName="Modern 01"/>
''';

void main() {
  final import = parseXmpPreset(_xmp);

  test('applies the mappable settings', () {
    expect(import.recipe.exposure, 0.5);
    expect(import.recipe.contrast, closeTo(0.2, 1e-9));
  });

  test('approximates temperature (absolute Kelvin -> relative)', () {
    expect(import.recipe.temperature, 1.0); // 5500 * 0.0002 clamped to 1
    final note = import.notes.firstWhere((n) => n.setting == 'Temperature');
    expect(note.status, PresetStatus.approximated);
  });

  test('reports unsupported settings and missing ones', () {
    final settings = {for (final n in import.notes) n.setting: n.status};
    expect(settings['LensProfileEnable'], PresetStatus.unsupported);
    expect(settings['Highlights'], PresetStatus.unsupported); // not present
    expect(settings['Exposure'], PresetStatus.applied);
    expect(import.hasUnsupported, isTrue);
  });

  group('embedded / named looks', () {
    test('extracts an embedded look table and marks it approximated', () {
      final withLook = parseXmpPreset(_xmpWithEmbeddedLook);
      expect(withLook.look.kind, PresetLookKind.embedded);
      expect(withLook.look.name, 'Vintage Hollywood');
      expect(withLook.look.tableBytes, 12);
      final note = withLook.notes.firstWhere((n) => n.setting == 'Look');
      expect(note.status, PresetStatus.approximated);
    });

    test('a named look with no table is still approximated', () {
      final named = parseXmpPreset(_xmpWithNamedLookOnly);
      expect(named.look.kind, PresetLookKind.named);
      expect(named.look.name, 'Modern 01');
      expect(named.look.tableBytes, 0);
      final note = named.notes.firstWhere((n) => n.setting == 'Look');
      expect(note.status, PresetStatus.approximated);
    });

    test('a preset without a look reports no look', () {
      expect(import.look.kind, PresetLookKind.none);
      expect(import.notes.any((n) => n.setting == 'Look'), isFalse);
    });
  });
}

