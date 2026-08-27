import 'package:flutter_test/flutter_test.dart';

import 'package:translation_app/services/articles_service.dart';
import 'package:translation_app/services/tips_service.dart';

void main() {
  group('kTipsQuickTips — bilingual content', () {
    test('contains at least 5 quick tips', () {
      expect(kTipsQuickTips.length, greaterThanOrEqualTo(5));
    });

    test('every tip has Arabic and English title & body', () {
      for (final tip in kTipsQuickTips) {
        expect(tip.title.ar.trim(), isNotEmpty,
            reason: 'Arabic title should not be blank');
        expect(tip.title.en.trim(), isNotEmpty,
            reason: 'English title should not be blank');
        expect(tip.body.ar.trim(), isNotEmpty,
            reason: 'Arabic body should not be blank');
        expect(tip.body.en.trim(), isNotEmpty,
            reason: 'English body should not be blank');
      }
    });

    test('resolve() picks English for en, Arabic otherwise', () {
      for (final tip in kTipsQuickTips) {
        expect(tip.title.resolve('en'), tip.title.en);
        expect(tip.title.resolve('ar'), tip.title.ar);
        expect(tip.title.resolve('fr'), tip.title.ar);
        expect(tip.body.resolve('en'), tip.body.en);
        expect(tip.body.resolve('ar'), tip.body.ar);
      }
    });
  });

  group('kTipsUsageSteps — bilingual content', () {
    test('contains at least 5 steps', () {
      expect(kTipsUsageSteps.length, greaterThanOrEqualTo(5));
    });

    test('every step has Arabic and English title & body', () {
      for (final step in kTipsUsageSteps) {
        expect(step.title.ar.trim(), isNotEmpty);
        expect(step.title.en.trim(), isNotEmpty);
        expect(step.body.ar.trim(), isNotEmpty);
        expect(step.body.en.trim(), isNotEmpty);
      }
    });
  });

  group('kTipsSetupArticleIds — article references', () {
    test('every referenced article id exists in kAppArticles', () {
      final ids = kAppArticles.map((a) => a.id).toSet();
      for (final id in kTipsSetupArticleIds) {
        expect(ids, contains(id),
            reason: 'Tips screen links to article "$id" which is not in '
                'kAppArticles');
        final article = kAppArticles.firstWhere((a) => a.id == id);
        expect(article.assetEn, isNotNull,
            reason: 'Setup article "$id" should be bilingual');
      }
    });
  });
}