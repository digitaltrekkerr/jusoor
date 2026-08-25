import 'package:file_handler/file_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HtmlParser', () {
    late HtmlParser parser;

    setUp(() {
      parser = HtmlParser();
    });

    test('parses h1 heading to Markdown', () {
      const html = '<h1>Title</h1>';
      final result = parser.parse(html);
      expect(result, contains('# Title'));
    });

    test('parses h2 heading to Markdown', () {
      const html = '<h2>Subtitle</h2>';
      final result = parser.parse(html);
      expect(result, contains('## Subtitle'));
    });

    test('parses h3 heading to Markdown', () {
      const html = '<h3>Section</h3>';
      final result = parser.parse(html);
      expect(result, contains('### Section'));
    });

    test('parses p tags to paragraph text', () {
      const html = '<p>Hello world</p>';
      final result = parser.parse(html);
      expect(result, contains('Hello world'));
    });

    test('parses ul/li to list items with - prefix', () {
      const html = '<ul><li>Item 1</li><li>Item 2</li></ul>';
      final result = parser.parse(html);
      expect(result, contains('- Item 1'));
      expect(result, contains('- Item 2'));
    });

    test('parses ol/li to list items with - prefix', () {
      const html = '<ol><li>First</li><li>Second</li></ol>';
      final result = parser.parse(html);
      expect(result, contains('- First'));
      expect(result, contains('- Second'));
    });

    test('parses table to pipe-delimited output', () {
      const html =
          '<table>'
          '<tr><th>Name</th><th>Age</th></tr>'
          '<tr><td>Alice</td><td>30</td></tr>'
          '</table>';
      final result = parser.parse(html);
      expect(result, contains('| Name | Age |'));
      expect(result, contains('| --- | --- |'));
      expect(result, contains('| Alice | 30 |'));
    });

    test('parses blockquote with > prefix', () {
      const html = '<blockquote>This is a quote</blockquote>';
      final result = parser.parse(html);
      expect(result, contains('> This is a quote'));
    });

    test('parses pre to code block', () {
      const html = '<pre>code here</pre>';
      final result = parser.parse(html);
      expect(result, contains('```\ncode here\n```'));
    });

    test('parses strong/b to bold Markdown', () {
      expect(parser.parse('<strong>bold</strong>'), contains('**bold**'));
      expect(parser.parse('<b>bold</b>'), contains('**bold**'));
    });

    test('parses em/i to italic Markdown', () {
      expect(parser.parse('<em>italic</em>'), contains('*italic*'));
      expect(parser.parse('<i>italic</i>'), contains('*italic*'));
    });

    test('parses a tag to Markdown link', () {
      const html = '<a href="https://example.com">Link</a>';
      final result = parser.parse(html);
      expect(result, contains('[Link](https://example.com)'));
    });

    test('parses br to newline', () {
      const html = '<p>Line 1<br>Line 2</p>';
      final result = parser.parse(html);
      expect(result, contains('Line 1\nLine 2'));
    });

    test('strips script tags', () {
      const html = '<p>Visible</p><script>alert("xss")</script>';
      final result = parser.parse(html);
      expect(result, contains('Visible'));
      expect(result, isNot(contains('alert')));
      expect(result, isNot(contains('xss')));
    });

    test('strips style tags', () {
      const html = '<p>Content</p><style>body { color: red; }</style>';
      final result = parser.parse(html);
      expect(result, contains('Content'));
      expect(result, isNot(contains('color')));
    });

    test('strips nav tags', () {
      const html = '<nav>Menu</nav><p>Main</p>';
      final result = parser.parse(html);
      expect(result, contains('Main'));
      expect(result, isNot(contains('Menu')));
    });

    test('strips footer tags', () {
      const html = '<p>Body</p><footer>Footer</footer>';
      final result = parser.parse(html);
      expect(result, contains('Body'));
      expect(result, isNot(contains('Footer')));
    });

    test('handles complex HTML with multiple elements', () {
      const html =
          '<h1>Document</h1>'
          '<p>Intro paragraph</p>'
          '<ul><li>Item A</li><li>Item B</li></ul>';
      final result = parser.parse(html);
      expect(result, contains('# Document'));
      expect(result, contains('Intro paragraph'));
      expect(result, contains('- Item A'));
      expect(result, contains('- Item B'));
    });
  });
}
