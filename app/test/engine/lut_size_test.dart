import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/color/grade_spec.dart';
import 'package:aperturex/engine/engine.dart';

void main() {
  group('AxEngine.bakeLut3d range assertions', () {
    test('rejects size < 2', () {
      expect(
        () => AxEngine.bakeLut3d(const GradeSpec(), size: 1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects size > 256', () {
      expect(
        () => AxEngine.bakeLut3d(const GradeSpec(), size: 257),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
