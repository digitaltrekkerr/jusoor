// Copyright (c) 2026 Jusoor. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file in the root of the source tree.

import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/src/models/model_capabilities.dart';
import 'package:translation_core/src/models/reasoning_effort.dart';

/// Real capability sets, copied from `GET /api/v1/models` on OpenRouter.
///
/// These are the shapes the gating has to survive, so the tests use the real
/// values rather than invented ones.
const kClaudeHaiku55 = ModelCapabilities(
  id: 'anthropic/claude-haiku-5.5',
  known: true,
  supportsReasoning: true,
  reasoningMandatory: false,
  supportedEfforts: [
    ReasoningEffort.high,
    ReasoningEffort.medium,
    ReasoningEffort.low,
  ],
  defaultEffort: ReasoningEffort.medium,
  defaultEnabled: true,
);

/// A model whose reasoning cannot be switched off.
const kMandatory = ModelCapabilities(
  id: 'some/mandatory-model',
  known: true,
  supportsReasoning: true,
  reasoningMandatory: true,
  supportedEfforts: [
    ReasoningEffort.high,
    ReasoningEffort.medium,
    ReasoningEffort.low,
  ],
  defaultEffort: ReasoningEffort.high,
  defaultEnabled: true,
);

/// A model supporting only two levels.
const kSparse = ModelCapabilities(
  id: 'some/sparse-model',
  known: true,
  supportsReasoning: true,
  reasoningMandatory: false,
  supportedEfforts: [
    ReasoningEffort.high,
    ReasoningEffort.low,
  ],
  defaultEffort: ReasoningEffort.high,
  defaultEnabled: true,
);

/// A model with no reasoning at all — the `reasoning` field is simply absent
/// from the models listing, which is also true of `openrouter/auto` and
/// `openrouter/free`.
const kNoReasoning = ModelCapabilities(
  id: 'some/plain-model',
  known: true,
  supportsReasoning: false,
);

void main() {
  group('sanitize — a supported effort passes straight through', () {
    test('high stays high', () {
      expect(kClaudeHaiku55.sanitize(ReasoningEffort.high),
          ReasoningEffort.high);
    });

    test('medium stays medium', () {
      expect(kClaudeHaiku55.sanitize(ReasoningEffort.medium),
          ReasoningEffort.medium);
    });

    test('low stays low', () {
      expect(kClaudeHaiku55.sanitize(ReasoningEffort.low), ReasoningEffort.low);
    });
  });

  group('sanitize — an unsupported effort is clamped', () {
    test('medium clamps down to low on a two-level model', () {
      expect(kSparse.sanitize(ReasoningEffort.medium), ReasoningEffort.low);
    });

    test('an out-of-range level clamps to the nearest stronger one', () {
      // kSparse supports high and low; medium is equidistant, so it must
      // resolve to the cheaper option rather than silently spending more.
      expect(kSparse.sanitize(ReasoningEffort.medium), ReasoningEffort.low);
    });

    test('the result is always a level the model accepts', () {
      for (final caps in [kClaudeHaiku55, kSparse, kMandatory]) {
        for (final requested in ReasoningEffort.values) {
          final resolved = caps.sanitize(requested);
          if (resolved == ReasoningEffort.none) continue;
          expect(
            caps.supportedEfforts.contains(resolved),
            isTrue,
            reason: '${caps.id} rejected $resolved for $requested',
          );
        }
      }
    });
  });

  group('sanitize — none is never sent to a mandatory model', () {
    test('mandatory reasoning clamps none to the model default effort', () {
      expect(kMandatory.sanitize(ReasoningEffort.none),
          ReasoningEffort.high);
    });

    test('mandatory reasoning with no preference uses the default', () {
      expect(kMandatory.sanitize(null), ReasoningEffort.high);
    });

    test('optional reasoning honors an explicit none', () {
      expect(kClaudeHaiku55.sanitize(ReasoningEffort.none),
          ReasoningEffort.none);
    });

    test('canSend agrees that none is invalid on a mandatory model', () {
      expect(kMandatory.canSend(ReasoningEffort.none), isFalse);
      expect(kClaudeHaiku55.canSend(ReasoningEffort.none), isTrue);
    });
  });

  group('sanitize — models with no reasoning', () {
    test('any request resolves to none so the key is omitted', () {
      for (final requested in ReasoningEffort.values) {
        expect(kNoReasoning.sanitize(requested), ReasoningEffort.none);
      }
    });

    test('the UI offers nothing to choose', () {
      expect(kNoReasoning.selectableEfforts, isEmpty);
    });
  });

  group('sanitize — unknown capabilities', () {
    const unknown = ModelCapabilities.unknown('some/unknown-model');

    test('the model is reported as unknown', () {
      expect(unknown.known, isFalse);
    });

    test('the user\'s choice passes through untouched', () {
      expect(unknown.sanitize(ReasoningEffort.high), ReasoningEffort.high);
      expect(unknown.sanitize(ReasoningEffort.none), ReasoningEffort.none);
      expect(unknown.sanitize(null), ReasoningEffort.none);
    });

    test('canSend cannot rule anything out', () {
      for (final effort in ReasoningEffort.values) {
        expect(unknown.canSend(effort), isTrue);
      }
    });

    test('the UI still offers every level', () {
      expect(unknown.selectableEfforts,
          [ReasoningEffort.none, ReasoningEffort.high, ReasoningEffort.medium, ReasoningEffort.low]);
    });
  });

  group('selectableEfforts', () {
    test('includes a leading none when reasoning is optional', () {
      expect(
        kClaudeHaiku55.selectableEfforts,
        [
          ReasoningEffort.none,
          ReasoningEffort.high,
          ReasoningEffort.medium,
          ReasoningEffort.low,
        ],
      );
    });

    test('drops none when reasoning is mandatory', () {
      expect(kMandatory.selectableEfforts, isNot(contains(ReasoningEffort.none)));
    });

    test('never offers a level duplicated by the provider', () {
      final claude = kClaudeHaiku55.selectableEfforts.toSet();
      expect(claude.length, kClaudeHaiku55.selectableEfforts.length);
    });
  });
}
