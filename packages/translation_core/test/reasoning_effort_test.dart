// Copyright (c) 2026 Jusoor. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file in the root of the source tree.

import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/src/models/reasoning_effort.dart';

void main() {
  group('ReasoningEffort wire value', () {
    test('each level round-trips through its own name', () {
      for (final effort in ReasoningEffort.values) {
        expect(ReasoningEffort.fromWire(effort.wireValue), effort);
      }
    });

    test('strength increases from none to high', () {
      expect(ReasoningEffort.none.strength,
          lessThan(ReasoningEffort.low.strength));
      expect(ReasoningEffort.low.strength,
          lessThan(ReasoningEffort.medium.strength));
      expect(ReasoningEffort.medium.strength,
          lessThan(ReasoningEffort.high.strength));
    });
  });

  group('ReasoningEffort.fromWire', () {
    test('unknown, empty and null values parse to null, not throw', () {
      expect(ReasoningEffort.fromWire(null), isNull);
      expect(ReasoningEffort.fromWire(''), isNull);
      expect(ReasoningEffort.fromWire('turbo'), isNull);
      expect(ReasoningEffort.fromWire('HIGH'), isNull,
          reason: 'values are case-sensitive so a typo cannot silently match');
    });
  });

  group('ReasoningEffort.normalize', () {
    test('folds provider-only levels onto ones Jusoor exposes', () {
      expect(ReasoningEffort.normalize('xhigh'), ReasoningEffort.high);
      expect(ReasoningEffort.normalize('max'), ReasoningEffort.high);
      expect(ReasoningEffort.normalize('minimal'), ReasoningEffort.none);
      expect(ReasoningEffort.normalize('none'), ReasoningEffort.none);
    });

    test('passes through the levels we expose untouched', () {
      expect(ReasoningEffort.normalize('low'), ReasoningEffort.low);
      expect(ReasoningEffort.normalize('medium'), ReasoningEffort.medium);
      expect(ReasoningEffort.normalize('high'), ReasoningEffort.high);
    });

    test('an unrecognized value lands on medium, never throws', () {
      expect(ReasoningEffort.normalize('gigantic'), ReasoningEffort.medium);
    });
  });
}
