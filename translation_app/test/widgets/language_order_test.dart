import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:translation_app/l10n/app_localizations.dart';
import 'package:translation_app/widgets/language_dropdown.dart';

const _expectedLanguages = <String>[
  'Arabic',
  'English',
  'Turkish',
  'Spanish',
  'French',
  'German',
  'Italian',
  'Portuguese',
  'Russian',
  'Chinese',
  'Japanese',
  'Korean',
  'Hindi',
  'Dutch',
  'Polish',
  'Swedish',
  'Danish',
  'Finnish',
  'Norwegian',
  'Czech',
  'Greek',
  'Hebrew',
  'Thai',
  'Vietnamese',
  'Indonesian',
  'Ukrainian',
  'Romanian',
  'Hungarian',
  'Catalan',
];

void main() {
  group('shared ordering', () {
    test('first three entries are ar/en/tr by code', () {
      expect(
        kLanguageEntries.take(3).map((e) => e.code).toList(),
        ['ar', 'en', 'tr'],
      );
    });

    test('first three entries are Arabic/English/Turkish by name', () {
      expect(
        kLanguageEntries.take(3).map((e) => e.name).toList(),
        ['Arabic', 'English', 'Turkish'],
      );
    });

    test('kLanguages first three', () {
      expect(kLanguages.take(3).toList(), ['Arabic', 'English', 'Turkish']);
    });

    test('full 29-name order snapshot', () {
      expect(kLanguages, _expectedLanguages);
    });

    test('counts and uniqueness', () {
      expect(kLanguages.length, kLanguageEntries.length);
      expect(kLanguages.length, 29);
      expect(kLanguages.toSet().length, kLanguages.length);
      expect(
        kLanguageEntries.map((e) => e.code).toSet().length,
        kLanguageEntries.length,
      );
    });

    test('mappings unchanged', () {
      expect(getLanguageCode('Arabic'), 'ar');
      expect(getLanguageCode('English'), 'en');
      expect(getLanguageCode('Turkish'), 'tr');
    });
  });

  testWidgets('home/overlay picker shows ar, en, tr first', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LanguageDropdown(
            selected: 'Arabic',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(LanguageDropdown));
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(GridView),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .toList();

    expect(labels.take(3), ['Arabic', 'English', 'Turkish']);
  });

  group('anti-drift', () {
    test('main.dart drives from kLanguages, not _kLanguageNames', () {
      final src = File('lib/main.dart').readAsStringSync();
      expect(src, isNot(contains(RegExp(r'_kLanguageNames'))));
      expect(src, contains('kLanguages'));
    });

    test('exactly one lib file contains the Spanish literal', () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      final matches = files.where((f) {
        return f.readAsStringSync().contains("'Spanish'");
      }).toList();
      expect(matches.length, 1);
      expect(matches.single.path, contains('language_dropdown.dart'));
    });
  });
}
