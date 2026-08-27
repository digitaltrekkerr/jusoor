import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:translation_app/l10n/app_localizations.dart';
import 'package:translation_app/screens/tips_screen.dart';
import 'package:translation_app/services/articles_service.dart';
import 'package:translation_app/services/tips_service.dart';

void main() {
  Widget buildApp({required Locale locale}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TipsScreen(),
    );
  }

  /// Scrolls [finder] into view inside the scrollable Tips list.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  testWidgets('English locale renders all three sections', (tester) async {
    await tester.pumpWidget(buildApp(locale: const Locale('en')));
    await tester.pump();

    // First section + first tip are immediately visible.
    expect(find.text('Quick tips'), findsOneWidget);
    expect(find.text('Use fast, cheap models'), findsOneWidget);

    await scrollTo(tester, find.text('How to use the app'));
    expect(find.text('How to use the app'), findsOneWidget);

    await scrollTo(tester, find.text('Step-by-step setup'));
    expect(find.text('Step-by-step setup'), findsOneWidget);

    // Setup article cards resolve to English titles.
    final firstArticleId = kTipsSetupArticleIds.first;
    final firstArticle = kAppArticles.firstWhere((a) => a.id == firstArticleId);
    await scrollTo(tester, find.text(firstArticle.titleEn!));
    expect(find.text(firstArticle.titleEn!), findsOneWidget);
  });

  testWidgets('Arabic locale renders Arabic content', (tester) async {
    await tester.pumpWidget(buildApp(locale: const Locale('ar')));
    await tester.pump();

    expect(find.text('نصائح سريعة'), findsOneWidget);
    expect(find.text(kTipsQuickTips.first.title.ar), findsOneWidget);

    await scrollTo(tester, find.text('كيفية استخدام التطبيق'));
    expect(find.text('كيفية استخدام التطبيق'), findsOneWidget);

    await scrollTo(tester, find.text('الإعداد خطوة بخطوة'));
    expect(find.text('الإعداد خطوة بخطوة'), findsOneWidget);
  });

  testWidgets('tapping a setup article opens the article reader',
      (tester) async {
    await tester.pumpWidget(buildApp(locale: const Locale('en')));
    await tester.pump();

    final firstArticleId = kTipsSetupArticleIds.first;
    final firstArticle = kAppArticles.firstWhere((a) => a.id == firstArticleId);
    final card = find.byKey(ValueKey('tips-article-$firstArticleId'));
    await scrollTo(tester, card);

    await tester.tap(card);
    await tester.pumpAndSettle();

    // The article reader AppBar shows the article title.
    expect(
      find.widgetWithText(AppBar, firstArticle.titleEn!),
      findsOneWidget,
    );
  });
}