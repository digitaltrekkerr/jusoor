import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_app/widgets/bidi_markdown_view.dart';

void main() {
  group('BiDiMarkdownView.isRtl', () {
    test('pure Arabic returns true', () {
      expect(BiDiMarkdownView.isRtl('مرحبا بالعالم'), isTrue);
    });

    test('pure English returns false', () {
      expect(BiDiMarkdownView.isRtl('Hello world'), isFalse);
    });

    test('empty text returns false', () {
      expect(BiDiMarkdownView.isRtl(''), isFalse);
    });

    test('markdown-stripped Arabic returns true', () {
      expect(BiDiMarkdownView.isRtl('**مرحبا**'), isTrue);
    });

    test('markdown-stripped English returns false', () {
      expect(BiDiMarkdownView.isRtl('## Hello'), isFalse);
    });

    test('Hebrew returns true', () {
      expect(BiDiMarkdownView.isRtl('שלום עולם'), isTrue);
    });

    test('Arabic-dominant mixed text returns true', () {
      expect(BiDiMarkdownView.isRtl('مرحبا بالعالم Hello'), isTrue);
    });

    test('English-dominant mixed text returns false', () {
      expect(BiDiMarkdownView.isRtl('Hello world and مرحبا'), isFalse);
    });

    test('equal mixed text defaults to false (tie goes to LTR)', () {
      expect(BiDiMarkdownView.isRtl('مرحباHello'), isFalse);
    });

    test('numbers-only returns false', () {
      expect(BiDiMarkdownView.isRtl('123456'), isFalse);
    });

    group('URL handling', () {
      test('markdown link targets do not flip Arabic to LTR', () {
        expect(
          BiDiMarkdownView.isRtl(
            '[نص عربي](https://example.com/very/long/path/page)',
          ),
          isTrue,
        );
      });

      test('bare URLs do not flip Arabic to LTR', () {
        expect(
          BiDiMarkdownView.isRtl('اقرأ المزيد https://example.com/a/b/c/d/e'),
          isTrue,
        );
      });

      test('English document with links stays LTR', () {
        expect(
          BiDiMarkdownView.isRtl('[Hello](https://ar.example.com) world'),
          isFalse,
        );
      });
    });
  });

  group('BiDiMarkdownView.detectDirection', () {
    test('no previous, pure Arabic returns RTL', () {
      expect(
        BiDiMarkdownView.detectDirection('مرحبا'),
        TextDirection.rtl,
      );
    });

    test('no previous, pure English returns LTR', () {
      expect(
        BiDiMarkdownView.detectDirection('Hello'),
        TextDirection.ltr,
      );
    });

    test('empty text returns fallback', () {
      expect(
        BiDiMarkdownView.detectDirection('', fallback: TextDirection.rtl),
        TextDirection.rtl,
      );
    });

    test('no RTL/LTR chars returns fallback', () {
      expect(
        BiDiMarkdownView.detectDirection('   ', fallback: TextDirection.ltr),
        TextDirection.ltr,
      );
    });

    group('hysteresis', () {
      test('stays RTL when RTL ratio is 50% (within 45% threshold)', () {
        expect(
          BiDiMarkdownView.detectDirection('مرAB', previous: TextDirection.rtl),
          TextDirection.rtl,
        );
      });

      test('switches to LTR when RTL drops below 45%', () {
        expect(
          BiDiMarkdownView.detectDirection('مABC', previous: TextDirection.rtl),
          TextDirection.ltr,
        );
      });

      test('stays LTR when RTL ratio is 50% (within 55% threshold)', () {
        expect(
          BiDiMarkdownView.detectDirection('ABمر', previous: TextDirection.ltr),
          TextDirection.ltr,
        );
      });

      test('switches to RTL when RTL exceeds 55%', () {
        // 5 RTL + 4 LTR = 55.5% RTL > 55% → switches to RTL
        expect(
          BiDiMarkdownView.detectDirection('ABCDمرحبا', previous: TextDirection.ltr),
          TextDirection.rtl,
        );
      });

      test('hysteresis with empty previous defaults to initial threshold', () {
        // 2 RTL + 2 LTR = 50% → no previous, < 55% → LTR
        expect(
          BiDiMarkdownView.detectDirection('ABمر'),
          TextDirection.ltr,
        );
        // 5 RTL + 4 LTR = 55.5% > 55% → RTL (no previous)
        expect(
          BiDiMarkdownView.detectDirection('ABCDمرحبا'),
          TextDirection.rtl,
        );
      });
    });
  });

  group('BiDiMarkdownView widget', () {
    Widget buildSubject({
      String text = '',
      bool selectable = false,
      bool isLoading = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: BiDiMarkdownView(
            markdownText: text,
            selectable: selectable,
            isLoading: isLoading,
          ),
        ),
      );
    }

    Directionality? findBidiDir(WidgetTester tester) {
      final dirs =
          tester.widgetList<Directionality>(find.byType(Directionality));
      for (final d in dirs) {
        if (d.key != null && d.key.toString().contains('bidi-dir-')) {
          return d;
        }
      }
      return null;
    }

    testWidgets('loading state shows CircularProgressIndicator', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildSubject(isLoading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Arabic text renders with Directionality.rtl', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildSubject(text: 'مرحبا بالعالم'));
      await tester.pumpAndSettle();
      final dir = findBidiDir(tester);
      expect(dir, isNotNull);
      expect(dir!.textDirection, TextDirection.rtl);
    });

    testWidgets('English text renders with Directionality.ltr', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildSubject(text: 'Hello world'));
      await tester.pumpAndSettle();
      final dir = findBidiDir(tester);
      expect(dir, isNotNull);
      expect(dir!.textDirection, TextDirection.ltr);
    });

    testWidgets('selectable wraps in SelectionArea', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildSubject(text: 'Hello', selectable: true));
      await tester.pumpAndSettle();
      final selAreaDescendant = find.descendant(
        of: find.byType(BiDiMarkdownView),
        matching: find.byType(SelectionArea),
      );
      expect(selAreaDescendant, findsOneWidget);
    });

    testWidgets('non-selectable has no SelectionArea', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(text: 'Hello', selectable: false),
      );
      await tester.pumpAndSettle();
      final selAreaDescendant = find.descendant(
        of: find.byType(BiDiMarkdownView),
        matching: find.byType(SelectionArea),
      );
      expect(selAreaDescendant, findsNothing);
    });

    testWidgets('streaming constructor renders partial text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BiDiMarkdownView.streaming(
              partial: '# Hello\nThis is **streaming** content.',
              selectable: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final richTexts =
          tester.widgetList<RichText>(find.byType(RichText));
      final allText =
          richTexts.map((rt) => rt.text.toPlainText()).join(' ');
      expect(allText, contains('Hello'));
      expect(allText, contains('streaming'));
    });

    testWidgets('text direction updates when content changes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildSubject(text: 'Hello'));
      await tester.pumpAndSettle();
      var dir = findBidiDir(tester);
      expect(dir, isNotNull);
      expect(dir!.textDirection, TextDirection.ltr);

      await tester.pumpWidget(buildSubject(text: 'مرحبا بالعالم'));
      await tester.pumpAndSettle();
      dir = findBidiDir(tester);
      expect(dir, isNotNull);
      expect(dir!.textDirection, TextDirection.rtl);
    });

    testWidgets('fenced code block inside Arabic text forces LTR', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(text: 'نص عربي\n```\nvalue = 123\n```'),
      );
      await tester.pumpAndSettle();

      final outerDir = findBidiDir(tester);
      expect(outerDir, isNotNull);
      expect(outerDir!.textDirection, TextDirection.rtl);

      // The code-block builder must introduce an inner LTR Directionality.
      final innerLtr = tester
          .widgetList<Directionality>(
            find.descendant(
              of: find.byType(BiDiMarkdownView),
              matching: find.byType(Directionality),
            ),
          )
          .where((d) => d.textDirection == TextDirection.ltr);
      expect(innerLtr, isNotEmpty);
    });
  });
}
