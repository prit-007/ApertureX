import 'dart:typed_data';

import 'package:aperturex/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LinearImage & Linear Pipeline Tests', () {
    test('LinearImage stores width, height, and Float32List data', () {
      final data = Float32List.fromList([0.0, 0.5, 1.0, 1.0]);
      final img = LinearImage(width: 1, height: 1, data: data);
      expect(img.width, 1);
      expect(img.height, 1);
      expect(img.data.length, 4);
      expect(img.data[0], 0.0);
      expect(img.data[1], 0.5);
      expect(img.data[2], 1.0);
      expect(img.data[3], 1.0);
    });
  });
}
