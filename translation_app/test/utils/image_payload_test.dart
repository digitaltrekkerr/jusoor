import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:translation_app/l10n/app_localizations_ar.dart';
import 'package:translation_app/l10n/app_localizations_en.dart';
import 'package:translation_app/utils/image_payload.dart';
import 'package:translation_core/translation_core.dart';

/// Guards the reasoning-effort strings added for the OpenRouter effort
/// selector, and the invariant that both locales expose every one of them.
///
/// Effort is offered in the profile editor's model picker for every provider,
/// so a missing key in either locale would break the settings screen.
void main() {
  group('reasoning effort strings', () {
    test('en resolves every selector label', () {
      final en = AppLocalizationsEn();

      expect(en.profileReasoningEffortLabel, 'Reasoning effort');
      expect(en.profileReasoningEffortAuto, 'Auto (model default)');
      expect(en.profileReasoningEffortNone, 'None');
      expect(en.profileReasoningEffortLow, 'Low');
      expect(en.profileReasoningEffortMedium, 'Medium');
      expect(en.profileReasoningEffortHigh, 'High');
    });

    test('en explains the cost and the per-model filtering', () {
      final en = AppLocalizationsEn();

      expect(en.profileReasoningEffortHelper, contains('slower'));
      expect(en.profileReasoningEffortHelper, contains('this model'));
      expect(en.profileReasoningEffortOpenRouterOnly, contains('OpenRouter'));
    });

    test('ar resolves every selector label', () {
      final ar = AppLocalizationsAr();

      expect(ar.profileReasoningEffortLabel, 'مستوى التفكير');
      expect(ar.profileReasoningEffortAuto, 'تلقائي (افتراضي النموذج)');
      expect(ar.profileReasoningEffortNone, 'بدون');
      expect(ar.profileReasoningEffortLow, 'منخفض');
      expect(ar.profileReasoningEffortMedium, 'متوسط');
      expect(ar.profileReasoningEffortHigh, 'عالٍ');
    });

    test('ar never falls back to the English copy', () {
      final ar = AppLocalizationsAr();
      final en = AppLocalizationsEn();

      expect(ar.profileReasoningEffortLabel,
          isNot(en.profileReasoningEffortLabel));
      expect(ar.profileReasoningEffortAuto,
          isNot(en.profileReasoningEffortAuto));
      expect(ar.profileReasoningEffortHelper,
          isNot(en.profileReasoningEffortHelper));
    });

    test('both locales expose exactly the same set of effort keys', () {
      final ar = AppLocalizationsAr();
      final en = AppLocalizationsEn();

      // Reference the getters so a typo in either one fails to compile here.
      final arValues = [
        ar.profileReasoningEffortLabel,
        ar.profileReasoningEffortAuto,
        ar.profileReasoningEffortNone,
        ar.profileReasoningEffortLow,
        ar.profileReasoningEffortMedium,
        ar.profileReasoningEffortHigh,
        ar.profileReasoningEffortHelper,
        ar.profileReasoningEffortOpenRouterOnly,
      ];
      final enValues = [
        en.profileReasoningEffortLabel,
        en.profileReasoningEffortAuto,
        en.profileReasoningEffortNone,
        en.profileReasoningEffortLow,
        en.profileReasoningEffortMedium,
        en.profileReasoningEffortHigh,
        en.profileReasoningEffortHelper,
        en.profileReasoningEffortOpenRouterOnly,
      ];

      expect(arValues.length, enValues.length);
      for (final value in arValues) {
        expect(value, isNotEmpty,
            reason: 'an empty localized string renders as a blank field');
      }
      for (final value in enValues) {
        expect(value, isNotEmpty);
      }
    });
  });

  group('ImagePayloadPreparer — non-image input', () {
    // Real decoding needs a platform image codec, which unit tests cannot
    // provide. These cover the parts that must degrade gracefully instead of
    // throwing, which is the contract the capture sites rely on.
    test('garbage bytes pass through rather than crash the flow', () async {
      final prepared = await ImagePayloadPreparer.prepare(
        Uint8List.fromList([1, 2, 3, 4]),
        mimeType: 'image/png',
      );

      expect(prepared.wasModified, isFalse);
      expect(prepared.mimeType, 'image/png');
      expect(prepared.base64, isNotEmpty);
    });

    test('an empty payload does not throw', () async {
      final prepared = await ImagePayloadPreparer.prepare(
        Uint8List(0),
        mimeType: 'image/png',
      );

      expect(prepared.base64, isEmpty);
    });

    test('isWithinLimits distinguishes small from large payloads', () {
      expect(ImagePayloadPreparer.isWithinLimits(Uint8List(10)), isTrue);
      expect(
        ImagePayloadPreparer.isWithinLimits(
          Uint8List(ImagePayloadPreparer.targetBytes + 1),
        ),
        isFalse,
      );
    });

    test('the size target sits below the core guard ceiling', () {
      expect(
        ImagePayloadPreparer.targetBytes,
        lessThan(ImagePayloadGuard.maxAcceptedBytes),
        reason: 'the preparer should be the one to fail, with rungs left',
      );
    });

    test('the long edge matches Anthropic\'s standard resolution tier', () {
      expect(ImagePayloadPreparer.maxLongEdgePx, 1568);
    });
  });
}
