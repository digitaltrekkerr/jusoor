import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:history/history.dart';
import 'package:translation_app/l10n/app_localizations.dart';
import 'package:translation_app/screens/history_detail_screen.dart';

/// Widget probe for Issue M2: the copy/share bottom sheets on the history
/// detail screen must render labels from `AppLocalizations` in the active
/// locale — an English-locale user must see English, never the old
/// hardcoded Arabic strings.
void main() {
  const record = TranslationRecord(
    createdAt: 1700000000000,
    targetLanguage: 'en',
    inputText: 'Hello world',
    outputText: '**Hello** world',
    inputType: 'text',
    modelUsed: 'gpt-4o',
    wordCount: 2,
  );

  Widget wrapEn(Widget child) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  testWidgets('history detail share sheet uses l10n labels for en locale',
      (tester) async {
    await tester.pumpWidget(wrapEn(const HistoryDetailScreen(record: record)));

    await tester.tap(find.byIcon(Icons.share));
    await tester.pumpAndSettle();

    expect(find.text('Share options'), findsOneWidget);
    expect(find.text('Share as plain text'), findsOneWidget);
    expect(find.text('Share as Markdown'), findsOneWidget);
    expect(find.text('Save to file'), findsOneWidget);

    // The old hardcoded Arabic labels must not appear in the en sheet.
    expect(find.text('مشاركة كنص عادي'), findsNothing);
    expect(find.text('مشاركة كـ Markdown (.md)'), findsNothing);
  });

  testWidgets('history detail copy sheet uses l10n labels for en locale',
      (tester) async {
    await tester.pumpWidget(wrapEn(const HistoryDetailScreen(record: record)));

    await tester.longPress(find.byIcon(Icons.copy));
    await tester.pumpAndSettle();

    expect(find.text('Copy options'), findsOneWidget);
    expect(find.text('Copy as plain text'), findsOneWidget);
    expect(find.text('Copy as Markdown'), findsOneWidget);

    expect(find.text('نسخ كنص عادي'), findsNothing);
    expect(find.text('نسخ كـ Markdown'), findsNothing);
  });
}