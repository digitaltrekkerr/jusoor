import 'package:flutter_test/flutter_test.dart';

import 'package:translation_app/l10n/app_localizations_ar.dart';
import 'package:translation_app/l10n/app_localizations_en.dart';

/// Guards against Issue M2 regressions: the copy/share bottom-sheet labels
/// must come from `AppLocalizations`, never from hardcoded inline strings.
void main() {
  group('AppLocalizations M2 copy/share keys', () {
    test('en resolves the English sheet labels', () {
      final en = AppLocalizationsEn();

      expect(en.copyAsPlain, 'Copy as plain text');
      expect(en.copyAsMarkdown, 'Copy as Markdown');
      expect(en.shareAsPlain, 'Share as plain text');
      expect(en.shareAsMarkdown, 'Share as Markdown');
      expect(en.saveToFile, 'Save to file');
      expect(en.copyOptionsTitle, 'Copy options');
      expect(en.shareOptionsTitle, 'Share options');
    });

    test('en labels are never the old hardcoded Arabic strings', () {
      final en = AppLocalizationsEn();

      expect(en.copyAsPlain, isNot('نسخ كنص عادي'));
      expect(en.copyAsMarkdown, isNot('نسخ كـ Markdown'));
      expect(en.shareAsPlain, isNot('مشاركة كنص عادي'));
      expect(en.shareAsMarkdown, isNot('مشاركة كـ Markdown'));
      expect(en.saveToFile, isNot('حفظ إلى ملف'));
    });

    test('ar preserves the previously hardcoded Arabic output for share', () {
      final ar = AppLocalizationsAr();

      // These values must equal what was hardcoded before the l10n refactor
      // so Arabic-default users see no visible change.
      expect(ar.shareAsPlain, 'مشاركة كنص عادي');
      expect(ar.shareAsMarkdown, 'مشاركة كـ Markdown (.md)');
      expect(ar.saveToFile, 'حفظ إلى ملف');
      expect(ar.copyAsPlain, 'نسخ كنص عادي');
      expect(ar.copyAsMarkdown, 'نسخ كـ Markdown');
    });
  });
}