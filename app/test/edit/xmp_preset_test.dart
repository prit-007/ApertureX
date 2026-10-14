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
}
