import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:translation_app/utils/text_size.dart';

void main() {
  group('clampTextSizePx', () {
    test('null stays null (system/inherit)', () {
      expect(clampTextSizePx(null), isNull);
    });

    test('values inside the range pass through', () {
      expect(clampTextSizePx(10), 10);
      expect(clampTextSizePx(22), 22);
      expect(clampTextSizePx(40), 40);
    });

    test('out-of-range values clamp instead of throwing', () {
      expect(clampTextSizePx(-5), kTextSizeMinPx);
      expect(clampTextSizePx(9), kTextSizeMinPx);
      expect(clampTextSizePx(41), kTextSizeMaxPx);
      expect(clampTextSizePx(9999), kTextSizeMaxPx);
    });
  });

  group('resolveOutputTextSizePx', () {
    test('inherits system when neither pref is set', () {
      expect(resolveOutputTextSizePx(null, null), isNull);
    });

    test('global applies when no output override exists', () {
      expect(resolveOutputTextSizePx(18, null), 18);
    });

    test('output override wins over the global size', () {
      expect(resolveOutputTextSizePx(18, 28), 28);
      expect(resolveOutputTextSizePx(null, 28), 28);
    });

    test('both inputs clamp before resolving', () {
      expect(resolveOutputTextSizePx(999, 5), kTextSizeMinPx);
      expect(resolveOutputTextSizePx(1, null), kTextSizeMinPx);
    });
  });

  group('resolveTextScaler', () {
    test('System keeps the ambient scaler untouched', () {
      const ambient = TextScaler.linear(1.3);
      final scaler = resolveTextScaler(px: null, basePx: 14, system: ambient);
      expect(scaler, same(ambient));
      expect(scaler.scale(14), closeTo(18.2, 0.001));
    });

    test('explicit px maps body text to that many logical pixels', () {
      final scaler = resolveTextScaler(
        px: 28,
        basePx: 14,
        system: const TextScaler.linear(1),
      );
      expect(scaler.scale(14), closeTo(28, 0.001));
    });

    test('non-positive base falls back instead of dividing by zero', () {
      final scaler = resolveTextScaler(
        px: 20,
        basePx: 0,
        system: const TextScaler.linear(1),
      );
      expect(scaler.scale(kFallbackBodyFontPx), closeTo(20, 0.001));
    });

    test('out-of-range px clamps', () {
      final scaler = resolveTextScaler(
        px: 500,
        basePx: 14,
        system: const TextScaler.linear(1),
      );
      expect(scaler.scale(14), closeTo(kTextSizeMaxPx.toDouble(), 0.001));
    });
  });

  group('bodyBaseFontPx', () {
    test('reads bodyMedium fontSize', () {
      expect(bodyBaseFontPx(const TextTheme(
        bodyMedium: TextStyle(fontSize: 16),
      )), 16);
    });

    test('falls back when the theme has no bodyMedium size', () {
      expect(bodyBaseFontPx(const TextTheme()), kFallbackBodyFontPx);
    });
  });
}
