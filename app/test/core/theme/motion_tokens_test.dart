import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/core/theme/design_tokens.dart';

void main() {
  group('AppMotion', () {
    test('standard duration uses M3 medium2 (800 ms)', () {
      expect(AppMotion.standardDuration, Durations.medium2);
    });

    test('standard curve uses M3 Easing.standard', () {
      expect(AppMotion.standardCurve, Easing.standard);
    });

    test('page enter duration uses M3 medium4 (1200 ms)', () {
      expect(AppMotion.pageDuration, Durations.medium4);
    });

    test('page enter curve uses M3 Easing.emphasizedDecelerate', () {
      expect(AppMotion.pageEnterCurve, Easing.emphasizedDecelerate);
    });

    test('page exit curve uses M3 Easing.emphasizedAccelerate', () {
      expect(AppMotion.pageExitCurve, Easing.emphasizedAccelerate);
    });

    test('fade duration uses M3 short3 (400 ms)', () {
      expect(AppMotion.fadeDuration, Durations.short3);
    });

    test('fade curve uses M3 Easing.standard', () {
      expect(AppMotion.fadeCurve, Easing.standard);
    });

    test('scrub duration uses M3 short2 (250 ms)', () {
      expect(AppMotion.scrubDuration, Durations.short2);
    });

    test('scrub curve uses M3 Easing.standard', () {
      expect(AppMotion.scrubCurve, Easing.standard);
    });

    test('micro duration uses M3 short1 (100 ms) for quick fades', () {
      expect(AppMotion.microDuration, Durations.short1);
    });

    test('short duration uses M3 short2 (250 ms) for scrub HUD', () {
      expect(AppMotion.shortDuration, Durations.short2);
    });

    test('all durations are non-zero and positive', () {
      expect(AppMotion.standardDuration.inMilliseconds, greaterThan(0));
      expect(AppMotion.pageDuration.inMilliseconds, greaterThan(0));
      expect(AppMotion.fadeDuration.inMilliseconds, greaterThan(0));
      expect(AppMotion.scrubDuration.inMilliseconds, greaterThan(0));
    });
  });

  group('Motion (legacy class)', () {
    test('fast uses Durations.short3', () {
      expect(Motion.fast, Durations.short3);
    });

    test('medium uses Durations.medium2', () {
      expect(Motion.medium, Durations.medium2);
    });

    test('slow uses Durations.medium4', () {
      expect(Motion.slow, Durations.medium4);
    });

    test('standard uses Easing.standard', () {
      expect(Motion.standard, Easing.standard);
    });

    test('emphasized uses Easing.emphasizedDecelerate', () {
      expect(Motion.emphasized, Easing.emphasizedDecelerate);
    });
  });
}
