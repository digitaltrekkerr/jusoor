import 'package:flutter_test/flutter_test.dart';

import 'package:translation_app/services/articles_service.dart';

/// Articles are bilingual: Arabic is the canonical content, English variants
/// (`.en.md`) are provided for every article. These tests guard the
/// bilingual invariant so titles/excerpts/assets resolve correctly per
/// locale and fall back to Arabic when English is missing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('kAppArticles — bilingual content', () {
    test('contains the expected number of bundled articles', () {
      expect(kAppArticles, hasLength(greaterThanOrEqualTo(6)));
    });

    test('every article id is a 2-digit numeric prefix', () {
      final idPattern = RegExp(r'^\d{2}$');
      for (final article in kAppArticles) {
        expect(
          idPattern.hasMatch(article.id),
          isTrue,
          reason: 'Article id "${article.id}" should be a 2-digit prefix',
        );
      }
    });

    test('every article has an Arabic title and excerpt', () {
      final arabicRange = RegExp(r'[\u0600-\u06FF]');
      for (final article in kAppArticles) {
        expect(
          arabicRange.hasMatch(article.title),
          isTrue,
          reason: 'Article title "${article.title}" should contain Arabic',
        );
        expect(
          arabicRange.hasMatch(article.excerpt),
          isTrue,
          reason: 'Article excerpt for "${article.id}" should contain Arabic',
        );
      }
    });

    test('every article has non-empty English title and excerpt', () {
      for (final article in kAppArticles) {
        expect(
          article.titleEn,
          isNotNull,
          reason: 'Article "${article.id}" should have an English title',
        );
        expect(
          article.titleEn!.trim(),
          isNotEmpty,
          reason: 'English title of article "${article.id}" should not be '
              'blank',
        );
        expect(
          article.excerptEn,
          isNotNull,
          reason: 'Article "${article.id}" should have an English excerpt',
        );
        expect(
          article.excerptEn!.trim(),
          isNotEmpty,
          reason: 'English excerpt of article "${article.id}" should not be '
              'blank',
        );
      }
    });

    test('every article has an English asset variant (.en.md)', () {
      for (final article in kAppArticles) {
        expect(
          article.assetEn,
          isNotNull,
          reason: 'Article "${article.id}" should declare an English asset',
        );
        expect(
          article.assetEn,
          endsWith('.en.md'),
          reason: 'English asset of article "${article.id}" should end with '
              '.en.md',
        );
      }
    });

    test('every article asset path points under assets/articles/', () {
      for (final article in kAppArticles) {
        expect(
          article.asset,
          startsWith('assets/articles/'),
          reason: 'Article asset "${article.asset}" should live under '
              'assets/articles/',
        );
        expect(
          article.asset,
          endsWith('.md'),
          reason: 'Article asset "${article.asset}" should be a .md file',
        );
        expect(
          article.assetEn,
          startsWith('assets/articles/'),
          reason: 'English asset "${article.assetEn}" should live under '
              'assets/articles/',
        );
      }
    });

    test('assetFor selects English variant, falling back to Arabic', () {
      final article = kAppArticles.first;
      // With English asset present:
      expect(article.assetFor('en'), article.assetEn);
      expect(article.assetFor('ar'), article.asset);
      expect(article.assetFor('fr'), article.asset);
      // Without English asset: falls back to the Arabic asset.
      const arabicOnly = AppArticle(
        id: '99',
        asset: 'assets/articles/99-test.md',
        title: 'عنوان عربي',
        excerpt: 'مقتطف عربي',
      );
      expect(arabicOnly.assetFor('en'), arabicOnly.asset);
      expect(arabicOnly.titleFor('en'), arabicOnly.title);
      expect(arabicOnly.excerptFor('en'), arabicOnly.excerpt);
    });

    test('titleFor/excerptFor pick English content when available', () {
      for (final article in kAppArticles) {
        expect(
          article.titleFor('en'),
          article.titleEn,
          reason: 'titleFor("en") for "${article.id}" should return the '
              'English title',
        );
        expect(
          article.excerptFor('en'),
          article.excerptEn,
          reason: 'excerptFor("en") for "${article.id}" should return the '
              'English excerpt',
        );
      }
    });

    test('article assets and English variants exist in the bundle', () async {
      // Sanity check: loadArticleBody should succeed for every article in
      // both locales. If an asset path drifts from the bundle, this test
      // fails fast.
      for (final article in kAppArticles) {
        final arBody = await loadArticleBody(article, languageCode: 'ar');
        expect(
          arBody,
          isNotEmpty,
          reason: 'Arabic body of article "${article.id}" should be non-empty',
        );
        final enBody = await loadArticleBody(article, languageCode: 'en');
        expect(
          enBody,
          isNotEmpty,
          reason: 'English body of article "${article.id}" should be '
              'non-empty',
        );
        expect(
          enBody,
          isNot(equals(arBody)),
          reason: 'English and Arabic bodies of article "${article.id}" '
              'should differ',
        );
      }
    });
  });
}