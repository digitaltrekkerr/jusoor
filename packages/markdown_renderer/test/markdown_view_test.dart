import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_renderer/markdown_renderer.dart';

/// Sample markdown containing all GFM element types the widget must
/// render without showing raw syntax symbols.
const _sampleMarkdown = '''
# Heading One

## Heading Two

### Heading Three

This is **bold** and *italic* text.

| Header 1 | Header 2 | Header 3 |
|----------|----------|----------|
| Cell 1   | Cell 2   | Cell 3   |

- List item one
- List item two
- List item three

> This is a blockquote.

Inline `code` example.

```
Code block line 1
Code block line 2
```
''';

void main() {
  group('MarkdownView', () {
    /// Helper to wrap [widgetUnderTest] in a [MaterialApp] so that
    /// [Theme.of(context)] and other inherited widgets are available.
    Widget buildSubject(Widget widgetUnderTest) {
      return MaterialApp(home: Scaffold(body: widgetUnderTest));
    }

    testWidgets('renders markdown text without raw symbols', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(const MarkdownView(markdownText: _sampleMarkdown)),
      );
      await tester.pumpAndSettle();

      // Headings should be rendered as Text widgets — no raw '#' visible.
      expect(find.text('Heading One'), findsOneWidget);
      expect(find.text('Heading Two'), findsOneWidget);
      expect(find.text('Heading Three'), findsOneWidget);

      // Bold/italic text is part of RichText — verify the text content
      // exists (not the raw ** or * symbols as separate text).
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final allText = richTexts.map((rt) => rt.text.toPlainText()).join(' ');
      // No raw markdown symbols should appear as plain text.
      expect(allText, isNot(contains('# ')));
      expect(allText, isNot(contains('**')));
      expect(allText, contains('bold'));
      expect(allText, contains('italic'));

      // List items rendered.
      expect(find.text('List item one'), findsOneWidget);
      expect(find.text('List item two'), findsOneWidget);
      expect(find.text('List item three'), findsOneWidget);

      // Blockquote content rendered.
      expect(find.text('This is a blockquote.'), findsOneWidget);

      // Inline code and code block content rendered as part of RichText.
      expect(allText, contains('code'));
    });

    testWidgets('renders tables with borders', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildSubject(const MarkdownView(markdownText: _sampleMarkdown)),
      );
      await tester.pumpAndSettle();

      // Tables are rendered as Table widgets with TableBorder.
      final tables = tester.widgetList<Table>(find.byType(Table));
      expect(
        tables,
        isNotEmpty,
        reason: 'At least one Table should be present',
      );

      // Verify table border is configured (non-null border with sides).
      for (final table in tables) {
        expect(table.border, isNotNull);
        expect(table.border!.top.width, greaterThan(0));
      }
    });

    testWidgets('loading state shows progress indicator', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildSubject(const MarkdownView.loading()));
      // Use pump() instead of pumpAndSettle() because
      // CircularProgressIndicator animates indefinitely.
      await tester.pump();

      // Should show a CircularProgressIndicator.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Should show the "Translating..." text.
      expect(find.text('Translating...'), findsOneWidget);
    });

    testWidgets('streaming state renders partial text', (
      WidgetTester tester,
    ) async {
      const partialText = '# Hello\nThis is **streaming** content.';

      await tester.pumpWidget(
        buildSubject(MarkdownView.streaming(partial: partialText)),
      );
      await tester.pumpAndSettle();

      // Heading should render without raw '#'.
      expect(find.text('Hello'), findsOneWidget);
      // Verify rich text content contains "streaming".
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final allText = richTexts.map((rt) => rt.text.toPlainText()).join(' ');
      expect(allText, contains('streaming'));
    });

    testWidgets('streaming state updates when text changes', (
      WidgetTester tester,
    ) async {
      const partialText1 = '# Hello';
      const partialText2 = '# Hello\nWorld paragraph.';

      // Start with partial text.
      await tester.pumpWidget(
        buildSubject(MarkdownView.streaming(partial: partialText1)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);

      // Update with more text — simulates parent re-building.
      await tester.pumpWidget(
        buildSubject(MarkdownView.streaming(partial: partialText2)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('World paragraph.'), findsOneWidget);
    });

    testWidgets('selectable=true wraps content in SelectionArea', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          const MarkdownView(markdownText: 'Selectable text', selectable: true),
        ),
      );
      await tester.pumpAndSettle();

      // SelectionArea should be present in the widget tree.
      expect(find.byType(SelectionArea), findsOneWidget);
    });

    testWidgets('selectable=false does not wrap in SelectionArea', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          const MarkdownView(
            markdownText: 'Non-selectable text',
            selectable: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SelectionArea should NOT be present.
      expect(find.byType(SelectionArea), findsNothing);
    });

    testWidgets('loading state is not selectable', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(const MarkdownView.loading()));
      // Use pump() instead of pumpAndSettle() because
      // CircularProgressIndicator animates indefinitely.
      await tester.pump();

      // Loading state should not have SelectionArea.
      expect(find.byType(SelectionArea), findsNothing);
      // Should not show MarkdownBody.
      expect(find.byType(MarkdownBody), findsNothing);
    });

    testWidgets('renders inline code with monospace font', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(const MarkdownView(markdownText: 'Use `code` here')),
      );
      await tester.pumpAndSettle();

      // The word "code" should appear in the rendered output.
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final allText = richTexts.map((rt) => rt.text.toPlainText()).join(' ');
      expect(allText, contains('code'));
    });
  });
}
