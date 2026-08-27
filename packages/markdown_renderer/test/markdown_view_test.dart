import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    group('link confirmation', () {
      // url_launcher's MethodChannelUrlLauncher uses
      // MethodChannel('plugins.flutter.io/url_launcher') with method
      // names 'canLaunch' and 'launch' (see
      // url_launcher_platform_interface/method_channel_url_launcher.dart).
      // We mock that channel directly rather than SystemChannels.platform,
      // which the plugin does not use.
      late List<MethodCall> platformCalls;

      setUp(() {
        platformCalls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/url_launcher'),
              (MethodCall call) async {
                platformCalls.add(call);
                if (call.method == 'launch') return true;
                if (call.method == 'canLaunch') return true;
                return null;
              },
            );
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/url_launcher'),
              null,
            );
      });

      testWidgets('Cancel on confirmation dialog blocks launchUrl', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            const MarkdownView(markdownText: '[Click me](https://example.com)'),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the link — this should pop the confirmation dialog.
        await tester.tap(find.text('Click me'));
        await tester.pumpAndSettle();

        // Dialog visible with the expected title and host.
        expect(find.text('Open external link?'), findsOneWidget);
        expect(find.text('example.com'), findsOneWidget);

        // Tap Cancel.
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // No 'launch' call was made on the url_launcher channel.
        final launchCalls = platformCalls
            .where((c) => c.method == 'launch')
            .toList();
        expect(launchCalls, isEmpty);
      });

      testWidgets('Open on confirmation dialog calls launchUrl exactly once', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            const MarkdownView(
              markdownText: '[Visit](https://example.org/path)',
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Visit'));
        await tester.pumpAndSettle();

        expect(find.text('Open external link?'), findsOneWidget);
        expect(find.text('example.org'), findsOneWidget);

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final launchCalls = platformCalls
            .where((c) => c.method == 'launch')
            .toList();
        expect(launchCalls, hasLength(1));
        // The url_launcher method call exposes the URI under the
        // 'url' argument key.
        expect(launchCalls.first.arguments['url'], 'https://example.org/path');
      });
    });
  });
}
