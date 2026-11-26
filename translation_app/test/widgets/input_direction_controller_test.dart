import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:translation_app/widgets/input_direction_controller.dart';

void main() {
  group('InputDirectionController', () {
    test('starts ltr; seed detects direction', () {
      final c = InputDirectionController();
      expect(c.value, TextDirection.ltr);
      c.seed('مرحبا');
      expect(c.value, TextDirection.rtl);
      c.seed('Hello');
      expect(c.value, TextDirection.ltr);
    });

    test('hysteresis keeps previous on update', () {
      final c = InputDirectionController();
      c.seed('مرحبا بالعالم');
      expect(c.value, TextDirection.rtl);
      // mixed ~50/50 should keep rtl because rtlRatio >= 0.45
      c.update('مرحبا hello');
      // value stays rtl (no crash); accept either but assert not flipped to ltr incorrectly? 
      // We assert it remains rtl for this mixed input.
      expect(c.value, TextDirection.rtl);
    });

    test('update flips to ltr past threshold', () {
      final c = InputDirectionController();
      c.seed('مرحبا');
      expect(c.value, TextDirection.rtl);
      c.update('Hello world this is a long english sentence');
      expect(c.value, TextDirection.ltr);
    });

    test('update does not notify when unchanged', () {
      final c = InputDirectionController();
      c.seed('Hello');
      int count = 0;
      c.addListener(() => count++);
      c.update('Hello again slightly different but still ltr dominant maybe');
      // If value unchanged, no notification. We force identical by updating same text.
      final before = count;
      c.update('Hello');
      expect(count, before);
    });
  });
}
